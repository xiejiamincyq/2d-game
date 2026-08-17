extends SceneTree

const RefinementRig = preload("res://scripts/art/PlayerMotionRefinementRig.gd")
const RENDERER_PATH := "res://scripts/art/RenderPlayerM2Ready120YawBake.gd"
const MATERIALS_PATH := "res://scripts/art/PlayerM2BakeMaterials.gd"
const CANDIDATE_MESH_PATH := "res://assets/art/source/player/player_production_lod_topology_candidate_v1.res"
const COMPOSITE_ATLAS_PATH := "res://assets/art/actors/player/technical_previews/player_m2_ready_120yaw_composite.png"
const BODY_ATLAS_PATH := "res://assets/art/actors/player/technical_previews/player_m2_ready_120yaw_body.png"
const WEAPON_ATLAS_PATH := "res://assets/art/actors/player/technical_previews/player_m2_ready_120yaw_weapon.png"
const BOARD_PATH := "res://docs/art/previews/characters-combat/player-m2-ready-120yaw-review-v1.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-m2-ready-120yaw-metrics-v1.json"
const MANIFEST_PATH := "res://docs/art/manifests/characters-combat/player_m2_ready_120yaw_bake.preview-v1.json"
const PLAYER_SCRIPT_PATH := "res://scripts/actors/Player.gd"
const EXPECTED_LAYERS := ["composite", "body", "weapon"]

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerM2Ready120YawBakeTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(FileAccess.file_exists(RENDERER_PATH), "120-yaw renderer is missing"):
		return
	if not _assert_true(FileAccess.file_exists(MATERIALS_PATH), "shared M2 bake material helper is missing"):
		return
	var renderer_source := FileAccess.get_file_as_string(RENDERER_PATH)
	if not _assert_true(renderer_source.contains("PlayerM2BakeMaterials.gd") and renderer_source.contains("BakeMaterials.body_material()") and renderer_source.contains("BakeMaterials.weapon_material()"), "READY renderer bypasses the shared M2 material source"):
		return
	var materials_source := FileAccess.get_file_as_string(MATERIALS_PATH)
	if not _assert_true(materials_source.contains("base_color\", Color(\"aeb8bc\")") and materials_source.contains("metallic_level\", 0.48") and materials_source.contains("roughness_level\", 0.55") and materials_source.contains("WEAPON_ACCENT := Color(\"c66a32\")"), "approved M2 material parameters drifted"):
		return
	if not _assert_true(renderer_source.contains("YAW_FRAME_COUNT := 120"), "renderer must cover 120 real yaw angles"):
		return
	if not _assert_true(renderer_source.contains("YAW_STEP_DEGREES := 3.0"), "renderer yaw step must be 3 degrees"):
		return
	if not _assert_true(renderer_source.contains("ATLAS_COLUMNS := 20") and renderer_source.contains("ATLAS_ROWS := 6"), "atlas must use a compact 20 by 6 layout"):
		return
	if not _assert_true(renderer_source.contains("CAMERA_PITCH_DEGREES := 45.0"), "camera is not locked to exactly 45 degrees"):
		return
	if not _assert_true(renderer_source.contains("SELECTED_MATERIAL := \"M2\""), "renderer does not lock approved M2"):
		return
	if not _assert_true(renderer_source.contains("SELECTED_POSE := \"READY\""), "renderer does not lock the bounded READY pose"):
		return
	if not _assert_true(renderer_source.contains("rig.rotation_degrees.y = yaw_degrees"), "renderer does not rotate real 3D geometry"):
		return
	if not _assert_true(renderer_source.contains("rig.body_mesh.visible") and renderer_source.contains("rig.weapon_attachment.visible"), "renderer does not isolate body and weapon source objects"):
		return
	if not _assert_true(renderer_source.contains("DisplayServer.get_name().to_lower() == \"headless\""), "renderer lacks a fail-fast guard against dummy 3D rendering"):
		return
	if not _assert_true(FileAccess.file_exists(CANDIDATE_MESH_PATH), "approved automatic LOD bake candidate is missing"):
		return
	var candidate_mesh := ResourceLoader.load(CANDIDATE_MESH_PATH, "ArrayMesh") as ArrayMesh
	if not _assert_true(candidate_mesh != null and candidate_mesh.surface_get_array_len(0) == 47326 and candidate_mesh.surface_get_array_index_len(0) == 283944, "bake candidate topology drifted"):
		return

	var atlas_paths := [COMPOSITE_ATLAS_PATH, BODY_ATLAS_PATH, WEAPON_ATLAS_PATH]
	for layer_index in range(atlas_paths.size()):
		if not _assert_true(FileAccess.file_exists(atlas_paths[layer_index]), "%s atlas is missing" % EXPECTED_LAYERS[layer_index]):
			return
		var atlas := Image.load_from_file(ProjectSettings.globalize_path(atlas_paths[layer_index]))
		if not _assert_true(not atlas.is_empty() and atlas.get_size() == Vector2i(1280, 384), "%s atlas must be 20 columns by 6 rows" % EXPECTED_LAYERS[layer_index]):
			return
		for yaw_index in range(120):
			var cell := Vector2i(yaw_index % 20, yaw_index / 20)
			if not _assert_true(_has_visible_pixel(atlas.get_region(Rect2i(cell * 64, Vector2i(64, 64)))), "empty %s frame at yaw index %d" % [EXPECTED_LAYERS[layer_index], yaw_index]):
				return

	if not _assert_true(FileAccess.file_exists(BOARD_PATH), "review board is missing"):
		return
	var board := Image.load_from_file(ProjectSettings.globalize_path(BOARD_PATH))
	if not _assert_true(not board.is_empty() and board.get_size() == Vector2i(1152, 384), "review board must show twelve key angles in a 6 by 2 grid"):
		return
	if not _assert_true(FileAccess.file_exists(REPORT_PATH), "metrics report is missing"):
		return
	var report := JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH)) as Dictionary
	if not _assert_true(report.get("selected_material", "") == "M2" and report.get("selected_pose", "") == "READY", "metrics do not lock M2 READY"):
		return
	if not _assert_true(report.get("sample_count", 0) == 120 and report.get("yaw_frame_count", 0) == 120 and report.get("yaw_step_degrees", 0.0) == 3.0, "metrics direction matrix drifted"):
		return
	var yaw_range: Dictionary = report.get("yaw_range_degrees", {}) as Dictionary
	if not _assert_true(yaw_range.get("start", -1.0) == 0.0 and yaw_range.get("end", -1.0) == 357.0 and yaw_range.get("step", -1.0) == 3.0, "metrics yaw range drifted"):
		return
	if not _assert_true(report.get("camera_pitch_degrees", 0.0) == 45.0, "metrics camera is not exactly 45 degrees"):
		return
	if not _assert_true(report.get("atlas_columns", 0) == 20 and report.get("atlas_rows", 0) == 6, "metrics atlas layout drifted"):
		return
	if not _assert_true(report.get("layer_ids", []) == EXPECTED_LAYERS, "metrics layer order drifted"):
		return
	if not _assert_true(report.get("body_weapon_source_objects_separate", false), "metrics do not preserve separate 3D source objects"):
		return
	if not _assert_true(report.get("runtime_recommendation", "") == "use composite atlas for correct per-pixel body/weapon depth", "metrics misrepresent diagnostic layers as depth-correct recomposition"):
		return
	if not _assert_true(report.get("composite_depth_source", "") == "single 3D SubViewport depth buffer", "composite atlas lacks one shared 3D depth source"):
		return
	if not _assert_true(report.get("batch_count", 0) == 10 and report.get("batch_size", 0) == 12, "recoverable batch structure drifted"):
		return
	if not _assert_true(report.get("minimum_composite_opaque_visible_ratio", 0.0) > 0.85 and report.get("minimum_body_opaque_visible_ratio", 0.0) > 0.85, "body or depth-correct composite contains broad translucency"):
		return
	if not _assert_true(report.get("minimum_weapon_opaque_visible_ratio", 0.0) > 0.75 and report.get("minimum_weapon_mean_visible_alpha", 0.0) > 0.85 and report.get("minimum_weapon_maximum_alpha", 0.0) >= 0.99, "thin profile weapon layer lacks a solid opaque core"):
		return
	if not _assert_true(report.get("composite_corner_alpha_max", 1.0) < 0.01 and report.get("body_corner_alpha_max", 1.0) < 0.01 and report.get("weapon_corner_alpha_max", 1.0) < 0.01, "one atlas lacks transparent corners"):
		return
	if not _assert_true(report.get("max_firing_hand_error", 1.0) <= RefinementRig.CONTACT_TOLERANCE and report.get("max_support_hand_error", 1.0) <= RefinementRig.CONTACT_TOLERANCE and report.get("max_stock_contact_error", 1.0) <= RefinementRig.CONTACT_TOLERANCE, "approved weapon contacts drifted"):
		return
	var file_sizes: Dictionary = report.get("file_sizes_bytes", {}) as Dictionary
	var total_atlas_bytes := int(file_sizes.get("composite_atlas", 0)) + int(file_sizes.get("body_atlas", 0)) + int(file_sizes.get("weapon_atlas", 0))
	if not _assert_true(total_atlas_bytes > 0 and total_atlas_bytes == int(report.get("total_atlas_bytes", -1)) and total_atlas_bytes < 6 * 1024 * 1024, "three 120-yaw atlases exceed the bounded 6 MiB proof budget"):
		return
	if not _assert_true(report.get("total_batch_render_msec", 0) > 0, "render timing was not measured"):
		return
	if not _assert_true(report.get("production_integration", true) == false, "report incorrectly claims production integration"):
		return
	if not _assert_true(FileAccess.file_exists(MANIFEST_PATH), "preview manifest is missing"):
		return
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	if not _assert_true((manifest.get("selection_approval", {}) as Dictionary).get("decision", "") == "M2", "manifest does not record the M2 selection"):
		return
	var player_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	if not _assert_true(not player_source.contains("player_m2_ready_120yaw"), "technical bake leaked into Player.gd"):
		return
	print("TEST PASS: PlayerM2Ready120YawBakeTest %d" % assertions)
	quit(0)

func _has_visible_pixel(image: Image) -> bool:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				return true
	return false
