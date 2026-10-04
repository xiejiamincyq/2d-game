extends "res://scripts/art/VerifyNaturalRun.gd"

const Ledger = preload("res://scripts/art/LateCrowdLedger.gd")
const Rendered = preload("res://scripts/art/VerifyNaturalRunRendered.gd")
const Lobbed = preload("res://scripts/components/LobbedProjectile.gd")
var ledger := Ledger.new()
var observations: Array[Dictionary] = []
var observation_pending := {}
var watched_player_id := 0
var segment := 0
var travelled := 0.0
var previous_point := Vector2.ZERO
var capture_dir := ""
var last_capture_wall := -1.0
var capture_frames: Array[Dictionary] = []
var capture_history: Array[Dictionary] = []
var run_map := {}

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Late crowd capture requires native rendering")
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--run="):
			var run_id := argument.trim_prefix("--run=")
			if RegEx.create_from_string("^[A-Za-z0-9_-]{1,80}$").search(run_id) == null:
				quit(2)
				return
			capture_dir = OUTPUT + "late-" + run_id + "/"
	if capture_dir.is_empty() or DirAccess.dir_exists_absolute(capture_dir) or FileAccess.file_exists(capture_dir.trim_suffix("/") + ".json"):
		push_error("Late crowd capture refuses existing or missing output ID")
		quit(2)
		return
	RenderingServer.frame_post_draw.connect(_capture_late)
	await super._initialize()

func _capture_late() -> void:
	if started == 0 or reloading or not terminal.is_empty() or observations.is_empty() or not is_instance_valid(scene.player):
		return
	var info := _context()
	info.merge({"boss": is_instance_valid(scene.wave_director.get_active_boss()), "collection": scene.wave_director.collection_window_active})
	if not Ledger.eligible(info) or not observations[-1].eligible or info.frame != observations[-1].frame or info.wall - last_capture_wall < 0.1:
		return
	last_capture_wall = info.wall
	var bitmap := view.get_texture().get_image()
	if bitmap == null or bitmap.is_empty() or bitmap.get_size() != Vector2i(1280, 720):
		valid = false
		terminal = "capture_error"
		return
	bitmap.convert(Image.FORMAT_RGBA8)
	info.merge({"segment": observations[-1].segment, "observation": observations[-1].index,
		"process_frame": Engine.get_process_frames(), "input": observations[-1].input_post,
		"player_position": [scene.player.global_position.x, scene.player.global_position.y],
		"entities": Ledger.entities(scene.wave_director.active_enemies, view.canvas_transform, Rect2(Vector2.ZERO, Vector2(view.size)), scene.player.global_position, scene.player.get_body_radius())})
	ledger.retain_capture({"id": bitmap.get_instance_id(), "image": bitmap, "record": info})
	capture_history.append({"wall": info.wall, "frame": info.frame, "observation": info.observation, "segment": info.segment, "process_frame": info.process_frame})
	if ledger.max_retained > 120:
		valid = false
		terminal = "capture_cache_limit"

func _context() -> Dictionary:
	return {"wall": float(Time.get_ticks_usec() - started) / 1000000.0, "frame": Engine.get_physics_frames(),
		"state": scene.RunState.keys()[scene.run_state], "wave": scene.wave_director.wave_index + 1, "player_id": watched_player_id}

func _observe_health(current: float, _maximum: float) -> void:
	ledger.observe_value("health", current, _context())

func _observe_shield(current: float, _maximum: float) -> void:
	ledger.observe_value("shield", current, _context())

func _before(delta: float) -> void:
	observation_pending = {}
	if is_instance_valid(scene) and is_instance_valid(scene.player) and watched_player_id != scene.player.get_instance_id():
		watched_player_id = scene.player.get_instance_id()
		ledger.previous_values = {"health": scene.player.health.current_health, "shield": scene.player.shield}
		scene.player.health_changed.connect(_observe_health)
		scene.player.shield_changed.connect(_observe_shield)
	super._before(delta)
	if pending_frame != Engine.get_physics_frames() or scene.run_state != scene.RunState.PLAYING:
		return
	if run_map.is_empty():
		var terrain: Array = []
		for descriptor in scene.arena_layout.obstacle_descriptors:
			var rect: Rect2 = descriptor.rect
			terrain.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
		var bounds: Rect2 = scene.WORLD_BOUNDS
		run_map = {"terrain": terrain, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
			"map_seed": scene.map_seed, "map_generator_version": scene.arena_layout.generator_version}
	valid = valid and int(run_map.map_seed) == scene.map_seed
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	observation_pending = {"pre_frame": pending_frame, "pre_delta": delta, "pre_position": [position_before.x, position_before.y],
		"input_pre": [input.x, input.y], "dash_pre": scene.player.dash_active,
		"walk_budget": scene.player.get_effective_move_speed() * delta * input.length(), "base_step_before": samples.size()}

