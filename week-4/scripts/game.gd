extends Node
## Week 5 — global game state, audio routing and accessibility settings.
##
## Registered as the "Game" autoload so state (score, health, timer) and
## audio survive scene changes between the menu and the level.

signal score_changed(score: int)
signal health_changed(health: int, max_health: int)
signal timer_changed(seconds: float)
signal run_finished(win: bool, time: float, score: int)
signal palette_changed(colorblind: bool)
signal settings_changed

const MAX_HEALTH := 3
const SFX_POOL_SIZE := 10

const SFX_PATHS := {
	"jump": "res://assets/audio/jump.wav",
	"jump2": "res://assets/audio/jump2.wav",
	"dash": "res://assets/audio/dash.wav",
	"coin": "res://assets/audio/coin.wav",
	"hurt": "res://assets/audio/hurt.wav",
	"click": "res://assets/audio/click.wav",
	"win": "res://assets/audio/win.wav",
	"gameover": "res://assets/audio/gameover.wav",
}
const MUSIC_PATH := "res://assets/audio/music.wav"

# --- Colour palettes -------------------------------------------------------
# The colourblind palette is based on the Okabe-Ito scheme and removes the
# red/green pair (hazard vs. goal) that is the most common source of confusion
# for deuteranopia / protanopia players.
const PALETTE_DEFAULT := {
	"ground": Color(0.447, 0.365, 0.176),
	"ground_top": Color(0.376, 0.584, 0.239),
	"hazard": Color(0.902, 0.286, 0.302),
	"goal": Color(0.290, 0.812, 0.435),
	"accent": Color(0.325, 0.769, 0.973),
	"panel": Color(0.086, 0.098, 0.129, 0.85),
	"text": Color(1, 1, 1),
}
const PALETTE_COLORBLIND := {
	"ground": Color(0.420, 0.370, 0.270),
	"ground_top": Color(0.000, 0.620, 0.451),
	"hazard": Color(0.835, 0.369, 0.000),
	"goal": Color(0.000, 0.447, 0.698),
	"accent": Color(0.337, 0.706, 0.914),
	"panel": Color(0.086, 0.098, 0.129, 0.85),
	"text": Color(1, 1, 1),
}

# --- Run state -------------------------------------------------------------
var score: int = 0
var health: int = MAX_HEALTH
var run_time: float = 0.0
var is_running: bool = false
var level_finished: bool = false

# --- Settings / accessibility ---------------------------------------------
var colorblind_mode: bool = false
var music_volume_db: float = -8.0
var sfx_volume_db: float = -2.0

# --- Audio -----------------------------------------------------------------
var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _sounds: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_sounds()
	_build_players()
	apply_audio_settings()
	play_music()


func _load_sounds() -> void:
	for key: String in SFX_PATHS:
		var stream: AudioStream = load(SFX_PATHS[key])
		if stream != null:
			_sounds[key] = stream


func _build_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Music"
	var music_stream: AudioStream = load(MUSIC_PATH)
	if music_stream != null and music_stream is AudioStreamWAV:
		music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music_stream.loop_begin = 0
	_music_player.stream = music_stream
	add_child(_music_player)

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)


# --- Run lifecycle ---------------------------------------------------------
func start_run() -> void:
	score = 0
	health = MAX_HEALTH
	run_time = 0.0
	is_running = true
	level_finished = false
	score_changed.emit(score)
	health_changed.emit(health, MAX_HEALTH)
	timer_changed.emit(run_time)


func add_score(amount: int) -> void:
	if not is_running:
		return
	score += amount
	score_changed.emit(score)


func damage(amount: int) -> void:
	if not is_running or level_finished:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		_finish(false)


func advance_time(delta: float) -> void:
	if not is_running or level_finished:
		return
	run_time += delta
	timer_changed.emit(run_time)


func win_level() -> void:
	if not is_running or level_finished:
		return
	_finish(true)


func _finish(win: bool) -> void:
	is_running = false
	level_finished = true
	play_sfx("win" if win else "gameover")
	run_finished.emit(win, run_time, score)


# --- Accessibility & settings ---------------------------------------------
func set_colorblind_mode(enabled: bool) -> void:
	if colorblind_mode == enabled:
		return
	colorblind_mode = enabled
	palette_changed.emit(colorblind_mode)
	settings_changed.emit()


func toggle_colorblind_mode() -> void:
	set_colorblind_mode(not colorblind_mode)


func get_color(key: String) -> Color:
	var dict: Dictionary = PALETTE_COLORBLIND if colorblind_mode else PALETTE_DEFAULT
	return dict.get(key, Color.WHITE)


func set_music_volume_db(db: float) -> void:
	music_volume_db = db
	apply_audio_settings()
	settings_changed.emit()


func set_sfx_volume_db(db: float) -> void:
	sfx_volume_db = db
	apply_audio_settings()
	settings_changed.emit()


func apply_audio_settings() -> void:
	_set_bus_volume(&"Music", music_volume_db)
	_set_bus_volume(&"SFX", sfx_volume_db)


func _set_bus_volume(bus_name: StringName, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


# --- Audio playback --------------------------------------------------------
func play_sfx(sfx_name: String) -> void:
	var stream: AudioStream = _sounds.get(sfx_name)
	if stream == null or _sfx_pool.is_empty():
		return
	var player := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	player.stream = stream
	player.play()


func play_music() -> void:
	if _music_player != null and _music_player.stream != null and not _music_player.playing:
		_music_player.play()