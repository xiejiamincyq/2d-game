extends SceneTree

const RefinementRig = preload("res://scripts/art/PlayerMotionRefinementRig.gd")
const RENDERER_PATH := "res://scripts/art/RenderPlayerM2RuntimeAnimationBake.gd"
const READY_PATH := "res://assets/art/actors/player/player_m2_ready_120yaw.png"
const MOVE_PATH := "res://assets/art/actors/player/player_m2_move_120yaw.png"
const FIRE_PATH := "res://assets/art/actors/player/player_m2_fire_120yaw.png"
const BOARD_PATH := "res://docs/art/previews/characters-combat/player-m2-runtime-actions-v1.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-m2-runtime-animation-metrics-v1.json"
const MANIFEST_PATH := "res://docs/art/manifests/characters-combat/player_m2_runtime_animation.preview-v1.json"
const EXPECTED_ACTIONS := ["move", "fire"]
const EXPECTED_RECOIL_PHASES := [0.0, 0.18, 0.35, 0.55, 0.75, 1.0]

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerM2RuntimeAnimationBakeTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(FileAccess.file_exists(RENDERER_PATH), "M2 runtime animation renderer is missing"):
		return
	var renderer_source := FileAccess.get_file_as_string(RENDERER_PATH)
	if not _assert_true(renderer_source.contains("YAW_FRAME_COUNT := 120") and renderer_source.contains("YAW_STEP_DEGREES := 3.0"), "renderer direction matrix drifted"):
		return
	if not _assert_true(renderer_source.contains("ACTION_FRAME_COUNT := 6") and renderer_source.contains("BATCH_COUNT := 12"), "renderer must bake six MOVE and six FIRE frame batches"):
		return
	if not _assert_true(renderer_source.contains("CAMERA_PITCH_DEGREES := 45.0"), "renderer camera is not exactly 45 degrees"):
		return
	if not _assert_true(renderer_source.contains("PlayerM2BakeMaterials.gd"), "renderer bypasses the shared approved M2 materials"):
		return
	if not _assert_true(renderer_source.contains("rig.rotation_degrees.y = yaw_degrees"), "renderer does not rotate real 3D geometry"):
		return
	if not _assert_true(renderer_source.contains("rig.weapon_attachment is BoneAttachment3D"), "renderer does not validate the independent rifle"):
		return

	if not _assert_true(FileAccess.file_exists(READY_PATH), "promoted READY atlas is missing"):
		return
	var ready := Image.load_from_file(ProjectSettings.globalize_path(READY_PATH))
	if not _assert_true(not ready.is_empty() and ready.get_size() == Vector2i(1280, 384), "READY atlas must be one 20 by 6 yaw block"):
		return
	for yaw_index in range(120):
		if not _assert_true(_has_visible_frame(ready, yaw_index, 0), "empty READY yaw frame %d" % yaw_index):
			return

	var action_paths := [MOVE_PATH, FIRE_PATH]
	for action_index in range(action_paths.size()):
		if not _assert_true(FileAccess.file_exists(action_paths[action_index]), "%s atlas is missing" % EXPECTED_ACTIONS[action_index]):
			return
		var atlas := Image.load_from_file(ProjectSettings.globalize_path(action_paths[action_index]))
		if not _assert_true(not atlas.is_empty() and atlas.get_size() == Vector2i(1280, 2304), "%s atlas must contain six stacked 20 by 6 yaw blocks" % EXPECTED_ACTIONS[action_index]):
			return
		for action_frame in range(6):
			for yaw_index in range(120):
				if not _assert_true(_has_visible_frame(atlas, yaw_index, action_frame), "empty %s frame %d yaw %d" % [EXPECTED_ACTIONS[action_index], action_frame, yaw_index]):
					return

	if not _assert_true(FileAccess.file_exists(BOARD_PATH), "runtime action review board is missing"):
		return
	var board := Image.load_from_file(ProjectSettings.globalize_path(BOARD_PATH))
	if not _assert_true(not board.is_empty() and board.get_size() == Vector2i(1152, 1536), "review board must show four states across twelve key angles"):
		return
	if not _assert_true(FileAccess.file_exists(REPORT_PATH), "runtime animation metrics are missing"):
		return
	var report := JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH)) as Dictionary
	if not _assert_true(report.get("selected_material", "") == "M2" and report.get("selected_refinement", "") == "A2", "report does not lock M2/A2"):
		return
	if not _assert_true(report.get("action_ids", []) == EXPECTED_ACTIONS and report.get("action_frame_count", 0) == 6, "report action matrix drifted"):
		return
	if not _assert_true(report.get("yaw_frame_count", 0) == 120 and report.get("yaw_step_degrees", 0.0) == 3.0 and report.get("sample_count", 0) == 1440, "report sample matrix drifted"):
		return
	if not _assert_true(report.get("recoil_phases", []) == EXPECTED_RECOIL_PHASES, "report recoil phases drifted"):
		return
	if not _assert_true((report.get("gait_phases", []) as Array).size() == 6, "report lacks six gait phases"):
		return
	if not _assert_true(report.get("camera_pitch_degrees", 0.0) == 45.0, "report camera is not exactly 45 degrees"):
		return
	if not _assert_true(report.get("minimum_opaque_visible_ratio", 0.0) > 0.85 and report.get("minimum_mean_visible_alpha", 0.0) > 0.90 and report.get("minimum_maximum_alpha", 0.0) >= 0.99, "runtime actions contain broad translucency"):
		return
	if not _assert_true(report.get("ready_corner_alpha_max", 1.0) < 0.01 and report.get("move_corner_alpha_max", 1.0) < 0.01 and report.get("fire_corner_alpha_max", 1.0) < 0.01, "one runtime atlas lacks transparent corners"):
		return
	if not _assert_true(report.get("max_firing_hand_error", 1.0) <= RefinementRig.CONTACT_TOLERANCE and report.get("max_support_hand_error", 1.0) <= RefinementRig.CONTACT_TOLERANCE and report.get("max_stock_contact_error", 1.0) <= RefinementRig.CONTACT_TOLERANCE, "weapon contacts drifted"):
		return
	if not _assert_true(report.get("minimum_foot_height", 0.0) >= report.get("declared_floor_height", 1.0) - 0.0001, "a MOVE/FIRE frame penetrates the floor"):
		return
	if not _assert_true(report.get("body_weapon_source_objects_separate", false) and report.get("weapon_attachment", "") == "BoneAttachment3D:firing_hand", "body and rifle source separation drifted"):
		return
	if not _assert_true(report.get("composite_depth_source", "") == "single 3D SubViewport depth buffer", "runtime action composite lacks shared 3D depth"):
		return
	var file_sizes: Dictionary = report.get("file_sizes_bytes", {}) as Dictionary
	var total_runtime_bytes := int(file_sizes.get("ready_atlas", 0)) + int(file_sizes.get("move_atlas", 0)) + int(file_sizes.get("fire_atlas", 0))
	if not _assert_true(total_runtime_bytes > 0 and total_runtime_bytes == int(report.get("total_runtime_atlas_bytes", -1)) and total_runtime_bytes < 12 * 1024 * 1024, "runtime animation PNGs exceed the bounded 12 MiB budget"):
		return
	if not _assert_true(report.get("total_batch_render_msec", 0) > 0 and report.get("batch_count", 0) == 12, "batch render cost was not measured"):
		return
	if not _assert_true(report.get("production_integration", true) == false, "bake report incorrectly claims runtime integration"):
		return
	if not _assert_true(FileAccess.file_exists(MANIFEST_PATH), "runtime animation manifest is missing"):
		return
	print("TEST PASS: PlayerM2RuntimeAnimationBakeTest %d" % assertions)
	quit(0)

func _has_visible_frame(atlas: Image, yaw_index: int, action_frame: int) -> bool:
	var cell := Vector2i(yaw_index % 20, action_frame * 6 + yaw_index / 20)
	var frame := atlas.get_region(Rect2i(cell * 64, Vector2i(64, 64)))
	for y in range(frame.get_height()):
		for x in range(frame.get_width()):
			if frame.get_pixel(x, y).a > 0.05:
				return true
	return false
