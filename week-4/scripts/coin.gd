extends Area2D
## Collectible coin — awards score and plays a sound when the player touches it.

const SCORE_VALUE := 10

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("coins")
	body_entered.connect(_on_body_entered)
	_start_bob()


func _start_bob() -> void:
	var start_y := sprite.position.y
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "position:y", start_y - 6.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:y", start_y + 6.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D:
		return
	Game.play_sfx("coin")
	Game.add_score(SCORE_VALUE)
	_pop()


func _pop() -> void:
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.7, 1.7), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.18)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)