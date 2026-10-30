extends Control
## Main menu — Start / Continue / Options / Quit, with the accessibility toggle
## and separate music / SFX volume sliders (both routed through their own buses).

const LEVEL_SCENE := "res://main.tscn"

var _options_panel: PanelContainer
var _colorblind_button: CheckButton
var _music_slider: HSlider
var _sfx_slider: HSlider


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu()
	Game.play_music()


func _build_background() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = load("res://assets/generated/sky_background.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.45)
	add_child(dim)


func _build_menu() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	centre.add_child(box)

	var title := _label("WEEK 7", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := _label("Juice, Save/Load & Optimization", 24)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Game.get_color("accent"))
	box.add_child(subtitle)

	box.add_child(_spacer(10))

	var start := _button("Start Game")
	start.pressed.connect(_on_start)
	box.add_child(start)

	var cont := _button("Continue")
	cont.disabled = not can_continue()
	cont.pressed.connect(_on_continue)
	box.add_child(cont)

	var options := _button("Options")
	options.pressed.connect(_on_toggle_options)
	box.add_child(options)

	var quit := _button("Quit")
	quit.pressed.connect(_on_quit)
	box.add_child(quit)

	var stats := _label(_stats_text(), 18)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)

	_build_options(box)


func _build_options(parent: VBoxContainer) -> void:
	_options_panel = PanelContainer.new()
	_options_panel.visible = false
	parent.add_child(_options_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_options_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var header := _label("Accessibility & Audio", 22)
	box.add_child(header)

	_colorblind_button = CheckButton.new()
	_colorblind_button.text = "Colourblind-safe palette (Okabe-Ito)"
	_colorblind_button.add_theme_font_size_override("font_size", 20)
	_colorblind_button.button_pressed = Game.colorblind_mode
	_colorblind_button.toggled.connect(_on_colorblind_toggled)
	box.add_child(_colorblind_button)

	box.add_child(_spacer(4))
	box.add_child(_label("Music volume", 18))
	_music_slider = _slider(0.0, 24.0, -Game.music_volume_db)
	_music_slider.value_changed.connect(_on_music_changed)
	box.add_child(_music_slider)

	box.add_child(_label("SFX volume", 18))
	_sfx_slider = _slider(0.0, 24.0, -Game.sfx_volume_db)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	box.add_child(_sfx_slider)


func can_continue() -> bool:
	return Game.has_save() and Game.checkpoint_index > 0


func _stats_text() -> String:
	if not Game.has_save():
		return "No saved progress yet"
	return "Best %d   •   Runs %d   •   Coins %d" % [
		Game.best_score, Game.runs_completed, Game.total_coins]


func _on_start() -> void:
	Game.play_sfx("click")
	Game.continue_run = false
	_go_to_level()


func _on_continue() -> void:
	Game.play_sfx("click")
	Game.continue_run = true
	_go_to_level()


func _go_to_level() -> void:
	var err: int = get_tree().change_scene_to_file(LEVEL_SCENE)
	if err != OK:
		push_error("Could not load %s (error %d)" % [LEVEL_SCENE, err])


func _on_toggle_options() -> void:
	Game.play_sfx("click")
	_options_panel.visible = not _options_panel.visible


func _on_quit() -> void:
	Game.play_sfx("click")
	get_tree().quit()


func _on_colorblind_toggled(enabled: bool) -> void:
	Game.play_sfx("click")
	Game.set_colorblind_mode(enabled)


func _on_music_changed(value: float) -> void:
	Game.set_music_volume_db(-value)


func _on_sfx_changed(value: float) -> void:
	Game.set_sfx_volume_db(-value)


# --- Small UI helpers ------------------------------------------------------
func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 56)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(func() -> void: Game.play_sfx("click"))
	return button


func _slider(min_value: float, max_value: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 1.0
	slider.value = value
	slider.custom_minimum_size = Vector2(320, 28)
	return slider


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer