extends Camera2D
## Follows the player, and adds a short decaying screen-shake on impacts.
##
## Anything can call `Game.shake(amount)`. The shake is driven by "trauma":
## each request adds to it, it decays every frame, and the actual offset uses a
## squared falloff so big hits feel punchy and small ones are subtle.

@export var max_offset: Vector2 = Vector2(10.0, 8.0)
@export var max_roll: float = 0.06
@export var decay_rate: float = 2.5

var _trauma: float = 0.0


func _ready() -> void:
	Game.shake_requested.connect(_on_shake_requested)


func _on_shake_requested(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		return

	_trauma = maxf(_trauma - decay_rate * delta, 0.0)

	# Squared falloff: shake fades out quickly instead of lingering.
	var amount := _trauma * _trauma
	offset = Vector2(
		randf_range(-1.0, 1.0) * max_offset.x * amount,
		randf_range(-1.0, 1.0) * max_offset.y * amount)
	rotation = randf_range(-1.0, 1.0) * max_roll * amount

	if _trauma <= 0.0:
		offset = Vector2.ZERO
		rotation = 0.0