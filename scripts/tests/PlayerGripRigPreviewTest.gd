extends SceneTree

const RENDERER_PATH := "res://scripts/art/RenderPlayerGripRigPreview.gd"
const ATLAS_PATH := "res://assets/art/actors/player/technical_previews/player_grip_rig_a_preview_v7.png"
const BOARD_PATH := "res://docs/art/previews/characters-combat/player-grip-rig-a-36-frame-v7.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-grip-rig-a-metrics-v7.json"
const PLAYER_SCRIPT_PATH := "res://scripts/actors/Player.gd"

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerGripRigPreviewTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(FileAccess.file_exists(RENDERER_PATH), "renderer is missing"):
		return
	var source := FileAccess.get_file_as_string(RENDERER_PATH)
	if not _assert_true(source.contains("CAMERA_PITCH_DEGREES := 45.0"), "camera is not locked to 45 degrees"):
		return
	if not _assert_true(source.contains("FRAME_COUNT := 12"), "renderer must sample twelve yaw angles"):
		return
	if not _assert_true(source.contains("GripRig.ACTIONS"), "renderer does not cover all approved action keys"):
		return
	if not _assert_true(source.contains("BoneAttachment3D"), "renderer lacks independent weapon attachment diagnostics"):
		return

	var atlas_texture := ResourceLoader.load(ATLAS_PATH, "Texture2D") as Texture2D
	if not _assert_true(atlas_texture != null, "36-frame atlas failed to import"):
		return
	if not _assert_true(atlas_texture.get_size() == Vector2(768, 192), "atlas must be twelve columns by three action rows"):
		return
	var atlas := atlas_texture.get_image()
	for action_index in range(3):
		for frame_index in range(12):
			var frame := atlas.get_region(Rect2i(frame_index * 64, action_index * 64, 64, 64))
			if not _assert_true(_has_visible_pixel(frame), "empty action/yaw frame: %d/%d" % [action_index, frame_index]):
				return

	var board_texture := ResourceLoader.load(BOARD_PATH, "Texture2D") as Texture2D
	if not _assert_true(board_texture != null, "review board failed to import"):
		return
	if not _assert_true(board_texture.get_size() == Vector2(1152, 1152), "review board must be 1152x1152"):
		return

	var report := JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH)) as Dictionary
	if not _assert_true(report.get("sample_count", 0) == 36, "metrics report does not cover 36 samples"):
		return
	if not _assert_true(report.get("max_firing_hand_error", 1.0) <= 0.006, "firing-hand error exceeds tolerance"):
		return
	if not _assert_true(report.get("max_support_hand_error", 1.0) <= 0.006, "support-hand error exceeds tolerance"):
		return
	if not _assert_true(report.get("max_stock_contact_error", 1.0) <= 0.006, "stock contact error exceeds tolerance"):
		return
	if not _assert_true(report.get("underweighted_arm_ratio", 1.0) < 0.02, "arm-region underweight ratio exceeds tolerance"):
		return
	var player_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	if not _assert_true(not player_source.contains("player_grip_rig_a_preview"), "review atlas leaked into Player.gd"):
		return
	print("TEST PASS: PlayerGripRigPreviewTest %d" % assertions)
	quit(0)

func _has_visible_pixel(image: Image) -> bool:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				return true
	return false
