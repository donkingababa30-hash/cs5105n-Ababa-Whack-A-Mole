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
signal shake_requested(amount: float)
signal popup_requested(world_pos: Vector2, text: String)
## Emitted when the last heart is lost. The level puts the player back on the
## last checkpoint they reached instead of ending the run.
signal player_died

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

# --- Persistent progress (save/load) --------------------------------------
const SAVE_PATH := "user://save.json"

var best_score: int = 0
var best_time: float = 0.0
var runs_completed: int = 0
var total_coins: int = 0
var checkpoint_index: int = 0

# --- Run extras -----------------------------------------------------------
var respawn_point: Vector2 = Vector2.ZERO
var continue_run: bool = false
var checkpoint_spawns: Dictionary = {}
var _hit_stopping: bool = false

## Furthest flag reached in THIS run. `checkpoint_index` above is the furthest
## ever reached and is only what "Continue" resumes from. Keeping the two apart
## is what lets a flag re-arm on a fresh run.
var run_checkpoint: int = 0

# --- Resumable run (what "Continue" restores) -----------------------------
## Score the saved run had reached.
var resume_score: int = 0
## Node names of coins already picked up in this run, so "Continue" does not
## hand them back.
var collected_coins: Array = []

## Debug counter for the navigation optimisation — how many times an enemy has
## actually handed a new target to its NavigationAgent.
var nav_target_updates: int = 0

# --- Audio -----------------------------------------------------------------
var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _sounds: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save()
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
	run_checkpoint = 0
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
	# Running out of hearts no longer ends the run — the level puts the player
	# back on the last checkpoint they reached and the run carries on.
	if health <= 0:
		player_died.emit()


## Refill the bar — used when the player is put back on a checkpoint.
func refill_health() -> void:
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)


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
	if win:
		register_completion(run_time, score)
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


# --- Juice -----------------------------------------------------------------
## Request a screen-shake. `amount` is roughly "how big the hit was" (0..1).
func shake(amount: float) -> void:
	shake_requested.emit(amount)


## Freeze time for a few milliseconds so an impact lands with weight. Recovery
## uses REAL time, otherwise the pause would slow its own release down.
func hit_stop(duration: float = 0.06) -> void:
	if _hit_stopping:
		return
	_hit_stopping = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stopping = false


## Spawn a floating "+10"-style label at a world position (drawn by the HUD).
func popup(world_pos: Vector2, text: String) -> void:
	popup_requested.emit(world_pos, text)


func collect_coin(id: String = "") -> void:
	add_score(10)
	total_coins += 1
	if id != "" and not collected_coins.has(id):
		collected_coins.append(id)
	# Remember the run, so a later "Continue" does not hand the coins back.
	save_progress()


func is_coin_collected(id: String) -> bool:
	return collected_coins.has(id)


## "Continue": pick the saved run back up. (The coins remove themselves as they
## are built, so only the score has to be restored here.)
func restore_run() -> void:
	score = resume_score
	score_changed.emit(score)


## "Start Game": wipe the resumable run so there is nothing to continue.
func clear_resume() -> void:
	resume_score = 0
	collected_coins.clear()
	checkpoint_index = 0
	save_progress()


# --- Checkpoints -----------------------------------------------------------
func set_checkpoint(index: int, pos: Vector2) -> void:
	# Guard on the RUN's progress, not the saved one. Using the saved value here
	# was a real bug: once you reached the last flag in any session, every flag
	# refused to arm on later runs, so dying or falling sent you back to the very
	# start of the level even though the flags looked active.
	if index <= run_checkpoint:
		return
	run_checkpoint = index
	respawn_point = pos
	checkpoint_index = maxi(checkpoint_index, index)
	save_progress()


# --- Save / load -----------------------------------------------------------
func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("save.json is unreadable — starting a fresh save.")
		return

	best_score = int(data.get("best_score", 0))
	best_time = float(data.get("best_time", 0.0))
	runs_completed = int(data.get("runs_completed", 0))
	total_coins = int(data.get("total_coins", 0))
	checkpoint_index = int(data.get("checkpoint_index", 0))
	resume_score = int(data.get("run_score", 0))
	var coins: Variant = data.get("run_coins", [])
	if typeof(coins) == TYPE_ARRAY:
		collected_coins.assign(coins)


func save_progress() -> void:
	# Keep the in-memory resume value in step with what we are about to write, so
	# "Continue" also works within the same session.
	resume_score = score
	var data := {
		"best_score": best_score,
		"best_time": best_time,
		"runs_completed": runs_completed,
		"total_coins": total_coins,
		"checkpoint_index": checkpoint_index,
		"run_score": score,
		"run_coins": collected_coins,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Called when the level is finished: bank the run into the saved totals.
func register_completion(time: float, final_score: int) -> void:
	runs_completed += 1
	best_score = maxi(best_score, final_score)
	if best_time <= 0.0 or time < best_time:
		best_time = time
	# Finishing the level consumes the mid-level progress.
	checkpoint_index = 0
	resume_score = 0
	collected_coins.clear()
	save_progress()