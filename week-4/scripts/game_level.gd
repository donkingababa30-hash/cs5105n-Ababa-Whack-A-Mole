extends Node2D
## Level controller — owns the run timer, pause, result and scene-flow logic.

@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	Game.start_run()
	Game.run_finished.connect(_on_run_finished)
	Game.palette_changed.connect(_on_palette_changed)
	hud.restart_requested.connect(_restart)
	hud.menu_requested.connect(_to_menu)
	_apply_palette()


func _process(delta: float) -> void:
	Game.advance_time(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not Game.level_finished:
		_toggle_pause()
		get_viewport().set_input_as_handled()


# --- Palette ---------------------------------------------------------------
func _apply_palette() -> void:
	for node in get_tree().get_nodes_in_group("p_ground_body"):
		if node is ColorRect:
			node.color = Game.get_color("ground")
	for node in get_tree().get_nodes_in_group("p_ground_top"):
		if node is ColorRect:
			node.color = Game.get_color("ground_top")


func _on_palette_changed(_colorblind: bool) -> void:
	_apply_palette()


# --- Flow ------------------------------------------------------------------
func _on_run_finished(win: bool, time: float, score: int) -> void:
	hud.show_result(win, time, score)


func _toggle_pause() -> void:
	var now_paused := not get_tree().paused
	get_tree().paused = now_paused
	hud.set_paused(now_paused)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")