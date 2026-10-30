extends Node
## Headless smoke probe: loads the level and drives an auto-player (hold right,
## jump periodically) to confirm the level is traversable to the goal.

func _ready() -> void:
	var level: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	var player: Node2D = level.get_node("Level/Player")
	await get_tree().process_frame

	# Snapshot the player's real save file, so driving the level from here can
	# never leave fake "best score / runs completed" data behind.
	var snap_best: int = Game.best_score
	var snap_coins: int = Game.total_coins
	var snap_runs: int = Game.runs_completed
	var snap_best_time: float = Game.best_time
	var snap_cp: int = Game.checkpoint_index
	var snap_respawn: Vector2 = Game.respawn_point
	var snap_collected: Array = Game.collected_coins.duplicate()
	var snap_resume_score: int = Game.resume_score

	# --- Palette -----------------------------------------------------------
	var ground_body: ColorRect = level.get_node("Level/Ground1/Body")
	var goal_banner: Polygon2D = level.get_node("Level/Goal/Banner")
	var spike_sprite: Sprite2D = level.get_node("Level/Spikes/S1/Sprite2D")
	print("PALETTE default   ground=", ground_body.color, " goal=", goal_banner.color, " spike=", spike_sprite.self_modulate)
	Game.set_colorblind_mode(true)
	await get_tree().process_frame
	print("PALETTE colorblind ground=", ground_body.color, " goal=", goal_banner.color, " spike=", spike_sprite.self_modulate)
	Game.set_colorblind_mode(false)
	await get_tree().process_frame

	# The ground and ledges are drawn by platform.gd (the rects are built in
	# code) and then recoloured by the level's palette pass — check both landed,
	# because if they did not the level looks wrong in a way tests never notice.
	var g_body: ColorRect = level.get_node("Level/Ground1/Body")
	var g_top: ColorRect = level.get_node("Level/Ground1/Top")
	print("GROUND body=", g_body.color, " top=", g_top.color,
		" top_strip_h=", snappedf(g_top.size.y, 0.1))

	# --- Audio -------------------------------------------------------------
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	print("AUDIO buses Music=", music_bus, " SFX=", sfx_bus,
		" music_db=", AudioServer.get_bus_volume_db(music_bus),
		" sfx_db=", AudioServer.get_bus_volume_db(sfx_bus))
	Game.play_sfx("coin")
	var sfx_playing := false
	for p in Game.get_children():
		if p is AudioStreamPlayer and p.playing and p.bus == &"SFX":
			sfx_playing = true
	print("AUDIO sfx_playing_after_coin=", sfx_playing)

	# --- Enemy FSM ---------------------------------------------------------
	var enemy: Node = level.get_node("Level/Enemies/E1")
	for i in 4:
		await get_tree().physics_frame
	var agent: NavigationAgent2D = enemy.get("agent")
	agent.target_position = enemy.global_position + Vector2(60, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("ENEMY spawn state=", enemy.get("state"), " pos=", enemy.global_position,
		" nav_path=", agent.get_current_navigation_path().size(),
		" map_iter=", NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()))
	var region: NavigationRegion2D = level.get_node("Level/NavRegion")
	var navpoly: NavigationPolygon = region.navigation_polygon
	var map: RID = level.get_world_2d().get_navigation_map()
	print("NAV polygon_count=", navpoly.get_polygon_count(), " verts=", navpoly.vertices.size(),
		" player_in_group=", player.is_in_group("player"))
	print("NAV map_iter=", NavigationServer2D.map_get_iteration_id(map),
		" region_enabled=", region.enabled,
		" region_map_eq=", region.get_navigation_map() == map,
		" direct_path=", NavigationServer2D.map_get_path(map, enemy.global_position, enemy.global_position + Vector2(60, 0), true).size())

	# Drop the player next to the enemy (on its left, on the ground) and watch
	# the state machine react.
	var seen: Dictionary = {}
	player.global_position = Vector2(enemy.global_position.x - 90.0, enemy.global_position.y)
	player.velocity = Vector2.ZERO
	var start_health: int = Game.health
	var nav_before: int = Game.nav_target_updates
	for i in 150:
		await get_tree().physics_frame
		if not is_instance_valid(enemy):
			break
		seen[int(enemy.get("state"))] = true
	print("ENEMY states_seen=", seen.keys(), " health ", start_health, "->", Game.health,
		" slime_alive=", is_instance_valid(enemy))
	# Optimisation evidence: without the throttle this would be ~150 (one per
	# frame per chasing enemy); with it, only when the goal really moves.
	print("NAVOPT target_updates_over_150_frames=", Game.nav_target_updates - nav_before)

	# --- Stomp must require landing SQUARELY on the head ---
	var miss_enemy: Node = level.get_node("Level/Enemies/E3")
	player.global_position = miss_enemy.global_position + Vector2(18, -40)
	player.velocity = Vector2(0, 320)
	for i in 8:
		await get_tree().physics_frame
	print("STOMP offcentre_still_alive=", is_instance_valid(miss_enemy))

	var stomp_enemy: Node = level.get_node("Level/Enemies/E4")
	var score_before: int = Game.score
	player.global_position = stomp_enemy.global_position + Vector2(0, -40)
	player.velocity = Vector2(0, 320)
	for i in 40:
		await get_tree().physics_frame
		if not is_instance_valid(stomp_enemy):
			break
	print("STOMP oncentre_defeated=", not is_instance_valid(stomp_enemy), " score ", score_before, "->", Game.score)

	# --- Double jump ------------------------------------------------------
	Game.start_run()
	player.global_position = Vector2(150, 500)
	player.velocity = Vector2.ZERO
	for i in 60:
		await get_tree().physics_frame
		if player.is_on_floor():
			break

	var base_y: float = player.global_position.y
	var single_min: float = base_y
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 80:
		await get_tree().physics_frame
		single_min = min(single_min, player.global_position.y)

	player.global_position = Vector2(150, 500)
	player.velocity = Vector2.ZERO
	for i in 60:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	base_y = player.global_position.y
	var double_min: float = base_y
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 28:
		await get_tree().physics_frame
		double_min = min(double_min, player.global_position.y)
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 80:
		await get_tree().physics_frame
		double_min = min(double_min, player.global_position.y)
	print("JUMP single_rise=", snappedf(base_y - single_min, 0.1),
		" double_rise=", snappedf(base_y - double_min, 0.1))

	# --- The coin floating over the spike must be reachable ---
	var coin_before: int = Game.score
	player.global_position = Vector2(430, 500)
	player.velocity = Vector2.ZERO
	for i in 60:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	Input.action_press("move_right")
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 14:
		await get_tree().physics_frame
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 110:
		await get_tree().physics_frame
		if Game.score > coin_before:
			break
	Input.action_release("move_right")
	print("COIN above_spike_collected=", Game.score > coin_before,
		" score ", coin_before, "->", Game.score)

	# --- One-way ledges: land on top, and pass up through from below ---------
	var p1: Node2D = level.get_node("Level/P1")
	player.global_position = Vector2(p1.global_position.x, p1.global_position.y - 70.0)
	player.velocity = Vector2.ZERO
	for i in 30:
		await get_tree().physics_frame
	print("PLATFORM one_way=", p1.get("one_way"), " landed_on_top=", player.is_on_floor(),
		" gap_to_centre=", snappedf(p1.global_position.y - player.global_position.y, 0.1))
	# Fire up from underneath: a one-way ledge must NOT stop the jump.
	player.global_position = Vector2(p1.global_position.x, p1.global_position.y + 80.0)
	player.velocity = Vector2(0, -500)
	for i in 45:
		await get_tree().physics_frame
	print("PLATFORM jumped_up_through=", player.global_position.y < p1.global_position.y - 30.0,
		" y=", snappedf(player.global_position.y, 0.1), " ledge_y=", p1.global_position.y)

	# --- Level traversal (hazards removed so this stays about geometry) ----
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	for s in get_tree().get_nodes_in_group("hazards"):
		s.set_deferred("monitoring", false)
	await get_tree().physics_frame
	Game.start_run()
	# Spare lives: falling in a pit is a geometry miss for a blind auto-player,
	# but this test asks whether the level *can* be crossed, not for a perfect run.
	Game.health = 30
	player.global_position = Vector2(60, 500)
	player.velocity = Vector2.ZERO

	var max_x: float = player.position.x
	var hop_cd := 0
	Input.action_press("move_right")
	for i in 3000:
		# Hop on every landing, and use the air jump while falling, so a mistimed
		# gap jump still recovers. A blind single bunny-hop fell in the pits at
		# random, which made this check pass or fail on luck.
		if hop_cd <= 0:
			if player.is_on_floor() or player.velocity.y > 80.0:
				Input.action_press("jump")
				hop_cd = 4
		if hop_cd > 0:
			hop_cd -= 1
			if hop_cd == 1:
				Input.action_release("jump")
		await get_tree().physics_frame
		max_x = max(max_x, player.position.x)
		if Game.level_finished:
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	await get_tree().physics_frame
	print("PROBE result max_x=", snappedf(max_x, 1.0), " final=", player.position, " score=", Game.score, " pit_falls=", 30 - Game.health, " finished=", Game.level_finished, " time=", Game.run_time)

	# --- A flag sets the respawn point, and dying returns you there ---------
	# (The traversal above ran through every flag, so re-arm CP2 first — on a real
	#  fresh run every flag is freshly built and starts disarmed.)
	Game.start_run()
	var cp2: Node2D = level.get_node("Level/Checkpoints/CP2")
	cp2.set("activated", false)
	player.global_position = cp2.global_position
	for i in 8:
		await get_tree().physics_frame
	var expect: Vector2 = cp2.global_position + Vector2(0, -34)
	print("CHECKPOINT run_checkpoint=", Game.run_checkpoint, " respawn_ok=",
		Game.respawn_point.distance_to(expect) < 4.0, " respawn=", Game.respawn_point)
	player.global_position = Vector2(3600, 480)
	for i in 4:
		await get_tree().physics_frame
	Game.damage(Game.MAX_HEALTH)
	for i in 6:
		await get_tree().physics_frame
	print("DEATH back_to_checkpoint=",
		absf(player.global_position.x - Game.respawn_point.x) < 4.0
			and absf(player.global_position.y - Game.respawn_point.y) < 20.0,
		" pos=", player.global_position, " respawn=", Game.respawn_point,
		" health=", Game.health, "/", Game.MAX_HEALTH, " run_still_going=", Game.is_running)

	# --- "Continue" keeps the coins already collected ----------------------
	Game.collected_coins.clear()
	Game.continue_run = true
	Game.collect_coin("C1")
	var kept_score_before: int = Game.score
	var level2: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(level2)
	await get_tree().process_frame
	print("CONTINUE score_kept=", Game.score == kept_score_before, " score=", Game.score,
		"/", kept_score_before, " c1_stays_collected=", not level2.has_node("Level/Coins/C1"),
		" c2_still_there=", level2.has_node("Level/Coins/C2"))
	level2.queue_free()
	await get_tree().process_frame

	# --- Save / load round-trip ---
	Game.best_score = 123
	Game.total_coins = 45
	Game.checkpoint_index = 2
	Game.save_progress()
	Game.best_score = 0
	Game.total_coins = 0
	Game.checkpoint_index = 0
	Game.load_save()
	print("SAVE roundtrip best=", Game.best_score, " coins=", Game.total_coins,
		" cp=", Game.checkpoint_index, " exists=", Game.has_save())

	# Put the player's real save back exactly as it was.
	Game.best_score = snap_best
	Game.total_coins = snap_coins
	Game.runs_completed = snap_runs
	Game.best_time = snap_best_time
	Game.checkpoint_index = snap_cp
	Game.respawn_point = snap_respawn
	Game.collected_coins.assign(snap_collected)
	Game.score = snap_resume_score
	Game.save_progress()
	get_tree().quit()