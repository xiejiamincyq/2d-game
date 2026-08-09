extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")

const FRAME_COUNT := 120
const FRAME_STEP_DEGREES := 3
const ATLAS_COLUMNS := 12
const ATLAS_ROWS := 10
const FRAME_SIZE := Vector2i(64, 64)
const DIRECTIONS_PATH := "res://assets/art/actors/player/turnaround_directions"
const ATLAS_PATH := "res://assets/art/actors/player/player_turnaround_atlas.png"

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
	if not _assert_true(player.player_directional_atlas.get_size() == Vector2(768, 640), "runtime 120-frame direction atlas texture did not load"):
		return
	if not _assert_true(player.player_weapon_texture.get_size() == Vector2(1024, 1024), "runtime weapon texture did not load"):
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
	if not _assert_true(player.direction_frame_rect(119) == Rect2(Vector2(704, 576), Vector2(FRAME_SIZE)), "frame 119 atlas rectangle is wrong"):
		return

	var direction_dir := DirAccess.open(DIRECTIONS_PATH)
	if not _assert_true(direction_dir != null, "direction frame directory is missing"):
		return
	var frame_files := PackedStringArray()
	for file_name in direction_dir.get_files():
		if file_name.ends_with(".png"):
			frame_files.append(file_name)
	if not _assert_true(frame_files.size() == FRAME_COUNT, "expected 120 direction PNGs, found %d" % frame_files.size()):
		return
	for frame in range(FRAME_COUNT):
		var expected_name := "angle_%03d.png" % (frame * FRAME_STEP_DEGREES)
		if not _assert_true(frame_files.has(expected_name), "missing direction frame " + expected_name):
			return

	var atlas_texture := ResourceLoader.load(ATLAS_PATH, "Texture2D") as Texture2D
	if not _assert_true(atlas_texture != null, "direction atlas could not be loaded"):
		return
	var atlas := atlas_texture.get_image()
	if not _assert_true(atlas != null and not atlas.is_empty(), "direction atlas image could not be read"):
		return
	if not _assert_true(atlas.get_size() == Vector2i(ATLAS_COLUMNS, ATLAS_ROWS) * FRAME_SIZE, "direction atlas is not 768x640"):
		return

	var cardinal_pixels: Array[PackedByteArray] = []
	for angle in [0, 90, 180, 270]:
		var frame_texture := ResourceLoader.load(DIRECTIONS_PATH + "/angle_%03d.png" % angle, "Texture2D") as Texture2D
		if not _assert_true(frame_texture != null, "cardinal frame %d could not be loaded" % angle):
			return
		var frame_image := frame_texture.get_image()
		if not _assert_true(frame_image != null and not frame_image.is_empty(), "cardinal frame %d image could not be read" % angle):
			return
		if not _assert_true(frame_image.get_size() == FRAME_SIZE, "cardinal frame %d is not 64x64" % angle):
			return
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
