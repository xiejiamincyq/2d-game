extends "res://scripts/art/RenderArtStressCombatPreview.gd"

const REPORT_PATH := "res://docs/art/reviews/art-stress-performance-v1.json"
const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 180

func _initialize() -> void:
	print("BENCHMARK START: Art stress combat runtime")
	var fixture := await _create_stress_fixture()
	var viewport: SubViewport = fixture["viewport"]
	for frame in range(WARMUP_FRAMES):
		await process_frame

	var process_msec: Array[float] = []
	var draw_calls: Array[int] = []
	var render_objects: Array[int] = []
	for frame in range(SAMPLE_FRAMES):
		await process_frame
		process_msec.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		render_objects.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))

	process_msec.sort()
	var report := {
		"schema_version": 1,
		"fixture": "high-density-art-stress-v1",
		"viewport": {"width": VIEWPORT_SIZE.x, "height": VIEWPORT_SIZE.y},
		"warmup_frames": WARMUP_FRAMES,
		"sample_frames": SAMPLE_FRAMES,
		"process_msec": {
			"average": _average_float(process_msec),
			"p95": process_msec[int(floor(0.95 * float(process_msec.size() - 1)))],
			"maximum": process_msec[-1],
		},
		"render_draw_calls": {
			"average": _average_int(draw_calls),
			"maximum": draw_calls.max(),
		},
		"render_objects": {
			"average": _average_int(render_objects),
			"maximum": render_objects.max(),
		},
		"render_texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"render_video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"engine_version": Engine.get_version_info().get("string", "unknown"),
		"rendering_device": RenderingServer.get_video_adapter_name(),
		"interpretation": "single-machine debug baseline; not a cross-device release threshold",
	}
	var absolute_path := ProjectSettings.globalize_path(REPORT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write art stress benchmark: " + REPORT_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	viewport.queue_free()
	await create_timer(0.25).timeout
	await process_frame
	print(
		"BENCHMARK PASS: average=%.3fms p95=%.3fms draw_calls_max=%d texture_mem=%.2fMiB -> %s"
		% [
			float(report.process_msec.average),
			float(report.process_msec.p95),
			int(report.render_draw_calls.maximum),
			float(report.render_texture_memory_bytes) / (1024.0 * 1024.0),
			REPORT_PATH,
		]
	)
	quit(0)

func _average_float(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())

func _average_int(values: Array[int]) -> float:
	var total := 0
	for value in values:
		total += value
	return float(total) / float(values.size())
