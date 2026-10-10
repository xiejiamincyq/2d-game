extends SceneTree
## Visual-load budget, not AI/physics, human acceptance or presented-frame FPS.
const PlayerSource = preload("res://scripts/actors/Player.gd")
const EnemySource = preload("res://scripts/actors/Enemy.gd")
const OutlineSource = preload("res://scripts/effects/PlayerOcclusionOutline.gd")
const OUT := "res://build/diagnostics/campaign-goal/native-player-budget-v2/"
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("NATIVE PLAYER BUDGET FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(DisplayServer.get_name() != "headless" and not DirAccess.dir_exists_absolute(OUT), "requires GPU and fresh output")
	if failures:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var source_paths := ["scripts/art/VerifyNativePlayerBudget.gd", "scripts/actors/Player.gd", "scripts/actors/Enemy.gd", "scripts/components/NativePlayerMotion.gd", "scripts/components/NativePlayerView.gd", "scripts/components/NativeActorView.gd", "scripts/components/NativeScrapperMotion.gd", "scenes/actors/native/player_paper_v1.tscn", "scenes/actors/native/rootling_paper_v3.tscn", "assets/art/actors/native/rootling_motion_v3.tres", "scripts/effects/PlayerOcclusionOutline.gd", "assets/art/shaders/player_native_outline.gdshader"]
	for facing in ["front", "back", "left", "right"]:
		source_paths.append("assets/art/actors/native/player_%s_motion_v1.tres" % facing)
	var sources := {}
	for path in source_paths:
		sources[path] = FileAccess.get_sha256("res://" + path)
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var screen := TextureRect.new()
	screen.texture = view.get_texture()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	var actor = PlayerSource.new()
	actor.position = Vector2(640, 384)
	view.add_child(actor)
	actor.set_physics_process(false)
	var crowd := Node2D.new()
	var obstacles := Node2D.new()
	view.add_child(crowd)
	view.add_child(obstacles)
	var actors: Array[CharacterBody2D] = []
	for index in 128:
		var enemy = EnemySource.new()
		enemy.position = Vector2(76 + (index % 16) * 74, 78 + (index / 16) * 84)
		enemy.setup(EnemySource.EnemyKind.SCRAPPER, 1, view, actor)
		crowd.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.velocity = Vector2(100, 0)
		actors.append(enemy)
	actors[0].position = actor.position + Vector2(0, 24)
	var outline = OutlineSource.new()
	actor.add_child(outline)
	outline.setup(actor, crowd, obstacles)
	outline.set_process(false)
	var intervals: Array[float] = []
	var previous := 0
	var started := 0
	var pose_seconds := 0.0
	var contour_frames := 0
	var draw_calls := 0
	var facing_seen := {}
	var recoil_seen := false
	for frame in 1440:
		var delta := 1.0 / 60.0 # Synthetic visual samples, not production clock writes.
		pose_seconds += delta
		actor.gun_angle = pose_seconds * 2
		actor.velocity = Vector2(100, 0)
		if frame % 12 == 0:
			actor.native_motion.prepare_shot(Vector2.RIGHT.rotated(actor.gun_angle))
		actor._update_visual_animation(delta)
		for enemy in actors:
			enemy.native_motion.update(enemy, delta)
		outline._process(0)
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if frame >= 240:
			if started == 0:
				started = previous
			intervals.append((now - previous) / 1000.0)
			contour_frames += 1 if outline.visible else 0
			draw_calls = maxi(draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			facing_seen[actor.native_visual.facing] = true
			recoil_seen = recoil_seen or actor.native_visual.clip == "shoot"
		previous = now
	var elapsed_ms := (previous - started) / 1000.0
	var sorted := intervals.duplicate()
	sorted.sort()
	var p95: float = sorted[ceili(sorted.size() * 0.95) - 1]
	check(intervals.size() == 1200 and contour_frames == 1200 and facing_seen.size() == 4 and recoil_seen, "load/pose coverage incomplete")
	check(p95 <= 16.7, "P95 exceeds 16.7 ms visual budget")
	check(view.get_texture().get_image().save_png(OUT + "crowd.png") == OK, "post-measurement image save failed")
	for path in source_paths:
		check(FileAccess.get_sha256("res://" + path) == sources[path], "source changed during budget proof")
	var report := {"passed": failures == 0, "samples": intervals.size(), "warmup_frames": 240, "native_enemies": 128,
		"contour_frames": contour_frames, "facings": facing_seen.keys(), "shoot_overlay_seen": recoil_seen,
		"mean_ms": elapsed_ms / intervals.size(), "p95_ms": p95, "max_ms": sorted[-1], "elapsed_ms": elapsed_ms,
		"peak_draw_calls": draw_calls, "frame_intervals_ms": intervals, "sources": sources, "adapter": RenderingServer.get_video_adapter_name(),
		"scope": "Synthetic 128 actual Enemy-created native bodies plus actual Player four views/gait/recoil and continuously occluded native mask; AI/physics disabled, no readbacks/writes during timing. Uncapped post-draw wall intervals, not GPU-only cost, presented frames, ordinary gameplay, comparative speedup or all six-region performance."}
	var file := FileAccess.open(OUT + "report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	screen.free()
	view.free()
	await process_frame
	print("NATIVE PLAYER BUDGET %s: 128 native enemies + player/outline, 1200 samples P95 %.3f ms max %.3f ms" % ["PASS" if failures == 0 else "FAIL", p95, sorted[-1]])
	quit(0 if failures == 0 else 1)
