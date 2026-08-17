extends SceneTree

const RefinementRig = preload("res://scripts/art/PlayerMotionRefinementRig.gd")
const PreviewSupport = preload("res://scripts/art/PlayerMotionPreviewRenderSupport.gd")
const BakeMaterials = preload("res://scripts/art/PlayerM2BakeMaterials.gd")
const CANDIDATE_MESH_PATH := "res://assets/art/source/player/player_production_lod_topology_candidate_v1.res"
const TECHNICAL_READY_PATH := "res://assets/art/actors/player/technical_previews/player_m2_ready_120yaw_composite.png"
const READY_PATH := "res://assets/art/actors/player/player_m2_ready_120yaw.png"
const MOVE_PATH := "res://assets/art/actors/player/player_m2_move_120yaw.png"
const FIRE_PATH := "res://assets/art/actors/player/player_m2_fire_120yaw.png"
const BOARD_PATH := "res://docs/art/previews/characters-combat/player-m2-runtime-actions-v1.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-m2-runtime-animation-metrics-v1.json"
const PARTIAL_ATLAS_PATTERN := "res://.godot/player_m2_runtime_action_batch_%02d.png"
const PARTIAL_REPORT_PATTERN := "res://.godot/player_m2_runtime_action_batch_%02d.json"
const KEY_FRAME_PATTERN := "res://.godot/player_m2_runtime_action_batch_%02d_yaw_%03d.png"
const SOURCE_SIZE := Vector2i(192, 192)
const RUNTIME_FRAME_SIZE := Vector2i(64, 64)
const BOARD_FRAME_SIZE := Vector2i(192, 192)
const YAW_COLUMNS := 20
const YAW_ROWS := 6
const YAW_FRAME_COUNT := 120
const YAW_STEP_DEGREES := 3.0
const KEY_ANGLE_INTERVAL := 10
const ACTION_IDS := ["move", "fire"]
const ACTION_FRAME_COUNT := 6
const BATCH_COUNT := 12
const BATCH_SCHEMA_VERSION := 1
const RECOIL_PHASES := [0.0, 0.18, 0.35, 0.55, 0.75, 1.0]
const REVIEW_BATCHES := [1, 4, 8, 10]
const REVIEW_COLORS := [Color("33fff2"), Color("33fff2"), Color("ff571f"), Color("ff8b33")]
const CAMERA_PITCH_DEGREES := 45.0
const CAMERA_DISTANCE := 8.5
const BODY_HEIGHT := 4.65
const NORMALIZED_BODY_HEIGHT := 1.988064
const SELECTED_MATERIAL := "M2"
const SELECTED_REFINEMENT := "A2"
const PREVIEW_BACKGROUND := Color("061019")

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.has("--assemble"):
		_assemble_batches()
		return
	var batch_index := _batch_index_from_arguments(arguments)
	if batch_index < 0 or batch_index >= BATCH_COUNT:
		_fail("Use -- --batch-index=0..11 to render one action-frame batch, then -- --assemble")
		return
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("M2 action batches require Windows/OpenGL3; use headless only for --assemble")
		return
	await _render_batch(batch_index)

func _batch_index_from_arguments(arguments: PackedStringArray) -> int:
	for argument in arguments:
		if argument.begins_with("--batch-index="):
			return argument.trim_prefix("--batch-index=").to_int()
	return -1

