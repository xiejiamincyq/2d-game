extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const OUTPUT := "res://docs/art/previews/environment/"
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "fire"]
var scene: Node
var viewport: SubViewport
var travelled := 0.0
var max_penetration := 0.0
var outline_frames := 0
var collision_frames := 0
var captures: Array[String] = []

func _initialize() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = MainScript.new()
	scene.audio_enabled = false
	viewport.add_child(scene)
	await process_frame
	scene.snapshot_store.save_path = "user://moving_readability_test.json"
	seed(20260908)
	scene._start_run()
	scene.arena_layout.generate(scene.WORLD_BOUNDS, 20260908)
	scene.player.advance_entrance(scene.player.get_entrance_duration() + 0.01)
	scene.ui.wave_banner.finish_message()
	scene.wave_director.active = false
	scene.wave_director.spawn_queue.clear()
	scene.player.health.set_invulnerable(999.0)
	_release_input()
	await physics_frame
	await physics_frame
	await process_frame
	var open_physics_start := Engine.get_physics_frames()
	var directions := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	# Open-space control: a four-second square driven by the same input path.
	for frame in range(240):
		_drive(directions[frame / 60])
		var previous: Vector2 = scene.player.global_position
		await physics_frame
		await process_frame
		travelled += previous.distance_to(scene.player.global_position)
		if not _sample():
			_finish(1)
			return
		# Exercise screenshot sampling while movement is still active.
		if frame == 119 and not await _capture(""):
			_finish(1)
			return
	_release_input()
	var open_distance := travelled
	var open_physics_frames := Engine.get_physics_frames() - open_physics_start
	if open_distance < 800.0 or not await _capture("moving-open-space-v1.png"):
		push_error("Moving verification invalid: open-space input/capture failed")
		_finish(1)
		return
	# Terrain fixture: actual input drives toward the nearest obstacle, not a teleport.
	var nearest := Vector2.ZERO
	var nearest_distance := INF
	for descriptor in scene.arena_layout.get_obstacle_descriptors():
		var center: Vector2 = Rect2(descriptor["rect"]).get_center()
		if center.length_squared() < nearest_distance:
			nearest = center
			nearest_distance = center.length_squared()
	var touched_terrain := false
	var terrain_physics_start := Engine.get_physics_frames()
	for frame in range(300):
		_drive((nearest - scene.player.global_position).normalized())
		var previous: Vector2 = scene.player.global_position
		await physics_frame
		await process_frame
		travelled += previous.distance_to(scene.player.global_position)
		if not _sample():
			_finish(1)
			return
		for index in range(scene.player.get_slide_collision_count()):
			var collider: Object = scene.player.get_slide_collision(index).get_collider()
			if collider is Node and collider.is_in_group(&"arena_obstacles"):
				touched_terrain = true
	_release_input()
	var terrain_physics_frames := Engine.get_physics_frames() - terrain_physics_start
	if not touched_terrain or not await _capture("moving-terrain-contact-v1.png"):
		push_error("Moving verification: terrain collision/capture missing")
		_finish(1)
		return
	var terrain_distance := travelled - open_distance
	# Reset between fixtures only. This displacement is excluded from travelled distance.
	scene.player.position = Vector2.ZERO
	scene.player.velocity = Vector2.ZERO
	scene.player.get_node("PlayerCamera").reset_smoothing()
	await physics_frame
	await process_frame
	var combat_start: float = scene.elapsed_seconds
	var combat_physics_start := Engine.get_physics_frames()
	var combat_distance_start := travelled
	var combat_outline_start := outline_frames
	var kinds: Array = EnemyScript.EnemyKind.values()
	for index in range(60):
		var angle := TAU * float(index) / 60.0
		scene.wave_director._spawn_enemy_at(kinds[index % kinds.size()], Vector2(cos(angle) * 280.0, sin(angle) * 220.0))
	Input.action_press("fire")
	for frame in range(1200):
		_drive(directions[(frame / 75) % directions.size()])
		var previous: Vector2 = scene.player.global_position
		await physics_frame
		await process_frame
		travelled += previous.distance_to(scene.player.global_position)
		if not _sample():
			_finish(1)
			return
		if frame in [299, 599, 899, 1199]:
			if not await _capture("moving-combat-%d-v1.png" % (frame + 1)):
				_finish(1)
				return
	_release_input()
	var combat_distance := travelled - combat_distance_start
	var combat_physics_frames := Engine.get_physics_frames() - combat_physics_start
	var crowd_mobility_passed := combat_distance >= 300.0
	var outline_triggered := outline_frames > combat_outline_start
	var sampling_valid := open_physics_frames == 240 and terrain_physics_frames == 300 and combat_physics_frames == 1200
	var scripted_checks_passed := crowd_mobility_passed and outline_triggered and sampling_valid
	var report := {
		"map_seed": 20260908, "combat_sample_frames": 1200,
		"open_physics_frames": open_physics_frames,
		"terrain_physics_frames": terrain_physics_frames,
		"combat_physics_frames": combat_physics_frames,
		"sampling_valid": sampling_valid,
		"combat_elapsed_game_seconds": scene.elapsed_seconds - combat_start,
		"open_space_travelled_pixels": open_distance,
		"terrain_approach_travelled_pixels": terrain_distance,
		"combat_travelled_pixels": combat_distance,
		"crowd_mobility_minimum_pixels": 300.0,
		"crowd_mobility_passed": crowd_mobility_passed,
		"acceptance": "scripted_checks_passed" if scripted_checks_passed else "needs_review",
		"outline_triggered": outline_triggered,
		"terrain_contact_verified": touched_terrain,
		"maximum_terrain_penetration_pixels": max_penetration,
		"collision_frames_all_phases": collision_frames, "combat_outline_active_sample_frames": outline_frames - combat_outline_start,
		"initial_combat_enemies": 60, "remaining_enemies": scene.enemies.get_child_count(),
		"captures": captures,
		"limitations": "scripted real input, invulnerable player, fixed map and initial layout; spawn RNG and viewport mouse aim not controlled; not human playtesting or full-run/performance acceptance; one fixture reset excluded from distance; outline flag sampled after physics before process updates",
	}
	var file := FileAccess.open(OUTPUT + "moving-readability-v1.json", FileAccess.WRITE)
	if file == null:
		push_error("Moving verification report write failed")
		_finish(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MOVING READABILITY REPORT: ", JSON.stringify(report))
	_finish(0 if scripted_checks_passed else 2)

func _drive(direction: Vector2) -> void:
	for action in ACTIONS.slice(0, 4):
		Input.action_release(action)
	if direction.x != 0.0:
		Input.action_press("move_right" if direction.x > 0.0 else "move_left", absf(direction.x))
	if direction.y != 0.0:
		Input.action_press("move_down" if direction.y > 0.0 else "move_up", absf(direction.y))

func _sample() -> bool:
	if paused or scene.run_state != scene.RunState.PLAYING:
		push_error("Moving verification invalid: paused or not playing")
		return false
	if scene.player.get_slide_collision_count() > 0:
		collision_frames += 1
	if scene.player.get_node("PlayerOcclusionOutline").is_visible_in_tree():
		outline_frames += 1
	var point: Vector2 = scene.player.global_position
	for descriptor in scene.arena_layout.get_obstacle_descriptors():
		var rect: Rect2 = descriptor["rect"]
		var closest := point.clamp(rect.position, rect.end)
		max_penetration = maxf(max_penetration, scene.player.BODY_RADIUS - point.distance_to(closest))
	if max_penetration > 1.0:
		push_error("Moving verification: terrain penetration exceeded 1px")
		return false
	return true

func _capture(filename: String) -> bool:
	var capture_position: Vector2 = scene.player.global_position
	await RenderingServer.frame_post_draw
	if capture_position.distance_to(scene.player.global_position) > 0.01:
		push_error("Moving verification invalid: capture skipped player movement")
		return false
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty():
		push_error("Moving verification screenshot failed")
		return false
	if filename.is_empty():
		return true
	if capture.save_png(ProjectSettings.globalize_path(OUTPUT + filename)) != OK:
		push_error("Moving verification screenshot failed")
		return false
	captures.append(filename)
	return true

func _release_input() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func _finish(code: int) -> void:
	_release_input()
	if is_instance_valid(scene):
		scene.snapshot_store.clear_snapshot()
	quit(code)
