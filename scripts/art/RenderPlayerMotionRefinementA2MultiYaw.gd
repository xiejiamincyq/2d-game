extends SceneTree

const RefinementRig = preload("res://scripts/art/PlayerMotionRefinementRig.gd")
const PreviewSupport = preload("res://scripts/art/PlayerMotionPreviewRenderSupport.gd")
const RUNTIME_PATH := "res://assets/art/actors/player/technical_previews/player_motion_refinement_a2_multiyaw.png"
const BOARD_PATH := "res://docs/art/previews/characters-combat/player-motion-refinement-a2-48-frame-v1.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-motion-refinement-a2-multiyaw-metrics-v1.json"
const PARTIAL_RUNTIME_PATTERN := "res://.godot/player_motion_refinement_a2_state_%d.png"
const PARTIAL_BOARD_PATTERN := "res://.godot/player_motion_refinement_a2_board_%d.png"
const PARTIAL_REPORT_PATTERN := "res://.godot/player_motion_refinement_a2_state_%d.json"
const SOURCE_SIZE := Vector2i(192, 192)
const RUNTIME_FRAME_SIZE := Vector2i(64, 64)
const BOARD_FRAME_SIZE := Vector2i(192, 192)
const BOARD_COLUMNS := 6
const YAW_FRAME_COUNT := 12
const YAW_STEP_DEGREES := 30.0
const CAMERA_PITCH_DEGREES := 45.0
const CAMERA_DISTANCE := 8.5
const BODY_HEIGHT := 4.65
const NORMALIZED_BODY_HEIGHT := 1.988064
const SELECTED_REFINEMENT := "A2"
const BATCH_SCHEMA_VERSION := 1
const PREVIEW_BACKGROUND := Color("061019")
const STATE_COLORS := [Color("33fff2"), Color("f559bf"), Color("ff571f"), Color("aab4be")]
const MOTION_STATES := [
	{"id": "GAIT_LEFT", "gait_phase": 0.25, "recoil_phase": -1.0},
	{"id": "GAIT_RIGHT", "gait_phase": 0.75, "recoil_phase": -1.0},
	{"id": "RECOIL_PEAK", "gait_phase": 0.0, "recoil_phase": 0.35},
	{"id": "RECOVERY_TAIL", "gait_phase": 0.0, "recoil_phase": 0.75},
]

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.has("--assemble"):
		print("ASSEMBLE START: PlayerMotionRefinementA2MultiYaw")
		_assemble_batches()
		return
	var state_index := _state_index_from_arguments(arguments)
	if state_index < 0 or state_index >= MOTION_STATES.size():
		push_error("Use -- --state-index=0..3 to render one recoverable batch, then -- --assemble")
		quit(1)
		return
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("A2 multi-yaw 3D batches require a GPU display driver. Use Windows/OpenGL3; reserve --headless for --assemble only.")
		quit(1)
		return
	print("RENDER START: PlayerMotionRefinementA2MultiYaw state=%d" % state_index)
	await _render_state_batch(state_index)

func _state_index_from_arguments(arguments: PackedStringArray) -> int:
	for argument in arguments:
		if argument.begins_with("--state-index="):
			return argument.trim_prefix("--state-index=").to_int()
	return -1

