extends Node2D
## Level controller — owns the run timer, pause, result and scene-flow logic.

@onready var hud: CanvasLayer = $HUD
@onready var player: CharacterBody2D = $Level/Player

const FALL_Y := 760.0          # below this the player has fallen into a pit
const LEVEL_WIDTH := 4200
const LEVEL_HEIGHT := 648
const START_POSITION := Vector2(60, 480)


func _ready() -> void:
	Game.start_run()
	Game.run_finished.connect(_on_run_finished)
	Game.palette_changed.connect(_on_palette_changed)
	Game.player_died.connect(_on_player_died)
	hud.restart_requested.connect(_restart)
	hud.menu_requested.connect(_to_menu)

	# A fresh run starts from nothing; "Continue" picks the saved run back up —
	# its checkpoint, its score, and the coins it had already collected.
	var continuing: bool = Game.continue_run
	Game.continue_run = false
	if continuing:
		Game.restore_run()
	else:
		Game.clear_resume()

	Game.checkpoint_spawns[0] = START_POSITION
	var start_index: int = Game.checkpoint_index if continuing else 0
	player.global_position = Game.checkpoint_spawns.get(start_index, START_POSITION)
	Game.respawn_point = player.global_position
	# Flags already behind the spawn point stay armed.
	Game.run_checkpoint = start_index

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = LEVEL_WIDTH
		camera.limit_bottom = LEVEL_HEIGHT

	_apply_palette()


func _process(delta: float) -> void:
	Game.advance_time(delta)
	# Fell into a pit?
	if Game.is_running and player != null and player.global_position.y > FALL_Y:
		player.respawn()


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


## Lost every heart: put the player back on the last checkpoint they reached and
## keep the run going, instead of sending them back to the start of the level.
func _on_player_died() -> void:
	Game.play_sfx("hurt")
	Game.shake(0.9)
	Game.hit_stop(0.08)
	player.revive()
	var where := "checkpoint %d" % Game.run_checkpoint if Game.run_checkpoint > 0 else "the start"
	hud.show_toast("Back to " + where)


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