extends Node
## Headless smoke probe: loads the level and drives an auto-player (hold right,
## jump periodically) to confirm the level is traversable to the goal.

func _ready() -> void:
	var level: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	var player: Node2D = level.get_node("Level/Player")
	await get_tree().process_frame

	# --- Palette -----------------------------------------------------------
	var ground_body: ColorRect = level.get_node("Level/Ground/Body")
	var goal_banner: Polygon2D = level.get_node("Level/Goal/Banner")
	var spike_sprite: Sprite2D = level.get_node("Level/Spikes/Spike1/Sprite2D")
	print("PALETTE default   ground=", ground_body.color, " goal=", goal_banner.color, " spike=", spike_sprite.self_modulate)
	Game.set_colorblind_mode(true)
	await get_tree().process_frame
	print("PALETTE colorblind ground=", ground_body.color, " goal=", goal_banner.color, " spike=", spike_sprite.self_modulate)
	Game.set_colorblind_mode(false)
	await get_tree().process_frame

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
	var enemy: Node = level.get_node("Level/Enemies/Enemy1")
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

	# Drop the player next to the enemy (on its left, clear of the spike) and
	# watch the state machine react.
	var seen: Dictionary = {}
	player.global_position = enemy.global_position + Vector2(-90, -30)
	player.velocity = Vector2.ZERO
	var start_health: int = Game.health
	for i in 150:
		await get_tree().physics_frame
		seen[int(enemy.get("state"))] = true
		if i % 25 == 0:
			print("  ENEMY t=", i, " state=", enemy.get("state"),
				" sees=", enemy.get("_player_in_detection"),
				" det_overlap=", (enemy.get("detection") as Area2D).get_overlapping_bodies().size(),
				" ray_hit=", (enemy.get("sight") as RayCast2D).is_colliding(),
				" agent_path=", agent.get_current_navigation_path().size(),
				" agent_finished=", agent.is_navigation_finished(),
				" dx=", snappedf(player.global_position.x - enemy.global_position.x, 0.1))
	print("ENEMY states_seen=", seen.keys(), " health ", start_health, "->", Game.health,
		" player_dx=", snappedf(player.global_position.x - enemy.global_position.x, 0.1))

	# --- Stomp must require landing SQUARELY on the head ---
	var miss_enemy: Node = level.get_node("Level/Enemies/Enemy1")
	player.global_position = miss_enemy.global_position + Vector2(18, -44)
	player.velocity = Vector2(0, 320)
	for i in 8:
		await get_tree().physics_frame
	print("STOMP offcentre_still_alive=", is_instance_valid(miss_enemy))

	var stomp_enemy: Node = level.get_node("Level/Enemies/Enemy2")
	var score_before: int = Game.score
	player.global_position = stomp_enemy.global_position + Vector2(0, -44)
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
	player.global_position = Vector2(370, 500)
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
	for i in 90:
		await get_tree().physics_frame
		if Game.score > coin_before:
			break
	Input.action_release("move_right")
	print("COIN above_spike_collected=", Game.score > coin_before,
		" score ", coin_before, "->", Game.score)

	# --- Level traversal (enemies removed so this stays about geometry) ----
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await get_tree().physics_frame
	Game.start_run()
	player.global_position = Vector2(60, 500)
	player.velocity = Vector2.ZERO

	var max_x: float = player.position.x
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