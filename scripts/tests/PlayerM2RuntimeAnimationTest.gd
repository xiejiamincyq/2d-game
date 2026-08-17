extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")

const READY_PATH := "res://assets/art/actors/player/player_m2_ready_120yaw.png"
const MOVE_PATH := "res://assets/art/actors/player/player_m2_move_120yaw.png"
const FIRE_PATH := "res://assets/art/actors/player/player_m2_fire_120yaw.png"
const FRAME_SIZE := Vector2(64.0, 64.0)

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerM2RuntimeAnimationTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/actors/Player.gd")
	if not _assert_true(not source.contains("player_turnaround_atlas.png"), "legacy turnaround atlas remains in production"):
		return
	if not _assert_true(not source.contains("player_weapon.png"), "standalone 2D rifle remains in production"):
		return
	if not _assert_true(not source.contains("action_slices/player_b_action_slice"), "one-direction action-slice exception remains"):
		return
	if not _assert_true(not source.contains("draw_set_transform"), "runtime still spins a screen-space rifle"):
		return

	for path in [READY_PATH, MOVE_PATH, FIRE_PATH]:
		if not _assert_true(FileAccess.file_exists(path), "runtime M2 atlas is missing: " + path):
			return
	var player: CharacterBody2D = PlayerScript.new()
	root.add_child(player)
	await process_frame
	if not _assert_true(player.player_ready_atlas.get_size() == Vector2(1280, 384), "READY runtime texture did not load"):
		return
	if not _assert_true(player.player_move_atlas.get_size() == Vector2(1280, 2304), "MOVE runtime texture did not load"):
		return
	if not _assert_true(player.player_fire_atlas.get_size() == Vector2(1280, 2304), "FIRE runtime texture did not load"):
		return

	for frame in range(120):
		var angle := deg_to_rad(float(frame * 3))
		if not _assert_true(player.direction_frame_index(angle) == frame, "three-degree yaw mapping drifted at %d" % frame):
			return
	if not _assert_true(player.direction_frame_index(deg_to_rad(-3.0)) == 119, "negative yaw does not wrap"):
		return
	if not _assert_true(player.direction_frame_rect(0, 0) == Rect2(Vector2.ZERO, FRAME_SIZE), "READY yaw zero rectangle is wrong"):
		return
	if not _assert_true(player.direction_frame_rect(119, 0) == Rect2(Vector2(1216, 320), FRAME_SIZE), "READY final yaw rectangle is wrong"):
		return
	if not _assert_true(player.direction_frame_rect(119, 5) == Rect2(Vector2(1216, 2240), FRAME_SIZE), "action frame five final yaw rectangle is wrong"):
		return

	if not _assert_true(player.resolve_visual_action(false, false, false) == "ready", "stationary state did not resolve READY"):
		return
	if not _assert_true(player.resolve_visual_action(true, false, false) == "move", "movement did not resolve MOVE"):
		return
	if not _assert_true(player.resolve_visual_action(true, true, false) == "fire", "FIRE did not override MOVE"):
		return
	if not _assert_true(player.resolve_visual_action(true, true, true) == "ready", "dash must reuse the approved READY pose"):
		return
	if not _assert_true(player.visual_action_frame("ready", 99.0) == 0, "READY must stay on frame zero"):
		return
	if not _assert_true(player.visual_action_frame("move", 0.11) == 1, "MOVE did not advance at 10 FPS"):
		return
	if not _assert_true(player.visual_action_frame("move", 0.61) == 0, "MOVE did not wrap after six frames"):
		return
	if not _assert_true(player.visual_action_frame("fire", 0.17) == 2, "FIRE did not advance at 12 FPS"):
		return
	if not _assert_true(is_equal_approx(player.visual_playback_rate("move", 235.0, 235.0, 1.0), 1.0), "normal MOVE playback rate drifted"):
		return
	if not _assert_true(is_equal_approx(player.visual_playback_rate("move", 235.0 * 1.3, 235.0, 1.0), 1.3), "overdrive MOVE playback does not follow movement speed"):
		return
	if not _assert_true(is_equal_approx(player.visual_playback_rate("move", 600.0, 235.0, 1.0), 1.5), "MOVE playback rate is not capped"):
		return
	if not _assert_true(is_equal_approx(player.visual_playback_rate("fire", 0.0, 235.0, 2.0), 1.5), "overdrive FIRE playback does not use the readability cap"):
		return
	player.set_overdrive_active(true)
	player.velocity = Vector2(player.get_effective_move_speed(), 0.0)
	player.visual_current_action = "move"
	player.visual_elapsed = 0.0
	player._update_visual_animation(0.1)
	if not _assert_true(is_equal_approx(player.visual_elapsed, 0.13), "overdrive MOVE did not advance at the effective speed ratio"):
		return
	player.visual_current_action = "fire"
	player.visual_fire_timer = 0.2
	player.visual_elapsed = 0.0
	player._update_visual_animation(0.1)
	if not _assert_true(is_equal_approx(player.visual_elapsed, 0.15), "overdrive FIRE did not apply the readability cap in runtime state"):
		return
	if not _assert_true(player.visual_texture_for_action("ready") == player.player_ready_atlas, "READY texture selection drifted"):
		return
	if not _assert_true(player.visual_texture_for_action("move") == player.player_move_atlas, "MOVE texture selection drifted"):
		return
	if not _assert_true(player.visual_texture_for_action("fire") == player.player_fire_atlas, "FIRE texture selection drifted"):
		return

	player.queue_free()
	await process_frame
	print("TEST PASS: PlayerM2RuntimeAnimationTest %d" % assertions)
	quit(0)