func _render_state_batch(state_index: int) -> void:
	var runtime_row := Image.create_empty(YAW_FRAME_COUNT * RUNTIME_FRAME_SIZE.x, RUNTIME_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	runtime_row.fill(Color(0, 0, 0, 0))
	var board_strip := Image.create_empty(BOARD_COLUMNS * BOARD_FRAME_SIZE.x, 2 * BOARD_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	board_strip.fill(PREVIEW_BACKGROUND)
	var state: Dictionary = MOTION_STATES[state_index]
	var state_id := String(state["id"])
	var viewports: Array[SubViewport] = []
	var rigs: Array[Node] = []
	print("BATCH BUILD START: %s 12 cached rigs" % state_id)
	for yaw_index in range(YAW_FRAME_COUNT):
		var viewport := PreviewSupport.build_viewport(
			"PlayerMotionRefinementA2MultiYawViewport%d" % yaw_index,
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
			quit(1)
			return
		rig.scale = Vector3.ONE * (BODY_HEIGHT / NORMALIZED_BODY_HEIGHT)
		if not rig.weapon_attachment is BoneAttachment3D:
			push_error("A2 multi-yaw rifle is not driven by BoneAttachment3D")
			quit(1)
			return
		var yaw_degrees := float(yaw_index) * YAW_STEP_DEGREES
		rig.apply_refinement(SELECTED_REFINEMENT, float(state["gait_phase"]), float(state["recoil_phase"]))
		rig.rotation_degrees.y = yaw_degrees
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewports.append(viewport)
		rigs.append(rig)
	print("BATCH BUILD PASS: %s 12 cached rigs" % state_id)
	await process_frame
	await RenderingServer.frame_post_draw

	var sample_metrics: Array[Dictionary] = []
	var max_firing_error := 0.0
	var max_support_error := 0.0
	var max_stock_error := 0.0
	var minimum_foot_height := INF
	var minimum_opaque_visible_ratio := 1.0
	for yaw_index in range(YAW_FRAME_COUNT):
		var yaw_degrees := float(yaw_index) * YAW_STEP_DEGREES
		var viewport := viewports[yaw_index]
		var rig := rigs[yaw_index]
		var source := viewport.get_texture().get_image()
		if source.is_empty():
			push_error("A2 multi-yaw simultaneous batch capture is empty: %s yaw %.1f" % [state_id, yaw_degrees])
			quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)
		var opaque_ratio: float = PreviewSupport.opaque_visible_ratio(source)
		var firing_error: float = rig.firing_hand_error()
		var support_error: float = rig.support_hand_error()
		var stock_error: float = rig.stock_contact_error()
		var foot_height: float = minf(rig.left_foot_position().y, rig.right_foot_position().y)
		minimum_opaque_visible_ratio = minf(minimum_opaque_visible_ratio, opaque_ratio)
		max_firing_error = maxf(max_firing_error, firing_error)
		max_support_error = maxf(max_support_error, support_error)
		max_stock_error = maxf(max_stock_error, stock_error)
		minimum_foot_height = minf(minimum_foot_height, foot_height)
		_record_partial_frame(source, state_index, yaw_index, runtime_row, board_strip)
		sample_metrics.append({
			"state": state_id,
			"yaw_degrees": yaw_degrees,
			"firing_hand_error": firing_error,
			"support_hand_error": support_error,
			"stock_contact_error": stock_error,
			"minimum_foot_height": foot_height,
			"opaque_visible_ratio": opaque_ratio,
		})

	if max_firing_error > RefinementRig.CONTACT_TOLERANCE or max_support_error > RefinementRig.CONTACT_TOLERANCE or max_stock_error > RefinementRig.CONTACT_TOLERANCE:
		push_error("A2 multi-yaw grip contact tolerance failed in state " + state_id)
		quit(1)
		return
	var reference_rig := rigs[0]
	if minimum_foot_height < reference_rig.floor_height() - 0.0001:
		push_error("A2 multi-yaw foot penetrated the declared floor in state " + state_id)
		quit(1)
		return
	if minimum_opaque_visible_ratio <= 0.85:
		push_error("A2 multi-yaw proof contains broad translucency in state " + state_id)
		quit(1)
		return
	if not PreviewSupport.save_png(self, runtime_row, PARTIAL_RUNTIME_PATTERN % state_index, "A2 multi-yaw runtime row"):
		return
	if not PreviewSupport.save_png(self, board_strip, PARTIAL_BOARD_PATTERN % state_index, "A2 multi-yaw board strip"):
		return
	var partial_report := {
		"batch_schema_version": BATCH_SCHEMA_VERSION,
		"state_index": state_index,
		"state": state,
		"camera_pitch_degrees": CAMERA_PITCH_DEGREES,
		"yaw_frame_count": YAW_FRAME_COUNT,
		"yaw_step_degrees": YAW_STEP_DEGREES,
		"source_size": {"width": SOURCE_SIZE.x, "height": SOURCE_SIZE.y},
		"cache_schema_version": RefinementRig.REVIEW_SKINNED_MESH_CACHE_SCHEMA_VERSION,
		"sample_metrics": sample_metrics,
		"locked_profile": reference_rig.refinement_profile(SELECTED_REFINEMENT),
		"max_firing_hand_error": max_firing_error,
		"max_support_hand_error": max_support_error,
		"max_stock_contact_error": max_stock_error,
		"minimum_foot_height": minimum_foot_height,
		"declared_floor_height": reference_rig.floor_height(),
		"minimum_opaque_visible_ratio": minimum_opaque_visible_ratio,
		"source_vertices_preserved": reference_rig.body_mesh.mesh.surface_get_array_len(0),
		"source_indices_preserved": reference_rig.body_mesh.mesh.surface_get_array_index_len(0),
	}
	if not _write_json(PARTIAL_REPORT_PATTERN % state_index, partial_report):
		return
	for viewport in viewports:
		viewport.queue_free()
	await process_frame
	print("RENDER PASS: PlayerMotionRefinementA2MultiYaw state=%s 12 samples" % state_id)
	quit(0)

func _assemble_batches() -> void:
	var runtime_atlas := Image.create_empty(YAW_FRAME_COUNT * RUNTIME_FRAME_SIZE.x, MOTION_STATES.size() * RUNTIME_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	runtime_atlas.fill(Color(0, 0, 0, 0))
	var board := Image.create_empty(BOARD_COLUMNS * BOARD_FRAME_SIZE.x, MOTION_STATES.size() * 2 * BOARD_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	board.fill(PREVIEW_BACKGROUND)
	var max_firing_error := 0.0
	var max_support_error := 0.0
	var max_stock_error := 0.0
	var minimum_foot_height := INF
	var declared_floor_height := 0.0
	var minimum_opaque_visible_ratio := 1.0
	var source_vertices_preserved := 0
	var source_indices_preserved := 0
	var locked_profile := {}
	var sample_metrics: Array = []
	var motion_state_ids: Array[String] = []
	for state_index in range(MOTION_STATES.size()):
		var runtime_row := Image.load_from_file(ProjectSettings.globalize_path(PARTIAL_RUNTIME_PATTERN % state_index))
		var board_strip := Image.load_from_file(ProjectSettings.globalize_path(PARTIAL_BOARD_PATTERN % state_index))
		var partial_report := JSON.parse_string(FileAccess.get_file_as_string(PARTIAL_REPORT_PATTERN % state_index)) as Dictionary
		if runtime_row.is_empty() or board_strip.is_empty() or partial_report.is_empty():
			push_error("Missing or invalid A2 multi-yaw batch: %d" % state_index)
			quit(1)
			return
		if not _valid_partial_report(partial_report, state_index):
			push_error("Stale or mismatched A2 multi-yaw batch: %d" % state_index)
			quit(1)
			return
		runtime_atlas.blit_rect(runtime_row, Rect2i(Vector2i.ZERO, runtime_row.get_size()), Vector2i(0, state_index * RUNTIME_FRAME_SIZE.y))
		board.blit_rect(board_strip, Rect2i(Vector2i.ZERO, board_strip.get_size()), Vector2i(0, state_index * board_strip.get_height()))
		motion_state_ids.append(String((partial_report["state"] as Dictionary)["id"]))
		sample_metrics.append_array(partial_report["sample_metrics"] as Array)
		max_firing_error = maxf(max_firing_error, float(partial_report["max_firing_hand_error"]))
		max_support_error = maxf(max_support_error, float(partial_report["max_support_hand_error"]))
		max_stock_error = maxf(max_stock_error, float(partial_report["max_stock_contact_error"]))
		minimum_foot_height = minf(minimum_foot_height, float(partial_report["minimum_foot_height"]))
		minimum_opaque_visible_ratio = minf(minimum_opaque_visible_ratio, float(partial_report["minimum_opaque_visible_ratio"]))
		declared_floor_height = float(partial_report["declared_floor_height"])
		source_vertices_preserved = int(partial_report["source_vertices_preserved"])
		source_indices_preserved = int(partial_report["source_indices_preserved"])
		locked_profile = (partial_report["locked_profile"] as Dictionary).duplicate(true)
	if not PreviewSupport.save_png(self, runtime_atlas, RUNTIME_PATH, "48-frame A2 multi-yaw atlas"):
		return
	if not PreviewSupport.save_png(self, board, BOARD_PATH, "48-frame A2 multi-yaw review board"):
		return
	var yaw_samples_degrees: Array[float] = []
	for yaw_index in range(YAW_FRAME_COUNT):
		yaw_samples_degrees.append(float(yaw_index) * YAW_STEP_DEGREES)
	var report := {
		"schema_version": 1,
		"asset_id": "player_motion_refinement_a2_multiyaw",
		"selected_refinement": SELECTED_REFINEMENT,
		"locked_profile": locked_profile,
		"camera_pitch_degrees": CAMERA_PITCH_DEGREES,
		"yaw_frame_count": YAW_FRAME_COUNT,
		"yaw_step_degrees": YAW_STEP_DEGREES,
		"yaw_samples_degrees": yaw_samples_degrees,
		"motion_state_ids": motion_state_ids,
		"motion_states": MOTION_STATES,
		"sample_count": YAW_FRAME_COUNT * MOTION_STATES.size(),
		"sample_metrics": sample_metrics,
		"contact_tolerance": RefinementRig.CONTACT_TOLERANCE,
		"max_firing_hand_error": max_firing_error,
		"max_support_hand_error": max_support_error,
		"max_stock_contact_error": max_stock_error,
		"minimum_foot_height": minimum_foot_height,
		"declared_floor_height": declared_floor_height,
		"minimum_opaque_visible_ratio": minimum_opaque_visible_ratio,
		"runtime_corner_alpha_max": PreviewSupport.corner_alpha_max(runtime_atlas),
		"source_vertices_preserved": source_vertices_preserved,
		"source_indices_preserved": source_indices_preserved,
		"weapon_attachment": "BoneAttachment3D:firing_hand",
		"production_integration": false,
		"render_pipeline": "four recoverable 12-frame state batches assembled after validation",
	}
	if not _write_json(REPORT_PATH, report):
		return
	print("ASSEMBLE PASS: PlayerMotionRefinementA2MultiYaw 48 samples")
	quit(0)

func _valid_partial_report(report: Dictionary, state_index: int) -> bool:
	var expected_state: Dictionary = MOTION_STATES[state_index]
	var source_size: Dictionary = report.get("source_size", {}) as Dictionary
	var report_state: Dictionary = report.get("state", {}) as Dictionary
	return (
		int(report.get("batch_schema_version", 0)) == BATCH_SCHEMA_VERSION
		and int(report.get("state_index", -1)) == state_index
		and report_state.get("id", "") == expected_state["id"]
		and float(report.get("camera_pitch_degrees", 0.0)) == CAMERA_PITCH_DEGREES
		and int(report.get("yaw_frame_count", 0)) == YAW_FRAME_COUNT
		and float(report.get("yaw_step_degrees", 0.0)) == YAW_STEP_DEGREES
		and int(source_size.get("width", 0)) == SOURCE_SIZE.x
		and int(source_size.get("height", 0)) == SOURCE_SIZE.y
		and int(report.get("cache_schema_version", 0)) == RefinementRig.REVIEW_SKINNED_MESH_CACHE_SCHEMA_VERSION
		and (report.get("sample_metrics", []) as Array).size() == YAW_FRAME_COUNT
	)

func _record_partial_frame(source: Image, state_index: int, yaw_index: int, runtime_row: Image, board_strip: Image) -> void:
	var runtime_frame := source.duplicate()
	runtime_frame.resize(RUNTIME_FRAME_SIZE.x, RUNTIME_FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
	runtime_row.blit_rect(runtime_frame, Rect2i(Vector2i.ZERO, RUNTIME_FRAME_SIZE), Vector2i(yaw_index * RUNTIME_FRAME_SIZE.x, 0))
	var board_frame := source.duplicate()
	board_frame.resize(BOARD_FRAME_SIZE.x, BOARD_FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var board_cell := Vector2i(yaw_index % BOARD_COLUMNS, yaw_index / BOARD_COLUMNS)
	var board_position := board_cell * BOARD_FRAME_SIZE
	board_strip.blend_rect(board_frame, Rect2i(Vector2i.ZERO, BOARD_FRAME_SIZE), board_position)
	board_strip.fill_rect(Rect2i(board_position, Vector2i(BOARD_FRAME_SIZE.x, 4)), STATE_COLORS[state_index])
	board_strip.fill_rect(Rect2i(board_position + Vector2i(0, 4), Vector2i(8 + yaw_index * 2, 3)), Color("ff571f"))

func _write_json(path: String, value: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		push_error("Could not write JSON: " + path)
		quit(1)
		return false
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()
	return true
