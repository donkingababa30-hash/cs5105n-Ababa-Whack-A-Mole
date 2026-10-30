extends CharacterBody2D
## Week 6 enemy: a slime that patrols the ground, spots the player, chases, and
## lunges when it gets close.
##
## This node is a FINITE STATE MACHINE (FSM). At any moment the slime is in
## exactly one of the states below, and the only place a state can change is
## `_enter_state()`. Movement lives in `_physics_process`, so the state logic
## stays readable on its own.
##
##   PATROL  --(sees the player)----------------------> CHASE
##   CHASE   --(player inside attack range, off cooldown)--> ATTACK
##   CHASE   --(lost sight of the player for a while)--> PATROL
##   ATTACK  --(lunge finished)-----------------------> CHASE
##   any     --(player lands on its head)-------------> DEAD
##
## It walks using a NavigationAgent2D, so it follows the baked ground nav mesh
## instead of a straight line, and it "sees" the player with a detection Area2D
## confirmed by a line-of-sight raycast.

enum State { PATROL, CHASE, ATTACK, DEAD }

# Half-sizes used by the stomp check (the slime's body is 28 x 32, the player's is
# 24 x 52). Keeping them named makes the stomp rule easy to re-tune.
const BODY_HALF_HEIGHT := 16.0      # this enemy is 32 px tall
const PLAYER_HALF_HEIGHT := 26.0    # the player is 52 px tall
const STOMP_HALF_WIDTH := 14.0      # must land within this of the slime's centre
const STOMP_MIN_FALL_SPEED := 120.0

# --- Tuning (the exported knobs you can balance without touching code) ------
@export_group("Patrol")
@export var patrol_left: float = 300.0
@export var patrol_right: float = 470.0
@export var patrol_speed: float = 55.0

@export_group("Chase")
@export var chase_speed: float = 115.0
@export var lose_sight_time: float = 2.0

@export_group("Attack")
@export var attack_range: float = 48.0
@export var attack_vertical: float = 46.0
@export var attack_windup: float = 0.35
@export var attack_lunge_time: float = 0.20
@export var attack_lunge_speed: float = 240.0
@export var attack_cooldown: float = 0.9

@export_group("Physics")
@export var gravity: float = 980.0

# --- State -----------------------------------------------------------------
var state: State = State.PATROL
var _facing: float = 1.0
var _patrol_target: float = 0.0
var _lose_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _attack_phase: int = 0          # 0 = windup, 1 = lunge
var _attack_timer: float = 0.0
var _attack_direction: float = 1.0
var _last_known: Vector2 = Vector2.ZERO
var _player: Node2D = null
var _player_in_detection: bool = false
var _base_scale: Vector2 = Vector2.ONE

@onready var sprite: Sprite2D = $Sprite2D
@onready var detection: Area2D = $Detection
@onready var sight: RayCast2D = $Sight
@onready var hitbox: Area2D = $Hitbox
@onready var agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	add_to_group("enemies")
	_base_scale = sprite.scale
	detection.body_entered.connect(_on_detection_body_entered)
	detection.body_exited.connect(_on_detection_body_exited)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_enter_state(State.PATROL)


func _physics_process(delta: float) -> void:
	# The player may not exist yet on the very first frames, so look it up lazily.
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")

	_tick_timers(delta)
	_update_state(delta)

	# Gravity — the slime is a ground enemy.
	if not is_on_floor():
		velocity.y += gravity * delta

	_check_stomp()
	move_and_slide()

	# Face the direction we are moving.
	if absf(velocity.x) > 4.0:
		sprite.flip_h = velocity.x < 0.0


