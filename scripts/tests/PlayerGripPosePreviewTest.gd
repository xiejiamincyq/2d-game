extends SceneTree

const ATLAS_PATH := "res://assets/art/actors/player/technical_previews/player_grip_pose_candidates.png"
const BOARD_PATH := "res://docs/art/previews/characters-combat/player-grip-pose-candidates-runtime-v1.png"
const PLAYER_SCRIPT_PATH := "res://scripts/actors/Player.gd"
const SOURCE_PATHS := [
	"res://assets/art/source/player/grip_pose_candidates/player_grip_pose_a_alpha_v1.png",
	"res://assets/art/source/player/grip_pose_candidates/player_grip_pose_b_alpha_v1.png",
	"res://assets/art/source/player/grip_pose_candidates/player_grip_pose_c_alpha_v1.png",
]

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerGripPosePreviewTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var atlas_texture := ResourceLoader.load(ATLAS_PATH, "Texture2D") as Texture2D
	if not _assert_true(atlas_texture != null, "runtime review atlas failed to import"):
		return
	if not _assert_true(atlas_texture.get_size() == Vector2(576, 64), "runtime atlas must contain nine 64px frames"):
		return
	var atlas := atlas_texture.get_image()
	for frame_index in range(9):
		var frame := atlas.get_region(Rect2i(frame_index * 64, 0, 64, 64))
		if not _assert_true(_has_visible_pixel(frame), "runtime frame %d is empty" % frame_index):
			return

	var board_texture := ResourceLoader.load(BOARD_PATH, "Texture2D") as Texture2D
	if not _assert_true(board_texture != null, "comparison board failed to import"):
		return
	if not _assert_true(board_texture.get_size() == Vector2(1280, 720), "comparison board must be 1280x720"):
		return

	for source_path in SOURCE_PATHS:
		var texture := ResourceLoader.load(source_path, "Texture2D") as Texture2D
		if not _assert_true(texture != null, "source sheet failed to import: " + source_path):
			return
		var image := texture.get_image()
		if not _assert_true(image.get_size() == Vector2i(1254, 1254), "source sheet dimensions changed: " + source_path):
			return
		if not _assert_true(image.get_pixel(0, 0).a < 0.01, "source sheet corner is not transparent: " + source_path):
			return

	var player_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	if not _assert_true(not player_source.contains("player_grip_pose_candidates.png"), "review atlas leaked into Player.gd"):
		return
	print("TEST PASS: PlayerGripPosePreviewTest %d" % assertions)
	quit(0)

func _has_visible_pixel(image: Image) -> bool:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				return true
	return false
