extends Area2D
## A respawn point. Touching it makes it the place the player returns to after
## falling into a pit, and it remembers that progress in the save file.

@export var index: int = 1

@onready var banner: Polygon2D = $Banner

var activated: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	Game.palette_changed.connect(_on_palette_changed)
	_refresh_color()
	# Tell the level where "Continue" should drop the player for this checkpoint.
	Game.checkpoint_spawns[index] = global_position + Vector2(0, -34)


func _on_palette_changed(_colorblind: bool) -> void:
	_refresh_color()


func _refresh_color() -> void:
	banner.color = Game.get_color("goal") if activated else Color(0.46, 0.48, 0.55)


func _on_body_entered(body: Node2D) -> void:
	if activated or not body.is_in_group("player"):
		return
	activated = true
	_refresh_color()
	Game.play_sfx("coin")
	Game.set_checkpoint(index, global_position + Vector2(0, -34))

	var tween := create_tween()
	tween.tween_property(banner, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.25)