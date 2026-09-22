extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 980.0

@export var coyote_time: float = 0.12
var coyote_timer: float = 0.0

# --- Dash settings ---
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0  # remembers last facing direction

@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	# Cooldown ticks down regardless of state
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# --- Handle dash start ---
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing:
		is_dashing = true
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown
		velocity.y = 0  # cancel vertical motion during dash
		_dash_juice()

	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction * dash_speed
		if dash_timer <= 0:
			is_dashing = false
	else:
		# --- Normal gravity ---
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			coyote_timer = coyote_time

		if not is_on_floor():
			coyote_timer -= delta

		# --- Normal movement ---
		var direction := Input.get_axis("move_left", "move_right")
		if direction != 0:
			velocity.x = direction * speed
			sprite.flip_h = direction < 0
			dash_direction = direction  # remember facing for next dash
		else:
			velocity.x = move_toward(velocity.x, 0, speed)

		# --- Jump ---
		if Input.is_action_just_pressed("jump") and (is_on_floor() or coyote_timer > 0):
			velocity.y = jump_velocity
			coyote_timer = 0
			_squash_and_stretch()

	move_and_slide()

func _squash_and_stretch() -> void:
	sprite.scale = Vector2(0.7, 1.3)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.15)

func _dash_juice() -> void:
	# quick stretch in the direction of the dash for a speed-lines feel
	sprite.scale = Vector2(1.4, 0.7)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.2)
	modulate = Color(1.5, 1.5, 1.5)  # brief flash
	var flash_tween := create_tween()
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
