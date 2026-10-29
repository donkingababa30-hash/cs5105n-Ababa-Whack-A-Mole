extends Area2D
## Level goal — reaching the flag completes the run.

@onready var banner: Polygon2D = $Banner


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	Game.palette_changed.connect(_apply_palette)
	_apply_palette(Game.colorblind_mode)


func _apply_palette(_colorblind: bool) -> void:
	banner.color = Game.get_color("goal")


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		Game.win_level()