extends SceneTree

# Isolated visual-only dense sample. Does not benchmark gameplay AI/physics.
const Sample = preload("res://scenes/art/technical/NativeMonsterSample.tscn")
const OUTPUT := "res://build/diagnostics/campaign-goal/native-monster-density-v4.json"

func percentile(values: Array[float], fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(int(ceil(sorted.size() * fraction)) - 1, sorted.size() - 1)]

func _initialize() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scenarios: Array[Dictionary] = []
	for count in [32, 128, 256]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var start := Time.get_ticks_usec()
		for index in count:
			var actor := Sample.instantiate()
			actor.position = Vector2(32 + (index % 32) * 39, 80 + (index / 32) * 78)
			viewport.add_child(actor)
			actor.play_clip("walk")
		var spawn_ms := float(Time.get_ticks_usec() - start) / 1000.0
		for warmup in 30:
			await process_frame
			await RenderingServer.frame_post_draw
		var wall_times: Array[float] = []
		var draw_calls := 0
		for frame in 120:
			var frame_start := Time.get_ticks_usec()
			await process_frame
			await RenderingServer.frame_post_draw
			wall_times.append(float(Time.get_ticks_usec() - frame_start) / 1000.0)
			draw_calls = maxi(draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		var scenario := {"actors": count, "native_bones": count * 12, "samples": wall_times.size(), "spawn_ms": spawn_ms, "frame_wall_p50_ms": percentile(wall_times, 0.5), "frame_wall_p95_ms": percentile(wall_times, 0.95), "maximum_draw_calls": draw_calls}
		scenarios.append(scenario)
		print("NATIVE DENSITY: " + JSON.stringify(scenario))
		viewport.queue_free()
		await process_frame
		await process_frame
	var evidence := {"scope": "visual-only native skeleton, walk loop, 1280x720 offscreen viewport; not Main, AI, physics, input, present/drop or player experience", "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "vsync_requested": "disabled", "scenarios": scenarios}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		push_error("TEST FAIL: Native density evidence cannot be saved")
		quit(1)
		return
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	print("BENCHMARK PASS: NativeMonsterSample visual-only density recorded")
	quit(0)