func _render_batch(batch_index: int) -> void:
	var started_msec := Time.get_ticks_msec()
	var candidate_mesh := ResourceLoader.load(CANDIDATE_MESH_PATH, "ArrayMesh") as ArrayMesh
	if candidate_mesh == null:
		_fail("M2 runtime action candidate mesh is missing")
		return
	var viewport := PreviewSupport.build_viewport(
		"PlayerM2RuntimeActionViewport",
		SOURCE_SIZE,
		BODY_HEIGHT,
		CAMERA_PITCH_DEGREES,
		CAMERA_DISTANCE,
		true,
		false
	)
	var world_environment := viewport.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.ssao_enabled = false
	root.add_child(viewport)
	var rig := RefinementRig.new()
	viewport.add_child(rig)
	if not rig.initialize():
		_fail("Could not initialize the approved A2 action rig")
		return
	if not rig.weapon_attachment is BoneAttachment3D:
		_fail("Independent rifle is not driven by BoneAttachment3D")
		return
	if rig.body_mesh == rig.weapon_attachment or rig.body_mesh.is_ancestor_of(rig.weapon_attachment):
		_fail("Body and rifle are not separate 3D source objects")
		return
	rig.body_mesh.mesh = candidate_mesh
	rig.body_mesh.material_override = BakeMaterials.body_material()
	_set_weapon_material(rig.weapon_attachment, BakeMaterials.weapon_material())
	rig.scale = Vector3.ONE * (BODY_HEIGHT / NORMALIZED_BODY_HEIGHT)
	var action_index := batch_index / ACTION_FRAME_COUNT
	var action_frame := batch_index % ACTION_FRAME_COUNT
	var action_id: String = ACTION_IDS[action_index]
	_apply_action_pose(rig, action_id, action_frame)

	var partial := Image.create_empty(YAW_COLUMNS * RUNTIME_FRAME_SIZE.x, YAW_ROWS * RUNTIME_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	partial.fill(Color(0, 0, 0, 0))
	var minimum_opaque_ratio := 1.0
	var minimum_mean_alpha := 1.0
	var minimum_maximum_alpha := 1.0
	var max_firing_error := 0.0
	var max_support_error := 0.0
	var max_stock_error := 0.0
	var minimum_foot_height := INF
	for yaw_index in range(YAW_FRAME_COUNT):
		var yaw_degrees := float(yaw_index) * YAW_STEP_DEGREES
		rig.rotation_degrees.y = yaw_degrees
		var source := await _capture(viewport, action_id, action_frame, yaw_index)
		if source.is_empty():
			return
		var opaque_ratio := PreviewSupport.opaque_visible_ratio(source)
		var alpha_metrics := _visible_alpha_metrics(source)
		if opaque_ratio <= 0.85 or float(alpha_metrics["mean_visible_alpha"]) <= 0.90 or float(alpha_metrics["maximum_alpha"]) < 0.99:
			_fail("Alpha gate failed for %s frame %d yaw %.1f" % [action_id, action_frame, yaw_degrees])
			return
		minimum_opaque_ratio = minf(minimum_opaque_ratio, opaque_ratio)
		minimum_mean_alpha = minf(minimum_mean_alpha, float(alpha_metrics["mean_visible_alpha"]))
		minimum_maximum_alpha = minf(minimum_maximum_alpha, float(alpha_metrics["maximum_alpha"]))
		max_firing_error = maxf(max_firing_error, rig.firing_hand_error())
		max_support_error = maxf(max_support_error, rig.support_hand_error())
		max_stock_error = maxf(max_stock_error, rig.stock_contact_error())
		minimum_foot_height = minf(minimum_foot_height, minf(rig.left_foot_position().y, rig.right_foot_position().y))
		var runtime_frame := source.duplicate()
		runtime_frame.resize(RUNTIME_FRAME_SIZE.x, RUNTIME_FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
		var cell := Vector2i(yaw_index % YAW_COLUMNS, yaw_index / YAW_COLUMNS)
		partial.blit_rect(runtime_frame, Rect2i(Vector2i.ZERO, RUNTIME_FRAME_SIZE), cell * RUNTIME_FRAME_SIZE)
		if batch_index in REVIEW_BATCHES and yaw_index % KEY_ANGLE_INTERVAL == 0:
			if not PreviewSupport.save_png(self, source, KEY_FRAME_PATTERN % [batch_index, yaw_index], "M2 runtime action key frame"):
				return
	if maxf(max_firing_error, maxf(max_support_error, max_stock_error)) > RefinementRig.CONTACT_TOLERANCE:
		_fail("M2 runtime action weapon contact exceeded tolerance")
		return
	if minimum_foot_height < rig.floor_height() - 0.0001:
		_fail("M2 runtime action foot penetrated the declared floor")
		return
	if not PreviewSupport.save_png(self, partial, PARTIAL_ATLAS_PATTERN % batch_index, "M2 runtime action batch"):
		return
	var elapsed_msec := Time.get_ticks_msec() - started_msec
	var report := {
		"batch_schema_version": BATCH_SCHEMA_VERSION,
		"batch_index": batch_index,
		"action_id": action_id,
		"action_frame": action_frame,
		"gait_phase": float(action_frame) / float(ACTION_FRAME_COUNT) if action_id == "move" else 0.0,
		"recoil_phase": RECOIL_PHASES[action_frame] if action_id == "fire" else -1.0,
		"camera_pitch_degrees": CAMERA_PITCH_DEGREES,
		"yaw_frame_count": YAW_FRAME_COUNT,
		"yaw_step_degrees": YAW_STEP_DEGREES,
		"candidate_vertices": candidate_mesh.surface_get_array_len(0),
		"candidate_indices": candidate_mesh.surface_get_array_index_len(0),
		"minimum_opaque_visible_ratio": minimum_opaque_ratio,
		"minimum_mean_visible_alpha": minimum_mean_alpha,
		"minimum_maximum_alpha": minimum_maximum_alpha,
		"max_firing_hand_error": max_firing_error,
		"max_support_hand_error": max_support_error,
		"max_stock_contact_error": max_stock_error,
		"minimum_foot_height": minimum_foot_height,
		"declared_floor_height": rig.floor_height(),
		"body_weapon_source_objects_separate": true,
		"weapon_attachment": "BoneAttachment3D:firing_hand",
		"elapsed_msec": elapsed_msec,
	}
	if not _write_json(PARTIAL_REPORT_PATTERN % batch_index, report):
		return
	viewport.queue_free()
	await process_frame
	print("RENDER PASS: PlayerM2RuntimeAnimationBake batch=%d action=%s frame=%d samples=120 elapsed_msec=%d" % [batch_index, action_id, action_frame, elapsed_msec])
	quit(0)

func _apply_action_pose(rig: Node, action_id: String, action_frame: int) -> void:
	if action_id == "move":
		rig.apply_refinement(SELECTED_REFINEMENT, float(action_frame) / float(ACTION_FRAME_COUNT), -1.0)
	else:
		rig.apply_refinement(SELECTED_REFINEMENT, 0.0, RECOIL_PHASES[action_frame])

func _assemble_batches() -> void:
	var atlases := {}
	for action_id in ACTION_IDS:
		var atlas := Image.create_empty(
			YAW_COLUMNS * RUNTIME_FRAME_SIZE.x,
			YAW_ROWS * RUNTIME_FRAME_SIZE.y * ACTION_FRAME_COUNT,
			false,
			Image.FORMAT_RGBA8
		)
		atlas.fill(Color(0, 0, 0, 0))
		atlases[action_id] = atlas
	var aggregate := {
		"minimum_opaque_visible_ratio": 1.0,
		"minimum_mean_visible_alpha": 1.0,
		"minimum_maximum_alpha": 1.0,
		"max_firing_hand_error": 0.0,
		"max_support_hand_error": 0.0,
		"max_stock_contact_error": 0.0,
		"minimum_foot_height": INF,
		"declared_floor_height": -INF,
		"candidate_vertices": -1,
		"candidate_indices": -1,
		"total_render_msec": 0,
	}
	for batch_index in range(BATCH_COUNT):
		var partial := Image.load_from_file(PARTIAL_ATLAS_PATTERN % batch_index)
		if partial.is_empty() or partial.get_size() != Vector2i(YAW_COLUMNS * RUNTIME_FRAME_SIZE.x, YAW_ROWS * RUNTIME_FRAME_SIZE.y):
			_fail("Missing or invalid M2 runtime action atlas batch %d" % batch_index)
			return
		var report := _read_json_dictionary(PARTIAL_REPORT_PATTERN % batch_index)
		if not _valid_partial_report(report, batch_index):
			_fail("Missing or invalid M2 runtime action report batch %d" % batch_index)
			return
		var action_index := batch_index / ACTION_FRAME_COUNT
		var action_frame := batch_index % ACTION_FRAME_COUNT
		var action_id: String = ACTION_IDS[action_index]
		var atlas: Image = atlases[action_id]
		atlas.blit_rect(partial, Rect2i(Vector2i.ZERO, partial.get_size()), Vector2i(0, action_frame * partial.get_height()))
		aggregate["minimum_opaque_visible_ratio"] = minf(float(aggregate["minimum_opaque_visible_ratio"]), float(report["minimum_opaque_visible_ratio"]))
		aggregate["minimum_mean_visible_alpha"] = minf(float(aggregate["minimum_mean_visible_alpha"]), float(report["minimum_mean_visible_alpha"]))
		aggregate["minimum_maximum_alpha"] = minf(float(aggregate["minimum_maximum_alpha"]), float(report["minimum_maximum_alpha"]))
		aggregate["max_firing_hand_error"] = maxf(float(aggregate["max_firing_hand_error"]), float(report["max_firing_hand_error"]))
		aggregate["max_support_hand_error"] = maxf(float(aggregate["max_support_hand_error"]), float(report["max_support_hand_error"]))
		aggregate["max_stock_contact_error"] = maxf(float(aggregate["max_stock_contact_error"]), float(report["max_stock_contact_error"]))
		aggregate["minimum_foot_height"] = minf(float(aggregate["minimum_foot_height"]), float(report["minimum_foot_height"]))
		aggregate["declared_floor_height"] = maxf(float(aggregate["declared_floor_height"]), float(report["declared_floor_height"]))
		aggregate["candidate_vertices"] = int(report["candidate_vertices"])
		aggregate["candidate_indices"] = int(report["candidate_indices"])
		aggregate["total_render_msec"] = int(aggregate["total_render_msec"]) + int(report["elapsed_msec"])

	var ready := Image.load_from_file(TECHNICAL_READY_PATH)
	if ready.is_empty() or ready.get_size() != Vector2i(YAW_COLUMNS * RUNTIME_FRAME_SIZE.x, YAW_ROWS * RUNTIME_FRAME_SIZE.y):
		_fail("Accepted M2 READY atlas is missing or invalid")
		return
	var board := _build_review_board()
	if board.is_empty():
		return
	if not PreviewSupport.save_png(self, ready, READY_PATH, "M2 READY runtime atlas"):
		return
	if not PreviewSupport.save_png(self, atlases["move"], MOVE_PATH, "M2 MOVE runtime atlas"):
		return
	if not PreviewSupport.save_png(self, atlases["fire"], FIRE_PATH, "M2 FIRE runtime atlas"):
		return
	if not PreviewSupport.save_png(self, board, BOARD_PATH, "M2 runtime action review board"):
		return
	var gait_phases := []
	for frame_index in range(ACTION_FRAME_COUNT):
		gait_phases.append(float(frame_index) / float(ACTION_FRAME_COUNT))
	var total_runtime_bytes := _file_size(READY_PATH) + _file_size(MOVE_PATH) + _file_size(FIRE_PATH)
	var report := {
		"schema_version": 1,
		"asset_id": "player_m2_runtime_animation",
		"selected_material": SELECTED_MATERIAL,
		"selected_refinement": SELECTED_REFINEMENT,
		"action_ids": ACTION_IDS,
		"action_frame_count": ACTION_FRAME_COUNT,
		"gait_phases": gait_phases,
		"recoil_phases": RECOIL_PHASES,
		"camera_pitch_degrees": CAMERA_PITCH_DEGREES,
		"yaw_frame_count": YAW_FRAME_COUNT,
		"yaw_step_degrees": YAW_STEP_DEGREES,
		"yaw_range_degrees": 360.0,
		"sample_count": YAW_FRAME_COUNT * ACTION_FRAME_COUNT * ACTION_IDS.size(),
		"runtime_frame_size": {"width": RUNTIME_FRAME_SIZE.x, "height": RUNTIME_FRAME_SIZE.y},
		"ready_atlas_size": {"width": ready.get_width(), "height": ready.get_height()},
		"action_atlas_size": {"width": (atlases["move"] as Image).get_width(), "height": (atlases["move"] as Image).get_height()},
		"review_board_size": {"width": board.get_width(), "height": board.get_height()},
		"minimum_opaque_visible_ratio": aggregate["minimum_opaque_visible_ratio"],
		"minimum_mean_visible_alpha": aggregate["minimum_mean_visible_alpha"],
		"minimum_maximum_alpha": aggregate["minimum_maximum_alpha"],
		"ready_corner_alpha_max": _corner_alpha_max(ready),
		"move_corner_alpha_max": _corner_alpha_max(atlases["move"]),
		"fire_corner_alpha_max": _corner_alpha_max(atlases["fire"]),
		"max_firing_hand_error": aggregate["max_firing_hand_error"],
		"max_support_hand_error": aggregate["max_support_hand_error"],
		"max_stock_contact_error": aggregate["max_stock_contact_error"],
		"minimum_foot_height": aggregate["minimum_foot_height"],
		"declared_floor_height": aggregate["declared_floor_height"],
		"candidate_vertices": aggregate["candidate_vertices"],
		"candidate_indices": aggregate["candidate_indices"],
		"body_weapon_source_objects_separate": true,
		"weapon_attachment": "BoneAttachment3D:firing_hand",
		"composite_depth_source": "single 3D SubViewport depth buffer",
		"batch_count": BATCH_COUNT,
		"total_batch_render_msec": aggregate["total_render_msec"],
		"file_sizes_bytes": {
			"ready_atlas": _file_size(READY_PATH),
			"move_atlas": _file_size(MOVE_PATH),
			"fire_atlas": _file_size(FIRE_PATH),
		},
		"review_board_file_bytes": _file_size(BOARD_PATH),
		"total_runtime_atlas_bytes": total_runtime_bytes,
		"production_integration": false,
	}
	if not _write_json(REPORT_PATH, report):
		return
	print("ASSEMBLY PASS: PlayerM2RuntimeAnimationBake samples=%d runtime_bytes=%d render_msec=%d" % [report["sample_count"], total_runtime_bytes, aggregate["total_render_msec"]])
	quit(0)

func _build_review_board() -> Image:
	var board := Image.create_empty(BOARD_FRAME_SIZE.x * 6, BOARD_FRAME_SIZE.y * 8, false, Image.FORMAT_RGBA8)
	board.fill(PREVIEW_BACKGROUND)
	for review_index in range(REVIEW_BATCHES.size()):
		var batch_index: int = REVIEW_BATCHES[review_index]
		var bar_y := review_index * BOARD_FRAME_SIZE.y * 2
		board.fill_rect(Rect2i(0, bar_y, board.get_width(), 6), REVIEW_COLORS[review_index])
		for key_index in range(12):
			var yaw_index := key_index * KEY_ANGLE_INTERVAL
			var key_frame := Image.load_from_file(KEY_FRAME_PATTERN % [batch_index, yaw_index])
			if key_frame.is_empty() or key_frame.get_size() != BOARD_FRAME_SIZE:
				_fail("Missing review frame for batch %d yaw %d" % [batch_index, yaw_index])
				return Image.new()
			var position := Vector2i((key_index % 6) * BOARD_FRAME_SIZE.x, bar_y + (key_index / 6) * BOARD_FRAME_SIZE.y)
			board.blit_rect(key_frame, Rect2i(Vector2i.ZERO, BOARD_FRAME_SIZE), position)
	return board

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}

func _valid_partial_report(report: Dictionary, batch_index: int) -> bool:
	var action_index := batch_index / ACTION_FRAME_COUNT
	var action_frame := batch_index % ACTION_FRAME_COUNT
	return (
		int(report.get("batch_schema_version", -1)) == BATCH_SCHEMA_VERSION
		and int(report.get("batch_index", -1)) == batch_index
		and str(report.get("action_id", "")) == ACTION_IDS[action_index]
		and int(report.get("action_frame", -1)) == action_frame
		and int(report.get("yaw_frame_count", -1)) == YAW_FRAME_COUNT
		and is_equal_approx(float(report.get("yaw_step_degrees", -1.0)), YAW_STEP_DEGREES)
		and is_equal_approx(float(report.get("camera_pitch_degrees", -1.0)), CAMERA_PITCH_DEGREES)
		and int(report.get("candidate_vertices", 0)) > 0
		and int(report.get("candidate_indices", 0)) > 0
		and bool(report.get("body_weapon_source_objects_separate", false))
		and str(report.get("weapon_attachment", "")) == "BoneAttachment3D:firing_hand"
	)

func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var length := file.get_length()
	file.close()
	return length

func _corner_alpha_max(image: Image) -> float:
	return maxf(
		image.get_pixel(0, 0).a,
		maxf(
			image.get_pixel(image.get_width() - 1, 0).a,
			maxf(image.get_pixel(0, image.get_height() - 1).a, image.get_pixel(image.get_width() - 1, image.get_height() - 1).a)
		)
	)

func _capture(viewport: SubViewport, action_id: String, action_frame: int, yaw_index: int) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	await RenderingServer.frame_post_draw
	var source := viewport.get_texture().get_image()
	if source.is_empty():
		_fail("Empty %s frame %d capture at yaw index %d" % [action_id, action_frame, yaw_index])
		return Image.new()
	source.convert(Image.FORMAT_RGBA8)
	return source

func _visible_alpha_metrics(image: Image) -> Dictionary:
	var visible_pixels := 0
	var visible_alpha_sum := 0.0
	var maximum_alpha := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if alpha <= 0.05:
				continue
			visible_pixels += 1
			visible_alpha_sum += alpha
			maximum_alpha = maxf(maximum_alpha, alpha)
	return {
		"mean_visible_alpha": visible_alpha_sum / maxf(float(visible_pixels), 1.0),
		"maximum_alpha": maximum_alpha,
	}

func _set_weapon_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_set_weapon_material(child, material)

func _write_json(path: String, value: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		_fail("Could not write JSON: " + path)
		return false
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
