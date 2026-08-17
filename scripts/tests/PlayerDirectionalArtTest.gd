extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")

const FRAME_COUNT := 120
const FRAME_STEP_DEGREES := 3
const ATLAS_COLUMNS := 20
const ATLAS_ROWS := 6
const FRAME_SIZE := Vector2i(64, 64)
const ATLAS_PATH := "res://assets/art/actors/player/player_m2_ready_120yaw.png"

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerDirectionalArtTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(FileAccess.file_exists(ATLAS_PATH), "120-frame turnaround atlas is missing"):
		return
	var player: CharacterBody2D = PlayerScript.new()
	root.add_child(player)
	await process_frame

	if not _assert_true(player.has_method("direction_frame_index"), "player does not expose the 3-degree frame mapping"):
		return
	if not _assert_true(player.has_method("direction_frame_rect"), "player does not expose atlas frame rectangles"):
		return
	if not _assert_true(player.player_ready_atlas.get_size() == Vector2(1280, 384), "runtime M2 READY texture did not load"):
		return

	for frame in range(FRAME_COUNT):
		var angle := deg_to_rad(float(frame * FRAME_STEP_DEGREES))
		if not _assert_true(player.direction_frame_index(angle) == frame, "angle %d degrees did not select frame %d" % [frame * FRAME_STEP_DEGREES, frame]):
			return
	if not _assert_true(player.direction_frame_index(deg_to_rad(-3.0)) == 119, "negative angles do not wrap to frame 119"):
		return
	if not _assert_true(player.direction_frame_index(TAU) == 0, "360 degrees does not wrap to frame 0"):
		return
	if not _assert_true(player.direction_frame_index(deg_to_rad(1.49)) == 0, "angle below the first half-step did not stay on frame 0"):
		return
	if not _assert_true(player.direction_frame_index(deg_to_rad(1.51)) == 1, "angle above the first half-step did not advance to frame 1"):
		return
	if not _assert_true(player.direction_frame_index(deg_to_rad(358.49)) == 119, "angle below the wrap half-step did not stay on frame 119"):
		return
	if not _assert_true(player.direction_frame_index(deg_to_rad(358.51)) == 0, "angle above the wrap half-step did not advance to frame 0"):
		return
	if not _assert_true(player.direction_frame_rect(0) == Rect2(Vector2.ZERO, Vector2(FRAME_SIZE)), "frame 0 atlas rectangle is wrong"):
		return
	if not _assert_true(player.direction_frame_rect(119) == Rect2(Vector2(1216, 320), Vector2(FRAME_SIZE)), "frame 119 atlas rectangle is wrong"):
		return

	var atlas_texture := ResourceLoader.load(ATLAS_PATH, "Texture2D") as Texture2D
	if not _assert_true(atlas_texture != null, "direction atlas could not be loaded"):
		return
	var atlas := atlas_texture.get_image()
	if not _assert_true(atlas != null and not atlas.is_empty(), "direction atlas image could not be read"):
		return
	if not _assert_true(atlas.get_size() == Vector2i(ATLAS_COLUMNS, ATLAS_ROWS) * FRAME_SIZE, "M2 READY atlas is not 1280x384"):
		return

	var cardinal_pixels: Array[PackedByteArray] = []
	for angle in [0, 90, 180, 270]:
		var frame_index: int = int(angle) / FRAME_STEP_DEGREES
		var frame_image := atlas.get_region(Rect2i(player.direction_frame_rect(frame_index)))
		if not _assert_true(frame_image.get_pixel(0, 0).a == 0.0, "cardinal frame %d does not have a transparent corner" % angle):
			return
		cardinal_pixels.append(frame_image.get_data())
	for first in range(cardinal_pixels.size()):
		for second in range(first + 1, cardinal_pixels.size()):
			if not _assert_true(cardinal_pixels[first] != cardinal_pixels[second], "cardinal directions %d and %d are not visually distinct" % [first, second]):
				return

	player.queue_free()
	await process_frame
	print("TEST PASS: PlayerDirectionalArtTest %d" % assertions)
	quit(0)
