extends Area2D
## Hazard spikes — damage the player on contact. The colour follows the active
## palette so the danger colour stays distinguishable in colourblind mode; the
## triangular silhouette is a redundant shape cue.

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)
	Game.palette_changed.connect(_apply_palette)
	_apply_palette(Game.colorblind_mode)


func _apply_palette(_colorblind: bool) -> void:
	sprite.self_modulate = Game.get_color("hazard")


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("hurt"):
		body.hurt()