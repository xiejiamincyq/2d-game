extends RefCounted

# Diagnostic only. The canonical ledger owns peak selection and bounded images.
const Ledger = preload("res://scripts/art/LateCrowdLedger.gd")
var ledger := Ledger.new()
var observations: Array[Dictionary] = []
var history: Array[Dictionary] = []
var valid := true
var last_capture_wall := -1.0

func observe_sample(sample: Dictionary, bodies: Dictionary, warnings: Array) -> void:
	var info := sample.duplicate(false)
	info.merge({"index": int(sample.step), "frame": int(sample.physics_frame), "wall": float(sample.wall_seconds),
		"segment": 1, "eligible": float(sample.health) > 0.0, "live": bodies.bodies.size(),
		"visible": bodies.visible, "entities": bodies, "warnings": warnings})
	valid = valid and info.index == observations.size() + 1
	if not observations.is_empty():
		valid = valid and info.frame == observations[-1].frame + 1 and info.wall >= observations[-1].wall
	observations.append(info)
	ledger.consider_peak(info)

func capture(view: SubViewport, frame: int, wall: float) -> void:
	if not valid or observations.is_empty() or not observations[-1].eligible or frame != observations[-1].frame or wall - last_capture_wall < 0.1:
		return
	var bitmap := view.get_texture().get_image()
	if bitmap == null or bitmap.is_empty() or bitmap.get_size() != Vector2i(1280,720):
		valid = false
		return
	bitmap.convert(Image.FORMAT_RGBA8)
	var info := {"frame": frame, "wall": wall, "physics_wall": observations[-1].wall,
		"segment": 1, "observation": observations[-1].index, "process_frame": Engine.get_process_frames()}
	ledger.retain_capture({"id": bitmap.get_instance_id(), "image": bitmap, "record": info})
	history.append(info.duplicate(false))
	last_capture_wall = wall
	valid = valid and ledger.max_retained <= 120

func window_summary(terminal_wall: float, terminal_reason: String, frames: Array) -> Dictionary:
	if ledger.peak.is_empty():
		return {"observed_interval_complete":false, "reason":"no eligible physics peak"}
	var requested_start: float = ledger.peak.wall - 3.0
	var requested_end: float = ledger.peak.wall + 3.0
	var coverage_start := maxf(0.0, requested_start)
	var coverage_end := minf(terminal_wall, requested_end)
	var previous := coverage_start
	var max_gap := 0.0
	var ordered := true
	for frame in frames:
		var wall: float = frame.wall
		ordered = ordered and wall >= previous and wall <= coverage_end + 0.000001
		max_gap = maxf(max_gap, wall - previous)
		previous = wall
	max_gap = maxf(max_gap, coverage_end - previous)
	return {"requested_start":requested_start, "requested_end":requested_end, "coverage_start":coverage_start,
		"coverage_end":coverage_end, "terminal_wall":terminal_wall, "terminal_reason":terminal_reason,
		"first_capture":frames[0].wall if not frames.is_empty() else null,
		"last_capture":frames[-1].wall if not frames.is_empty() else null,
		"truncated_left":requested_start < 0.0, "left_reason":"startup" if requested_start < 0.0 else "none",
		"truncated_right":terminal_wall < requested_end, "right_reason":terminal_reason if terminal_wall < requested_end else "none",
		"left_gap":frames[0].wall-coverage_start if not frames.is_empty() else null,
		"right_gap":coverage_end-frames[-1].wall if not frames.is_empty() else null,
		"max_gap":max_gap, "gap_limit":0.25,
		"observed_interval_complete":not frames.is_empty() and ordered and max_gap <= 0.25}

func finish(directory: String, terminal_wall: float, terminal_reason: String) -> Dictionary:
	var frames: Array[Dictionary] = []
	if DirAccess.dir_exists_absolute(directory) or DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		valid = false
	else:
		for index in range(ledger.candidate.size()):
			var entry: Dictionary = ledger.candidate[index]
			var path := directory.path_join("peak-%03d.png" % index)
			valid = valid and entry.image.save_png(ProjectSettings.globalize_path(path)) == OK
			var record: Dictionary = entry.record.duplicate(false)
			record.merge({"path": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path)})
			frames.append(record)
	var window := window_summary(terminal_wall, terminal_reason, frames)
	valid = valid and window.observed_interval_complete
	ledger.ring.clear()
	ledger.candidate.clear()
	return {"valid": valid, "window":window, "observations": observations, "peak": ledger.peak, "visible_peak": ledger.visible_peak,
		"frames": frames, "capture_history": history, "max_retained": ledger.max_retained, "cache_limit": 120,
		"viewport": [1280,720], "display": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"scope": "stress60 live physics peak, earliest tie; conservative collision-body AABBs; native at most10fps wall readbacks within peak +/-3s, possibly truncated at startup/death; post-draw may include idle callbacks. Not natural balance, performance or human acceptance."}
