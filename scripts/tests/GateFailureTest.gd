extends SceneTree

const MainScript = preload("res://scripts/Main.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: GateFailureTest: " + message)
	paused = false
	quit(1)
	return false

func _initialize() -> void:
	var scene: Node = MainScript.new()
	scene.audio_enabled = false
	root.add_child(scene)
	await process_frame
	scene._start_run()
	scene.wave_director.prepared_wave = false
	scene.ui.wave_banner.finish_message()
	if not _assert_true(
		scene.run_state == scene.RunState.RESULT and paused,
		"begin_prepared_wave failure left the run paused behind a hidden banner"
	):
		return
	if not _assert_true(scene.ui.result_screen.visible, "wave-start failure did not expose a safe result action"):
		return

	paused = false
	scene.free()
	await process_frame
	await process_frame
	print("TEST PASS: GateFailureTest %d" % assertions)
	quit(0)
