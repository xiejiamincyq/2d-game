extends SceneTree

const RefinementRig = preload("res://scripts/art/PlayerMotionRefinementRig.gd")
const RENDERER_PATH := "res://scripts/art/RenderPlayerMotionRefinementA2MultiYaw.gd"
const ATLAS_PATH := "res://assets/art/actors/player/technical_previews/player_motion_refinement_a2_multiyaw.png"
const BOARD_PATH := "res://docs/art/previews/characters-combat/player-motion-refinement-a2-48-frame-v1.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-motion-refinement-a2-multiyaw-metrics-v1.json"
const CACHE_PATH := "res://assets/art/source/player/player_motion_review_skinned_mesh_v1.res"
const PLAYER_SCRIPT_PATH := "res://scripts/actors/Player.gd"
const EXPECTED_STATES := ["GAIT_LEFT", "GAIT_RIGHT", "RECOIL_PEAK", "RECOVERY_TAIL"]

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerMotionRefinementA2MultiYawTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(FileAccess.file_exists(RENDERER_PATH), "A2 multi-yaw renderer is missing"):
		return
	var source := FileAccess.get_file_as_string(RENDERER_PATH)
	if not _assert_true(source.contains("YAW_FRAME_COUNT := 12"), "renderer must cover twelve directions"):
		return
	if not _assert_true(source.contains("YAW_STEP_DEGREES := 30.0"), "renderer yaw step must be 30 degrees"):
		return
	if not _assert_true(source.contains("CAMERA_PITCH_DEGREES := 45.0"), "camera is not locked to 45 degrees"):
		return
	if not _assert_true(source.contains("rig.rotation_degrees.y = yaw_degrees"), "renderer does not rotate real world geometry"):
		return
	if not _assert_true(source.contains("rig.apply_refinement(SELECTED_REFINEMENT"), "renderer does not lock selected refinement A2"):
		return
	if not _assert_true(source.contains("DisplayServer.get_name().to_lower() == \"headless\""), "renderer lacks a fail-fast guard against the dummy 3D driver"):
		return
	if not _assert_true(FileAccess.file_exists(CACHE_PATH), "deterministic skinned review-mesh cache is missing"):
		return
	if not _assert_true(RefinementRig.REVIEW_SKINNED_MESH_CACHE_SCHEMA_VERSION == 1, "review-mesh cache schema version drifted"):
		return
	var cached_mesh := ResourceLoader.load(CACHE_PATH, "ArrayMesh") as ArrayMesh
	if not _assert_true(cached_mesh != null and cached_mesh.surface_get_array_len(0) == 94652 and cached_mesh.surface_get_array_index_len(0) == 567888, "cached review mesh does not preserve approved topology"):
		return
	var cached_arrays := cached_mesh.surface_get_arrays(0)
	if not _assert_true((cached_arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size() == 94652 * 4, "cached review mesh lacks four-slot bone indices"):
		return
	if not _assert_true((cached_arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).size() == 94652 * 4, "cached review mesh lacks four-slot bone weights"):
		return

	var atlas_texture := ResourceLoader.load(ATLAS_PATH, "Texture2D") as Texture2D
	if not _assert_true(atlas_texture != null, "48-frame A2 multi-yaw atlas failed to import"):
		return
	if not _assert_true(atlas_texture.get_size() == Vector2(768, 256), "atlas must be twelve columns by four rows"):
		return
	var atlas := atlas_texture.get_image()
	for row in range(4):
		for yaw_index in range(12):
			if not _assert_true(_has_visible_pixel(atlas.get_region(Rect2i(yaw_index * 64, row * 64, 64, 64))), "empty multi-yaw frame: %d/%d" % [row, yaw_index]):
				return

	var board_texture := ResourceLoader.load(BOARD_PATH, "Texture2D") as Texture2D
	if not _assert_true(board_texture != null, "A2 multi-yaw review board failed to import"):
		return
	if not _assert_true(board_texture.get_size() == Vector2(1152, 1536), "review board must be 1152x1536"):
		return

	var report := JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH)) as Dictionary
	if not _assert_true(report.get("selected_refinement", "") == "A2", "metrics do not lock selected refinement A2"):
		return
	if not _assert_true(report.get("sample_count", 0) == 48, "metrics do not cover 48 bounded samples"):
		return
	if not _assert_true(report.get("yaw_frame_count", 0) == 12 and report.get("yaw_step_degrees", 0.0) == 30.0, "metrics direction matrix drifted"):
		return
	if not _assert_true(report.get("camera_pitch_degrees", 0.0) == 45.0, "metrics camera is not exactly 45 degrees"):
		return
	if not _assert_true(report.get("motion_state_ids", []) == EXPECTED_STATES, "metrics motion state order drifted"):
		return
	if not _assert_true(report.get("yaw_samples_degrees", []).size() == 12, "metrics lack twelve yaw samples"):
		return
	var locked_profile: Dictionary = report.get("locked_profile", {}) as Dictionary
	if not _assert_true(locked_profile.get("stride", 0.0) == 0.15 and locked_profile.get("lift", 0.0) == 0.085 and locked_profile.get("shoulder_bob", 0.0) == 0.01 and locked_profile.get("recoil_degrees", 0.0) == 4.0, "metrics changed selected A2 base amplitudes"):
		return
	if not _assert_true(report.get("max_firing_hand_error", 1.0) <= RefinementRig.CONTACT_TOLERANCE, "firing-hand error exceeds tolerance"):
		return
	if not _assert_true(report.get("max_support_hand_error", 1.0) <= RefinementRig.CONTACT_TOLERANCE, "support-hand error exceeds tolerance"):
		return
	if not _assert_true(report.get("max_stock_contact_error", 1.0) <= RefinementRig.CONTACT_TOLERANCE, "stock error exceeds tolerance"):
		return
	if not _assert_true(report.get("minimum_foot_height", 0.0) >= report.get("declared_floor_height", 1.0) - 0.0001, "a sampled foot penetrates the floor"):
		return
	if not _assert_true(report.get("minimum_opaque_visible_ratio", 0.0) > 0.85, "subject remains broadly translucent"):
		return
	if not _assert_true(report.get("runtime_corner_alpha_max", 1.0) < 0.01, "runtime atlas corner is not transparent"):
		return
	if not _assert_true(report.get("source_vertices_preserved", 0) == 94652 and report.get("source_indices_preserved", 0) == 567888, "source topology drifted"):
		return
	if not _assert_true(report.get("weapon_attachment", "") == "BoneAttachment3D:firing_hand", "independent rifle attachment drifted"):
		return
	if not _assert_true(report.get("production_integration", true) == false, "report incorrectly claims production integration"):
		return
	var player_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	if not _assert_true(not player_source.contains("player_motion_refinement_a2_multiyaw"), "technical atlas leaked into Player.gd"):
		return
	print("TEST PASS: PlayerMotionRefinementA2MultiYawTest %d" % assertions)
	quit(0)

func _has_visible_pixel(image: Image) -> bool:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				return true
	return false