func _tick_timers(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


# --- The state machine -----------------------------------------------------
func _update_state(delta: float) -> void:
	match state:
		State.PATROL:
			_do_patrol()
		State.CHASE:
			_do_chase(delta)
		State.ATTACK:
			_do_attack(delta)
		State.DEAD:
			velocity.x = 0.0


func _enter_state(new_state: State) -> void:
	state = new_state
	sprite.modulate = Color.WHITE

	match state:
		State.PATROL:
			# Walk toward whichever bound is further away.
			var middle := (patrol_left + patrol_right) * 0.5
			_patrol_target = patrol_right if global_position.x < middle else patrol_left
		State.CHASE:
			_lose_timer = 0.0
			_last_known = _player.global_position if _player != null else global_position
		State.ATTACK:
			_attack_phase = 0
			_attack_timer = attack_windup
		State.DEAD:
			velocity.x = 0.0


func _do_patrol() -> void:
	if _can_see_player():
		_enter_state(State.CHASE)
		return

	# Ping-pong between the two patrol bounds.
	if absf(global_position.x - _patrol_target) < 8.0:
		_patrol_target = patrol_right if is_equal_approx(_patrol_target, patrol_left) else patrol_left

	_step_toward(_patrol_target, patrol_speed)


func _do_chase(delta: float) -> void:
	if _can_see_player():
		_lose_timer = 0.0
		_last_known = _player.global_position
	else:
		# Keep heading to where we last saw the player, but give up eventually.
		_lose_timer += delta
		if _lose_timer >= lose_sight_time:
			_enter_state(State.PATROL)
			return

	# Close enough and roughly level? Lunge.
	if _player != null and _cooldown_timer <= 0.0:
		var dx := absf(_player.global_position.x - global_position.x)
		var dy := absf(_player.global_position.y - global_position.y)
		if dx < attack_range and dy < attack_vertical:
			_enter_state(State.ATTACK)
			return

	_step_toward(_last_known.x, chase_speed)


func _do_attack(delta: float) -> void:
	_attack_timer -= delta

	if _attack_phase == 0:
		# Windup: hold still and flash so the player gets a readable warning.
		velocity.x = 0.0
		sprite.modulate = Color(1.7, 1.2, 1.2)
		if _attack_timer <= 0.0:
			_attack_phase = 1
			_attack_timer = attack_lunge_time
			_attack_direction = _facing
			_punch_scale(Vector2(1.25, 0.8))
	else:
		# Lunge forward. Contact damage does the rest.
		velocity.x = _attack_direction * attack_lunge_speed
		if _attack_timer <= 0.0:
			_cooldown_timer = attack_cooldown
			_enter_state(State.CHASE)


# --- Perception ------------------------------------------------------------
func _can_see_player() -> bool:
	if _player == null or not _player_in_detection:
		return false
	# Line of sight: cast straight at the player and make sure nothing solid
	# (the world layer) is between us.
	sight.target_position = sight.to_local(_player.global_position)
	sight.force_raycast_update()
	return not sight.is_colliding()


func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_detection = true


func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_detection = false


# --- Movement --------------------------------------------------------------
## Walk toward a world X coordinate using the navigation path when it is ready.
func _step_toward(target_x: float, speed: float) -> void:
	# The NavigationServer needs a physics frame before the nav mesh is usable.
	# Until then we steer straight at the target so the slime never freezes.
	#
	# We must also NOT set the agent's target before that first sync: the agent
	# only recomputes its path when the target CHANGES, so a target set while the
	# map is still empty would stick and the path would stay empty forever.
	if not _map_ready():
		_drive(target_x, speed)
		return

	agent.target_position = Vector2(target_x, global_position.y)
	_drive(agent.get_next_path_position().x, speed)


## Motor: set velocity.x so we close on `target_x` at `speed` px/s.
func _drive(target_x: float, speed: float) -> void:
	var dx := target_x - global_position.x
	if absf(dx) > 3.0:
		velocity.x = signf(dx) * speed
		_facing = signf(dx)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)


func _map_ready() -> bool:
	if not agent.is_inside_tree():
		return false
	return NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) != 0


# --- Contact damage & being stomped ----------------------------------------
func _on_hitbox_body_entered(body: Node2D) -> void:
	# Landing on the slime's head is a stomp, not a hit — never damage a player
	# who is coming down on top of us.
	var cb := body as CharacterBody2D
	if cb != null and cb.velocity.y > 0.0 \
			and cb.global_position.y + PLAYER_HALF_HEIGHT < global_position.y - 2.0:
		return
	if body.has_method("hurt"):
		body.hurt()


## A player who lands squarely on the slime's head defeats it (and gets a bounce).
## The tolerance is deliberately tight: a glancing or off-centre landing does NOT
## count, so you have to actually jump on top of it.
func _check_stomp() -> void:
	if state == State.DEAD or _player == null:
		return
	var body := _player as CharacterBody2D
	if body == null:
		return

	var dx := absf(body.global_position.x - global_position.x)
	var feet_y := body.global_position.y + PLAYER_HALF_HEIGHT
	var head_y := global_position.y - BODY_HALF_HEIGHT

	if dx < STOMP_HALF_WIDTH \
			and body.velocity.y > STOMP_MIN_FALL_SPEED \
			and feet_y > head_y - 10.0 \
			and feet_y < head_y + 22.0:
		_die(body)


func _die(player: CharacterBody2D) -> void:
	_enter_state(State.DEAD)
	Game.play_sfx("coin")
	Game.add_score(25)
	player.velocity.y = -330.0
	detection.set_deferred("monitoring", false)
	hitbox.set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.5, 0.0), 0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _punch_scale(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "scale", _base_scale * target, 0.08)
	tween.tween_property(sprite, "scale", _base_scale, 0.12)