func _after(delta: float) -> void:
	if observation_pending.is_empty() or not is_instance_valid(scene):
		super._after(delta)
		return
	var info := _context()
	info.merge({"boss": is_instance_valid(scene.wave_director.get_active_boss()), "collection": scene.wave_director.collection_window_active})
	var ordinary := Ledger.eligible(info)
	var before := Vector2(observation_pending.pre_position[0], observation_pending.pre_position[1])
	var point: Vector2 = scene.player.global_position
	if observations.is_empty() or not ordinary or not observations[-1].eligible or info.frame != observations[-1].frame + 1 or info.wave != observations[-1].wave:
		segment += 1
	var gap := 0.0 if observations.is_empty() or info.frame != observations[-1].frame + 1 else previous_point.distance_to(before)
	travelled += gap + before.distance_to(point)
	var bodies := Ledger.entities(scene.wave_director.active_enemies, view.canvas_transform, Rect2(Vector2.ZERO, Vector2(view.size)), point, scene.player.get_body_radius())
	var actual := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var progress := (point - before).dot(Vector2(observation_pending.input_pre[0], observation_pending.input_pre[1]).normalized())
	var warnings: Array[Dictionary] = []
	for shot in scene.projectiles.get_children():
		if shot is Lobbed and not shot.is_queued_for_deletion():
			warnings.append({"id": shot.get_instance_id(), "position": [shot.target_position.x, shot.target_position.y], "radius": shot.splash_radius, "elapsed": shot.elapsed, "duration": shot.flight_duration})
	var bounds: Rect2 = scene.WORLD_BOUNDS
	var terrain_gap: float = minf(minf(point.x - bounds.position.x, bounds.end.x - point.x), minf(point.y - bounds.position.y, bounds.end.y - point.y)) - scene.player.get_body_radius()
	for descriptor in scene.arena_layout.obstacle_descriptors:
		var rect: Rect2 = descriptor.rect
		var nearest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
		terrain_gap = minf(terrain_gap, point.distance_to(nearest) - scene.player.get_body_radius())
	info.merge(observation_pending)
	info.merge({"index": observations.size() + 1, "post_delta": delta, "position": [point.x, point.y],
		"input_post": [actual.x, actual.y], "dash_requested": Input.is_action_pressed("dash_melee"),
		"dash_active": scene.player.dash_active, "dash_started": scene.player.dash_active and not observation_pending.dash_pre,
		"eligible": ordinary, "segment": segment, "bodies": bodies.bodies, "live": bodies.bodies.size(),
		"visible": bodies.visible, "kinds": bodies.kinds, "canvas": bodies.canvas, "player_radius": scene.player.get_body_radius(), "nearest_enemy_gap": bodies.nearest_gap,
		"callback_gap": gap, "travelled": travelled, "along_input": progress,
		"low_progress": observation_pending.walk_budget > 0 and progress < observation_pending.walk_budget * 0.1,
		"health": scene.player.health.current_health, "shield": scene.player.shield,
		"health_loss": ledger.health_loss, "shield_loss": ledger.shield_loss})
	info.merge({"warnings": warnings, "terrain_gap": terrain_gap,
		"low_streak": int(observations[-1].low_streak) + 1 if info.low_progress and not observations.is_empty() and info.segment == observations[-1].segment else int(info.low_progress)})
	valid = valid and info.frame == info.pre_frame and is_equal_approx(delta, info.pre_delta) and actual.is_equal_approx(Vector2(info.input_pre[0], info.input_pre[1]))
	observations.append(info)
	ledger.consider_peak(info)
	previous_point = point
	observation_pending = {}
	super._after(delta)
	if samples.size() > int(info.base_step_before):
		samples[-1]["late_index"] = info.index

func _source_hashes() -> Dictionary:
	var hashes := super._source_hashes()
	for path in Rendered.visual_source_paths() + ["scripts/art/VerifyLateCrowd.gd", "scripts/art/LateCrowdLedger.gd", "scripts/art/check_late_crowd_report.py"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes

func _finish() -> void:
	RenderingServer.frame_post_draw.disconnect(_capture_late)
	paused = true
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir)) != OK:
		valid = false
	for index in range(ledger.candidate.size()):
		var entry: Dictionary = ledger.candidate[index]
		var path := capture_dir + "peak-%03d.png" % index
		if entry.image.save_png(ProjectSettings.globalize_path(path)) != OK:
			valid = false
		entry.record.merge({"path": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path)})
		capture_frames.append(entry.record)
	ledger.ring.clear()
	ledger.candidate.clear()
	var path := capture_dir.trim_suffix("/") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		valid = false
	else:
		var manifest := {"run": config.run, "source_sha256": source_before, "observations": observations,
			"peak": ledger.peak, "visible_peak": ledger.visible_peak, "frames": capture_frames, "capture_history": capture_history,
			"loss_events": ledger.events, "health_loss": ledger.health_loss, "shield_loss": ledger.shield_loss,
			"max_retained": ledger.max_retained, "cache_limit": 120, "viewport": [1280,720],
			"display": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(),
			"scope": "ordinary waves4-6 physics peak; conservative body AABB visibility; native wall-paced at most10fps readbacks, not performance/human acceptance"}
		manifest.merge(run_map)
		file.store_string(JSON.stringify(manifest))
		file.close()
	print("LATE_CROWD_COMPLETE run=%s observations=%d frames=%d max_retained=%d" % [config.run, observations.size(), capture_frames.size(), ledger.max_retained])
	await super._finish()
