extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const FLOOR_SCRIPT = preload("res://scripts/world/FloorGrid.gd")
const REPORT_PATH := "res://docs/art/previews/environment/mint-farm-benchmark-v1.json"

func _initialize() -> void:
	# Keep the original baseline intact when reviewing the impact readability fix.
	var readability_review := OS.get_cmdline_user_args().has("readability")
	var report_path := REPORT_PATH.replace("-v1", "-readability-v1") if readability_review else REPORT_PATH
	var capture_path := "res://docs/art/previews/environment/mint-farm-stress-v1.png"
	if readability_review:
		capture_path = capture_path.replace("-v1", "-readability-v1")
	var drift := await _check_floor_scroll()
	if drift > 0.02:
		push_error("Floor scroll world-space pixel drift exceeded 0.02: %f" % drift)
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := MainScript.new()
	scene.audio_enabled = false
	viewport.add_child(scene)
	await process_frame
	scene.snapshot_store.save_path = "user://mint_farm_benchmark_test.json"
	seed(20260908)
	scene._start_run()
	scene.arena_layout.generate(scene.WORLD_BOUNDS, 20260908)
	scene.player.advance_entrance(scene.player.get_entrance_duration() + 0.01)
	scene.ui.wave_banner.finish_message()
	scene.player.set_physics_process(false)
	scene.player.health.set_invulnerable(999.0)
	scene.wave_director.active = false
	scene.wave_director.spawn_queue.clear()
	var camera: Camera2D = scene.player.get_node("PlayerCamera")
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	var kinds: Array = EnemyScript.EnemyKind.values()
	for i in range(80):
		var angle := TAU * float(i) / 80.0
		var point := Vector2(cos(angle) * (360 + (i % 4) * 70), sin(angle) * 290)
		scene.wave_director._spawn_enemy_at(kinds[i % kinds.size()], point)
	var tracked_enemy: Node2D = scene.enemies.get_child(0)
	var enemy_start := tracked_enemy.global_position
	var enemy_moved := false
	var frame_times: Array[float] = []
	var maximum_draws := 0
	var maximum_projectiles := 0
	var minimum_enemies := 100000
	var maximum_enemies := 0
	var last_tick := Time.get_ticks_usec()
	for frame in range(1440):
		if paused or scene.run_state != scene.RunState.PLAYING:
			push_error("Benchmark invalid: simulation paused or left PLAYING")
			quit(1)
			return
		camera.position.x = sin(float(frame) * 0.025) * 260.0
		# Exercise real projectile/effect processing while the player is test-invulnerable.
		if frame % 12 == 0:
			scene.player._spawn_bullet(Vector2.RIGHT.rotated(float(frame) * 0.09))
			scene.combat_vfx.request_effect(&"spark", scene.player.global_position, Vector2.RIGHT, 1.0)
		await process_frame
		var now := Time.get_ticks_usec()
		if is_instance_valid(tracked_enemy):
			enemy_moved = enemy_moved or tracked_enemy.global_position.distance_to(enemy_start) > 4.0
		if frame >= 240:
			frame_times.append(float(now - last_tick) / 1000.0)
			maximum_draws = maxi(maximum_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			maximum_projectiles = maxi(maximum_projectiles, scene.projectiles.get_child_count())
			minimum_enemies = mini(minimum_enemies, scene.enemies.get_child_count())
			maximum_enemies = maxi(maximum_enemies, scene.enemies.get_child_count())
		last_tick = now
	await RenderingServer.frame_post_draw
	if not enemy_moved:
		push_error("Benchmark invalid: enemy AI did not move")
		quit(1)
		return
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.save_png(ProjectSettings.globalize_path(capture_path)) != OK:
		push_error("Stress screenshot failed")
		quit(1)
		return
	var report := {
		"fixture": "80 initial active AI enemies; scripted moving camera; invulnerable stationary player; periodic bullets and sparks",
		"map_seed": 20260908, "viewport": [1280, 720], "warmup_frames": 240, "sample_frames": 1200,
		"enemy_movement_verified": enemy_moved,
		"frame_interval_msec": _stats(frame_times), "draw_calls_max": maximum_draws,
		"active_enemy_count_range": [minimum_enemies, maximum_enemies],
		"projectiles_max": maximum_projectiles, "enemies_remaining": scene.enemies.get_child_count(),
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"floor_scroll_max_channel_drift": drift,
		"device": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info()["string"],
		"limitations": "single-machine debug snapshot, not a release FPS guarantee; scripted camera is not player collision playtesting",
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(report_path), FileAccess.WRITE)
	if file == null:
		push_error("Benchmark report write failed")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	scene.snapshot_store.clear_snapshot()
	viewport.queue_free()
	await process_frame
	print("BENCHMARK PASS: ", JSON.stringify(report))
	quit(0)

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	var sum := 0.0
	for value in values:
		sum += value
	return {"average": sum / values.size(), "p95": values[int(floor(0.95 * (values.size() - 1)))], "max": values[-1]}

func _check_floor_scroll() -> float:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 240)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var floor_node := FLOOR_SCRIPT.new()
	viewport.add_child(floor_node)
	var camera := Camera2D.new()
	camera.position = Vector2(480, 0)
	viewport.add_child(camera)
	await process_frame
	await RenderingServer.frame_post_draw
	var first := viewport.get_texture().get_image()
	var maximum := 0.0
	for offset in [Vector2(1, 0), Vector2(32, 24)]:
		camera.position = Vector2(480, 0) + offset
		await process_frame
		await RenderingServer.frame_post_draw
		var moved := viewport.get_texture().get_image()
		for y in range(32, 208):
			for x in range(40, 280):
				var before := first.get_pixel(x, y)
				var after := moved.get_pixel(x - int(offset.x), y - int(offset.y))
				maximum = maxf(maximum, maxf(absf(before.r - after.r), maxf(absf(before.g - after.g), absf(before.b - after.b))))
	viewport.queue_free()
	await process_frame
	return maximum
