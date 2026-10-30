extends CanvasLayer
## In-game HUD: score, timer and health, plus the pause / result overlay.
##
## The HUD lives on its own CanvasLayer so it stays fixed on screen regardless
## of what the world does, and it processes while the tree is paused so the
## pause and result menus remain interactive.

signal restart_requested
signal menu_requested

var _score_label: Label
var _time_label: Label
var _hint_label: Label
var _hearts: Array[TextureRect] = []
var _overlay: Control
var _overlay_title: Label
var _overlay_sub: Label
var _overlay_buttons: VBoxContainer
var _heart_tex: Texture2D
var _coin_tex: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_heart_tex = load("res://assets/generated/heart.png")
	_coin_tex = load("res://assets/generated/coin.png")
	_build_hud()
	_build_overlay()

	Game.score_changed.connect(_on_score_changed)
	Game.health_changed.connect(_on_health_changed)
	Game.timer_changed.connect(_on_timer_changed)
	Game.palette_changed.connect(_apply_palette)
	Game.popup_requested.connect(_on_popup_requested)

	_on_score_changed(Game.score)
	_on_health_changed(Game.health, Game.MAX_HEALTH)
	_on_timer_changed(Game.run_time)
	_apply_palette(Game.colorblind_mode)


# --- HUD -------------------------------------------------------------------
func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22.0
	top.offset_right = -22.0
	top.offset_top = 14.0
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)

	# Left: score
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	top.add_child(left)
	var coin_icon := TextureRect.new()
	coin_icon.texture = _coin_tex
	coin_icon.custom_minimum_size = Vector2(38, 38)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(coin_icon)
	_score_label = _make_label("0", 36)
	left.add_child(_score_label)

	# Centre: timer
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(centre)
	_time_label = _make_label("00:00", 36)
	centre.add_child(_time_label)

	# Right: health hearts
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 6)
	top.add_child(right)
	for i in Game.MAX_HEALTH:
		var heart := TextureRect.new()
		heart.texture = _heart_tex
		heart.custom_minimum_size = Vector2(38, 38)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		right.add_child(heart)
		_hearts.append(heart)

	# Bottom-left hint
	_hint_label = _make_label("Esc  Pause", 20)
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_label.offset_left = 22.0
	_hint_label.offset_top = -44.0
	root.add_child(_hint_label)


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	return label


# --- Overlay ---------------------------------------------------------------
func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.72)
	_overlay.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(centre)

	var panel := PanelContainer.new()
	centre.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	_overlay_title = _make_label("", 46)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_overlay_title)

	_overlay_sub = _make_label("", 22)
	_overlay_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_overlay_sub)

	_overlay_buttons = VBoxContainer.new()
	_overlay_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_buttons.add_theme_constant_override("separation", 10)
	box.add_child(_overlay_buttons)


func _populate_buttons(entries: Array) -> void:
	for child in _overlay_buttons.get_children():
		child.queue_free()
	for entry: Array in entries:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(260, 54)
		button.add_theme_font_size_override("font_size", 24)
		var action: Callable = entry[1]
		button.pressed.connect(func() -> void:
			Game.play_sfx("click")
			action.call())
		_overlay_buttons.add_child(button)


func set_paused(is_paused: bool) -> void:
	if is_paused:
		_overlay_title.text = "Paused"
		_overlay_sub.text = "Take a breath."
		_populate_buttons([
			["Resume", _resume],
			["Restart", func() -> void: restart_requested.emit()],
			["Main Menu", func() -> void: menu_requested.emit()],
		])
		_overlay.visible = true
	else:
		_overlay.visible = false


func show_result(win: bool, time: float, score: int) -> void:
	_overlay_title.text = "Level Complete!" if win else "Game Over"
	_overlay_sub.text = "Time %s     Score %d" % [_format_time(time), score]
	_populate_buttons([
		["Play Again", func() -> void: restart_requested.emit()],
		["Main Menu", func() -> void: menu_requested.emit()],
	])
	_overlay.visible = true


## Short centre-screen message — used when the player is sent back to a checkpoint.
func show_toast(text: String) -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 104.0
	holder.offset_bottom = 156.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var label := _make_label(text, 30)
	label.add_theme_color_override("font_color", Game.get_color("accent"))
	holder.add_child(label)

	label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(holder.queue_free)


func _resume() -> void:
	get_tree().paused = false
	_overlay.visible = false


# --- Updates ---------------------------------------------------------------
func _on_score_changed(score: int) -> void:
	if _score_label != null:
		_score_label.text = str(score)
		_punch(_score_label)


func _on_health_changed(health: int, _max_health: int) -> void:
	for i in _hearts.size():
		var filled := i < health
		_hearts[i].modulate = Color(1, 1, 1, 1) if filled else Color(0.2, 0.2, 0.24, 0.85)


func _on_timer_changed(seconds: float) -> void:
	if _time_label != null:
		_time_label.text = _format_time(seconds)


func _apply_palette(_colorblind: bool) -> void:
	if _time_label != null:
		_time_label.add_theme_color_override("font_color", Game.get_color("accent"))
	if _hint_label != null:
		_hint_label.add_theme_color_override("font_color", Game.get_color("accent"))


## Floating "+10" text at the world position where it was picked up.
func _on_popup_requested(world_pos: Vector2, text: String) -> void:
	var screen := get_viewport().get_canvas_transform() * world_pos
	var label := _make_label(text, 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.87, 0.35))
	label.position = screen - Vector2(18, 16)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 46.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


## Quick scale pop — cheap, readable juice for a number that just changed.
func _punch(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(1.3, 1.3)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [int(total / 60.0), total % 60]