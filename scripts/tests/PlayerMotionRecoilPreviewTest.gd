extends SceneTree

const MotionRig = preload("res://scripts/art/PlayerMotionRig.gd")
const RENDERER_PATH := "res://scripts/art/RenderPlayerMotionRecoilCandidates.gd"
const ATLAS_PATH := "res://assets/art/actors/player/technical_previews/player_motion_recoil_candidates.png"
const BOARD_PATH := "res://docs/art/previews/characters-combat/player-motion-recoil-candidates-comparison-v1.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-motion-recoil-metrics-v1.json"
const PLAYER_SCRIPT_PATH := "res://scripts/actors/Player.gd"
const CANDIDATE_PATHS := [
	"res://docs/art/previews/characters-combat/player-motion-recoil-candidate-a-v1.png",
	"res://docs/art/previews/characters-combat/player-motion-recoil-candidate-b-v1.png",
	"res://docs/art/previews/characters-combat/player-motion-recoil-candidate-c-v1.png",
]

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerMotionRecoilPreviewTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(FileAccess.file_exists(RENDERER_PATH), "renderer is missing"):
		return
	var source := FileAccess.get_file_as_string(RENDERER_PATH)
	if not _assert_true(source.contains("CAMERA_PITCH_DEGREES := 45.0"), "camera is not locked to 45 degrees"):
		return
	if not _assert_true(source.contains("GAIT_FRAME_COUNT := 6"), "gait preview must use exactly six frames"):
		return
	if not _assert_true(source.contains("RECOIL_FRAME_COUNT := 6"), "recoil preview must use exactly six frames"):
		return
	if not _assert_true(source.contains("MotionRig.CANDIDATES"), "renderer does not cover all motion candidates"):
		return
	if not _assert_true(source.contains("BoneAttachment3D"), "renderer lacks independent rifle diagnostics"):
		return

	var atlas_texture := ResourceLoader.load(ATLAS_PATH, "Texture2D") as Texture2D
	if not _assert_true(atlas_texture != null, "36-frame motion atlas failed to import"):
		return
	if not _assert_true(atlas_texture.get_size() == Vector2(384, 384), "atlas must be six columns by six candidate/action rows"):
		return
	var atlas := atlas_texture.get_image()
	for row in range(6):
		for frame_index in range(6):
			var frame := atlas.get_region(Rect2i(frame_index * 64, row * 64, 64, 64))
			if not _assert_true(_has_visible_pixel(frame), "empty motion frame: %d/%d" % [row, frame_index]):
				return

	for candidate_path in CANDIDATE_PATHS:
		var candidate_texture := ResourceLoader.load(candidate_path, "Texture2D") as Texture2D
		if not _assert_true(candidate_texture != null, "candidate preview failed to import: " + candidate_path):
			return
		if not _assert_true(candidate_texture.get_size() == Vector2(768, 256), "candidate preview must contain two rows of six 128-pixel frames"):
			return
		if not _assert_true(_corner_alpha_max(candidate_texture.get_image()) < 0.01, "candidate preview has an opaque corner: " + candidate_path):
			return

	var board_texture := ResourceLoader.load(BOARD_PATH, "Texture2D") as Texture2D
	if not _assert_true(board_texture != null, "motion comparison board failed to import"):
		return
	if not _assert_true(board_texture.get_size() == Vector2(1152, 512), "comparison board must be 1152x512"):
		return

	var report := JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH)) as Dictionary
	if not _assert_true(report.get("sample_count", 0) == 36, "metrics report does not cover 36 bounded samples"):
		return
	if not _assert_true(report.get("camera_pitch_degrees", 0.0) == 45.0, "metrics camera is not exactly 45 degrees"):
		return
	if not _assert_true(report.get("candidate_ids", []) == MotionRig.CANDIDATES, "metrics candidate order drifted"):
		return
	if not _assert_true(report.get("max_firing_hand_error", 1.0) <= MotionRig.CONTACT_TOLERANCE, "firing-hand error exceeds tolerance"):
		return
	if not _assert_true(report.get("max_support_hand_error", 1.0) <= MotionRig.CONTACT_TOLERANCE, "support-hand error exceeds tolerance"):
		return
	if not _assert_true(report.get("max_stock_contact_error", 1.0) <= MotionRig.CONTACT_TOLERANCE, "stock-contact error exceeds tolerance"):
		return
	if not _assert_true(report.get("underweighted_leg_ratio", 1.0) < 0.02, "leg-region underweight ratio exceeds tolerance"):
		return
	if not _assert_true(report.get("minimum_opaque_visible_ratio", 0.0) > 0.85, "subject pixels are still broadly translucent"):
		return
	if not _assert_true(report.get("runtime_corner_alpha_max", 1.0) < 0.01, "runtime atlas corners are not transparent"):
		return
	if not _assert_true(report.get("production_integration", true) == false, "preview report incorrectly claims production integration"):
		return
	var player_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	if not _assert_true(not player_source.contains("player_motion_recoil_candidates"), "review atlas leaked into Player.gd"):
		return
	print("TEST PASS: PlayerMotionRecoilPreviewTest %d" % assertions)
	quit(0)

func _has_visible_pixel(image: Image) -> bool:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				return true
	return false

func _corner_alpha_max(image: Image) -> float:
	return maxf(
		maxf(image.get_pixel(0, 0).a, image.get_pixel(image.get_width() - 1, 0).a),
		maxf(image.get_pixel(0, image.get_height() - 1).a, image.get_pixel(image.get_width() - 1, image.get_height() - 1).a)
	)
