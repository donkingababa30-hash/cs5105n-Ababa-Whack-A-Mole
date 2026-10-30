extends CharacterBody2D

@export var speed: float = 280.0
@export var jump_velocity: float = -500.0
@export var gravity: float = 980.0

@export var coyote_time: float = 0.12
var coyote_timer: float = 0.0

# Double jump: one extra jump while airborne (refilled on landing). This is what
# lets the player reach the coins that float above the spikes.
@export var max_air_jumps: int = 1
@export var air_jump_velocity: float = -430.0
var air_jumps_left: int = 0

@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var dust: CPUParticles2D = $Dust
var base_scale: Vector2
var was_on_floor: bool = false

var is_invulnerable: bool = false
@export var invuln_time: float = 1.2

func _ready() -> void:
	add_to_group("player")
	base_scale = sprite.scale

func _physics_process(delta: float) -> void:
	var can_control: bool = Game.is_running

	# Refill the air jump whenever we are standing on something.
	if is_on_floor():
		air_jumps_left = max_air_jumps

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	if can_control and Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing:
		is_dashing = true
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown
		velocity.y = 0
		_dash_juice()
		dust.restart()
		Game.play_sfx("dash")

	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction * dash_speed
		if dash_timer <= 0:
			is_dashing = false
	else:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			coyote_timer = coyote_time

		if not is_on_floor():
			coyote_timer -= delta

		var direction := Input.get_axis("move_left", "move_right") if can_control else 0.0
		if direction != 0:
			velocity.x = direction * speed
			sprite.flip_h = direction < 0
			dash_direction = direction
		else:
			velocity.x = move_toward(velocity.x, 0, speed)

		if can_control and Input.is_action_just_pressed("jump"):
			if is_on_floor() or coyote_timer > 0:
				velocity.y = jump_velocity
				coyote_timer = 0
				_squash_and_stretch()
				Game.play_sfx("jump")
			elif air_jumps_left > 0:
				# Double jump.
				air_jumps_left -= 1
				velocity.y = air_jump_velocity
				_double_jump_juice()
				Game.play_sfx("jump2")

	move_and_slide()

	if is_on_floor() and not was_on_floor:
		dust.restart()
	was_on_floor = is_on_floor()

	_update_animation()

func _update_animation() -> void:
	var target := "idle"
	if not is_on_floor():
		target = "jump"
	elif abs(velocity.x) > 10:
		target = "run"
	if anim.current_animation != target:
		anim.play(target)

func _squash_and_stretch() -> void:
	sprite.scale = base_scale * Vector2(0.7, 1.3)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", base_scale, 0.15)

func _double_jump_juice() -> void:
	dust.restart()
	sprite.scale = base_scale * Vector2(0.7, 1.35)
	modulate = Color(1.4, 1.4, 1.6)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", base_scale, 0.2)
	var flash := create_tween()
	flash.tween_property(self, "modulate", Color.WHITE, 0.2)


func _dash_juice() -> void:
	sprite.scale = base_scale * Vector2(1.4, 0.7)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", base_scale, 0.2)
	modulate = Color(1.5, 1.5, 1.5)
	var flash_tween := create_tween()
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.2)


func is_player() -> bool:
	return true


## Fell into a pit: lose a heart and return to the last checkpoint, with the
## same flashing invulnerability a normal hit gives.
func respawn() -> void:
	if not Game.is_running:
		return
	global_position = Game.respawn_point
	velocity = Vector2.ZERO
	Game.damage(1)
	Game.shake(0.7)
	Game.hit_stop(0.05)

	var flash := create_tween()
	for i in 4:
		flash.tween_property(sprite, "modulate:a", 0.3, 0.09)
		flash.tween_property(sprite, "modulate:a", 1.0, 0.09)
	flash.tween_callback(func() -> void: sprite.modulate.a = 1.0)


## Put the player back on their feet at the last checkpoint after losing every
## heart: full bar, no momentum, and a longer flash of invulnerability so they
## are not hit again the instant they reappear.
func revive() -> void:
	global_position = Game.respawn_point
	velocity = Vector2.ZERO
	is_dashing = false
	air_jumps_left = max_air_jumps
	is_invulnerable = true
	Game.refill_health()

	var flash := create_tween()
	for i in 8:
		flash.tween_property(sprite, "modulate:a", 0.2, 0.09)
		flash.tween_property(sprite, "modulate:a", 1.0, 0.09)
	flash.tween_callback(func() -> void: sprite.modulate.a = 1.0)

	await get_tree().create_timer(1.5).timeout
	is_invulnerable = false


## Called by hazards. Breaks a heart, knocks the player back and grants a
## short window of invulnerability (with a flashing sprite) so a single hit
## never drains more than one heart.
func hurt() -> void:
	if is_invulnerable or not Game.is_running:
		return
	is_invulnerable = true
	Game.play_sfx("hurt")
	Game.damage(1)
	Game.shake(0.55)
	Game.hit_stop(0.06)
	velocity.y = -280.0
	velocity.x = -dash_direction * 240.0
	var flash := create_tween()
	for i in 6:
		flash.tween_property(sprite, "modulate:a", 0.25, 0.08)
		flash.tween_property(sprite, "modulate:a", 1.0, 0.08)
	flash.tween_callback(func() -> void: sprite.modulate.a = 1.0)
	await get_tree().create_timer(invuln_time).timeout
	is_invulnerable = false
