extends Node
## Headless smoke probe: loads the level and drives an auto-player (hold right,
## jump periodically) to confirm the level is traversable to the goal.

func _ready() -> void:
	var level: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	var player: Node2D = level.get_node("Level/Player")
	await get_tree().process_frame

	var ground_body: ColorRect = level.get_node("Level/Ground/Body")
	var goal_banner: Polygon2D = level.get_node("Level/Goal/Banner")
	var spike_sprite: Sprite2D = level.get_node("Level/Spikes/Spike1/Sprite2D")
	print("PALETTE default   ground=", ground_body.color, " goal=", goal_banner.color, " spike=", spike_sprite.self_modulate)
	Game.set_colorblind_mode(true)
	await get_tree().process_frame
	print("PALETTE colorblind ground=", ground_body.color, " goal=", goal_banner.color, " spike=", spike_sprite.self_modulate)
	Game.set_colorblind_mode(false)
	await get_tree().process_frame
	print("PALETTE reverted  ground=", ground_body.color, " goal=", goal_banner.color)

	var max_x: float = player.position.x
	await get_tree().process_frame

	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	print("AUDIO buses Music=", music_bus, " SFX=", sfx_bus,
		" music_db=", AudioServer.get_bus_volume_db(music_bus),
		" sfx_db=", AudioServer.get_bus_volume_db(sfx_bus))
	Game.play_sfx("coin")
	var music_playing := false
	var sfx_playing := false
	for p in Game.get_children():
		if p is AudioStreamPlayer and p.playing:
			if p.bus == &"Music":
				music_playing = true
			elif p.bus == &"SFX":
				sfx_playing = true
	print("AUDIO music_playing=", music_playing, " sfx_playing_after_coin=", sfx_playing)
	for p in Game.get_children():
		if p is AudioStreamPlayer and p.bus == &"Music":
			var st: AudioStream = p.stream
			print("AUDIO music stream=", st, " length=", (st.get_length() if st != null else -1.0),
				" loop=", (st.loop_mode if st is AudioStreamWAV else -99))

	Input.action_press("move_right")
	for i in 1200:
		if i % 20 == 0:
			Input.action_press("jump")
		if i % 20 == 6:
			Input.action_release("jump")
		await get_tree().physics_frame
		max_x = max(max_x, player.position.x)
		if Game.level_finished:
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	await get_tree().physics_frame
	print("PROBE result max_x=", max_x, " final=", player.position, " score=", Game.score, " health=", Game.health, " finished=", Game.level_finished, " time=", Game.run_time)
	get_tree().quit()