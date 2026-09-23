extends Node2D


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass

func _on_spikes_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		body.position = Vector2(17, 568)  
		body.velocity = Vector2.ZERO


func _on_goal_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		$Completed.visible = true
		body.set_physics_process(false)
