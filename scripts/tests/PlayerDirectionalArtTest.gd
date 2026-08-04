extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")

const FRAME_COUNT := 72
const FRAME_STEP_DEGREES := 5
const ATLAS_COLUMNS := 9
const ATLAS_ROWS := 8
const FRAME_SIZE := Vector2i(64, 64)
const DIRECTIONS_PATH := "res://assets/art/actors/player/directions"
const ATLAS_PATH := "res://assets/art/actors/player/player_directional_atlas.png"

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerDirectionalArtTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var player: CharacterBody2D = PlayerScript.new()
	root.add_child(player)
	await process_frame

	if not _assert_true(player.has_method("direction_frame_index"), "player does not expose the 5-degree frame mapping"):
		return
	if not _assert_true(player.has_method("direction_frame_rect"), "player does not expose atlas frame rectangles"):
		return
	if not _assert_true(player.player_directional_atlas.get_size() == Vector2(576, 512), "runtime direction atlas texture did not load"):
		return
	if not _assert_true(player.player_weapon_texture.get_size() == Vector2(1024, 1024), "runtime weapon texture did not load"):
		return

	for frame in range(FRAME_COUNT):
		var angle := deg_to_rad(float(frame * FRAME_STEP_DEGREES))
		if not _assert_true(player.direction_frame_index(angle) == frame, "angle %d degrees did not select frame %d" % [frame * FRAME_STEP_DEGREES, frame]):
			return
	if not _assert_true(player.direction_frame_index(deg_to_rad(-5.0)) == 71, "negative angles do not wrap to frame 71"):
		return
	if not _assert_true(player.direction_frame_index(TAU) == 0, "360 degrees does not wrap to frame 0"):
		return
	if not _assert_true(player.direction_frame_index(deg_to_rad(2.49)) == 0, "angle below the first half-step did not stay on frame 0"):
		return
	if not _assert_true(player.direction_frame_index(deg_to_rad(2.51)) == 1, "angle above the first half-step did not advance to frame 1"):
		return
	if not _assert_true(player.direction_frame_index(deg_to_rad(357.49)) == 71, "angle below the wrap half-step did not stay on frame 71"):
		return
	if not _assert_true(player.direction_frame_index(deg_to_rad(357.51)) == 0, "angle above the wrap half-step did not advance to frame 0"):
		return
	if not _assert_true(player.direction_frame_rect(0) == Rect2(Vector2.ZERO, Vector2(FRAME_SIZE)), "frame 0 atlas rectangle is wrong"):
		return
	if not _assert_true(player.direction_frame_rect(71) == Rect2(Vector2(512, 448), Vector2(FRAME_SIZE)), "frame 71 atlas rectangle is wrong"):
		return

	var direction_dir := DirAccess.open(DIRECTIONS_PATH)
	if not _assert_true(direction_dir != null, "direction frame directory is missing"):
		return
	var frame_files := PackedStringArray()
	for file_name in direction_dir.get_files():
		if file_name.ends_with(".png"):
			frame_files.append(file_name)
	if not _assert_true(frame_files.size() == FRAME_COUNT, "expected 72 direction PNGs, found %d" % frame_files.size()):
		return
	for frame in range(FRAME_COUNT):
		var expected_name := "angle_%03d.png" % (frame * FRAME_STEP_DEGREES)
		if not _assert_true(frame_files.has(expected_name), "missing direction frame " + expected_name):
			return

	var atlas := Image.load_from_file(ATLAS_PATH)
	if not _assert_true(not atlas.is_empty(), "direction atlas could not be loaded"):
		return
	if not _assert_true(atlas.get_size() == Vector2i(ATLAS_COLUMNS, ATLAS_ROWS) * FRAME_SIZE, "direction atlas is not 576x512"):
		return

	player.queue_free()
	await process_frame
	print("TEST PASS: PlayerDirectionalArtTest %d" % assertions)
	quit(0)
