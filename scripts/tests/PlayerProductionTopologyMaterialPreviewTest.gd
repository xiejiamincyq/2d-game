extends SceneTree

const RENDERER_PATH := "res://scripts/art/RenderPlayerProductionTopologyMaterialPreview.gd"
const BUILDER_PATH := "res://scripts/art/BuildPlayerProductionTopologyCandidate.gd"
const SOURCE_MESH_PATH := "res://assets/art/source/player/player_motion_review_skinned_mesh_v1.res"
const CANDIDATE_MESH_PATH := "res://assets/art/source/player/player_production_lod_topology_candidate_v1.res"
const ATLAS_PATH := "res://assets/art/actors/player/technical_previews/player_production_material_candidates.png"
const MATERIAL_BOARD_PATH := "res://docs/art/previews/characters-combat/player-production-material-comparison-v1.png"
const TOPOLOGY_BOARD_PATH := "res://docs/art/previews/characters-combat/player-production-topology-comparison-v1.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-production-topology-material-metrics-v1.json"
const PLAYER_SCRIPT_PATH := "res://scripts/actors/Player.gd"
const EXPECTED_MATERIALS := ["M1", "M2", "M3"]

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerProductionTopologyMaterialPreviewTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(FileAccess.file_exists(BUILDER_PATH), "topology candidate builder is missing"):
		return
	if not _assert_true(FileAccess.file_exists(RENDERER_PATH), "topology/material renderer is missing"):
		return
	var renderer_source := FileAccess.get_file_as_string(RENDERER_PATH)
	if not _assert_true(renderer_source.contains("CAMERA_PITCH_DEGREES := 45.0"), "camera is not locked to exactly 45 degrees"):
		return
	if not _assert_true(renderer_source.contains("rig.rotation_degrees.y = yaw_degrees"), "renderer does not rotate real world geometry"):
		return
	if not _assert_true(renderer_source.contains("source_viewport_and_rig[\"rig\"].weapon_attachment.visible = false") and renderer_source.contains("candidate_viewport_and_rig[\"rig\"].weapon_attachment.visible = false"), "topology IoU is biased by the unchanged rifle silhouette"):
		return
	if not _assert_true(renderer_source.contains("BoneAttachment3D"), "renderer does not validate the independent rifle attachment"):
		return
	if not _assert_true(renderer_source.contains("_read_json_dictionary"), "renderer lacks safe recovery for missing or invalid batch reports"):
		return
	if not _assert_true(renderer_source.contains("if viewport_and_rig.is_empty()"), "renderer does not stop safely after rig-build failure"):
		return
	if not _assert_true(FileAccess.file_exists(SOURCE_MESH_PATH), "approved source mesh is missing"):
		return
	if not _assert_true(FileAccess.file_exists(CANDIDATE_MESH_PATH), "compact topology candidate is missing"):
		return
	var source_mesh := ResourceLoader.load(SOURCE_MESH_PATH, "ArrayMesh") as ArrayMesh
	var candidate_mesh := ResourceLoader.load(CANDIDATE_MESH_PATH, "ArrayMesh") as ArrayMesh
	if not _assert_true(source_mesh != null and source_mesh.surface_get_array_len(0) == 94652 and source_mesh.surface_get_array_index_len(0) == 567888, "approved source topology drifted"):
		return
	if not _assert_true(candidate_mesh != null and candidate_mesh.get_surface_count() == 1, "topology candidate is invalid"):
		return
	if not _assert_true(candidate_mesh.surface_get_array_len(0) < source_mesh.surface_get_array_len(0), "candidate did not compact referenced vertices"):
		return
	var index_ratio := float(candidate_mesh.surface_get_array_index_len(0)) / float(source_mesh.surface_get_array_index_len(0))
	if not _assert_true(index_ratio >= 0.20 and index_ratio <= 0.65, "candidate index ratio is outside the bounded review target"):
		return
	var candidate_arrays := candidate_mesh.surface_get_arrays(0)
	if not _assert_true((candidate_arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size() == candidate_mesh.surface_get_array_len(0) * 4, "candidate lacks four-slot bone indices"):
		return
	if not _assert_true((candidate_arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).size() == candidate_mesh.surface_get_array_len(0) * 4, "candidate lacks four-slot bone weights"):
		return

	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	if not _assert_true(not atlas.is_empty() and atlas.get_size() == Vector2i(256, 192), "material atlas must be four columns by three rows"):
		return
	for row in range(3):
		for column in range(4):
			if not _assert_true(_has_visible_pixel(atlas.get_region(Rect2i(column * 64, row * 64, 64, 64))), "empty material frame: %d/%d" % [row, column]):
				return
	var material_board := Image.load_from_file(ProjectSettings.globalize_path(MATERIAL_BOARD_PATH))
	if not _assert_true(not material_board.is_empty() and material_board.get_size() == Vector2i(768, 576), "material board must be 768x576"):
		return
	var topology_board := Image.load_from_file(ProjectSettings.globalize_path(TOPOLOGY_BOARD_PATH))
	if not _assert_true(not topology_board.is_empty() and topology_board.get_size() == Vector2i(1152, 768), "topology board must be 1152x768"):
		return

	var report := JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH)) as Dictionary
	if not _assert_true(report.get("camera_pitch_degrees", 0.0) == 45.0, "metrics camera is not exactly 45 degrees"):
		return
	if not _assert_true(report.get("material_ids", []) == EXPECTED_MATERIALS, "metrics material order drifted"):
		return
	var material_reports: Array = report.get("material_reports", []) as Array
	if not _assert_true(material_reports.size() == 3, "metrics do not contain three material reports"):
		return
	if not _assert_true(float((material_reports[1] as Dictionary).get("mean_visible_luminance", 0.0)) > float((material_reports[0] as Dictionary).get("mean_visible_luminance", 1.0)) + 0.08, "M2 is not visibly lighter than M1"):
		return
	if not _assert_true(float((material_reports[1] as Dictionary).get("mean_visible_luminance", 0.0)) > float((material_reports[2] as Dictionary).get("mean_visible_luminance", 1.0)) + 0.08, "M2 is not visibly lighter than M3"):
		return
	if not _assert_true(float((material_reports[2] as Dictionary).get("magenta_visible_ratio", 0.0)) > 0.002, "M3 lacks a readable magenta secondary accent"):
		return
	if not _assert_true(report.get("topology_yaw_count", 0) == 12 and report.get("topology_yaw_step_degrees", 0.0) == 30.0, "topology yaw matrix drifted"):
		return
	if not _assert_true(report.get("minimum_silhouette_iou", 0.0) >= 0.97, "topology candidate failed the silhouette gate"):
		return
	if not _assert_true(report.get("minimum_opaque_visible_ratio", 0.0) > 0.85, "material preview contains broad translucency"):
		return
	if not _assert_true(report.get("runtime_corner_alpha_max", 1.0) < 0.01, "material atlas corners are not transparent"):
		return
	if not _assert_true(report.get("weapon_attachment", "") == "BoneAttachment3D:firing_hand", "independent rifle attachment drifted"):
		return
	if not _assert_true(report.get("production_integration", true) == false, "report incorrectly claims production integration"):
		return
	var player_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	if not _assert_true(not player_source.contains("player_production_material_candidates"), "technical preview leaked into Player.gd"):
		return
	print("TEST PASS: PlayerProductionTopologyMaterialPreviewTest %d" % assertions)
	quit(0)

func _has_visible_pixel(image: Image) -> bool:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				return true
	return false
