extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: MovementTest: " + message)
	paused = false
	quit(1)
	return false

func _initialize() -> void:
	for hz in [30, 60, 120]:
		var player: Node = PlayerScript.new()
		root.add_child(player)
		await process_frame
		player.set_physics_process(false)
		player.world_bounds = Rect2(-1000.0, -1000.0, 2000.0, 2000.0)
		var frame_ms := 1000.0 / float(hz)

		player.velocity = Vector2.ZERO
		player._update_movement(Vector2.RIGHT)
		if not _assert_true(
			is_equal_approx(player.velocity.x, player.move_speed) and frame_ms <= 50.0,
			"%d Hz start response exceeded 50ms or missed full speed" % hz
		):
			return

		player._update_movement(Vector2.ZERO)
		if not _assert_true(
			player.velocity == Vector2.ZERO and frame_ms <= 40.0,
			"%d Hz stop response exceeded 40ms or retained velocity" % hz
		):
			return

		player.velocity = Vector2.RIGHT * player.move_speed
		player._update_movement(Vector2.LEFT)
		if not _assert_true(
			is_equal_approx(player.velocity.x, -player.move_speed) and frame_ms <= 70.0,
			"%d Hz reverse response exceeded 70ms or retained forward velocity" % hz
		):
			return

		player._update_movement(Vector2.ONE)
		if not _assert_true(
			is_equal_approx(player.velocity.length(), player.move_speed),
			"%d Hz diagonal input changed top speed to %.3f" % [hz, player.velocity.length()]
		):
			return
		player.queue_free()
		await process_frame

	var scene: Node = MainScript.new()
	root.add_child(scene)
	await process_frame
	scene._start_run()
	scene.ui.wave_banner.finish_message()
	var camera: Camera2D = scene.player.get_node("PlayerCamera")
	if not _assert_true(camera.position_smoothing_enabled, "recommended camera profile disabled smoothing"):
		return
	if not _assert_true(
		is_equal_approx(camera.position_smoothing_speed, MainScript.CAMERA_SMOOTHING_SPEED),
		"runtime camera did not use the selected smoothing speed"
	):
		return
	if not _assert_true(
		MainScript.CAMERA_SMOOTHING_CANDIDATES == [0.0, 8.0, 16.0, 20.0]
		and is_equal_approx(MainScript.CAMERA_SMOOTHING_SPEED, 8.0),
		"camera profiles lost the stable 8.0 baseline or selected a jitter-prone profile"
	):
		return

	TestSupport.stop_audio(scene.audio)
	await create_timer(0.25).timeout
	scene.queue_free()
	paused = false
	await process_frame
	await process_frame
	print("TEST PASS: MovementTest %d" % assertions)
	quit(0)
