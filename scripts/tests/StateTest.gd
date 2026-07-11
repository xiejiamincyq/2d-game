extends SceneTree

const MainScript = preload("res://scripts/Main.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: StateTest: " + message)
	paused = false
	quit(1)
	return false

func _initialize() -> void:
	for path in ["res://scripts/systems/UpgradeSystem.gd", "res://scripts/ui/GameUI.gd"]:
		var source := FileAccess.get_file_as_string(path)
		if not _assert_true(source.find("get_tree().paused =") == -1, "%s still assigns SceneTree.paused" % path):
			return

	var scene: Node = MainScript.new()
	root.add_child(scene)
	await process_frame
	if not _assert_true(scene.get("run_state") == 0, "Main did not start in START state"):
		return
	if not _assert_true(scene._transition_to(4) == false, "illegal START to RESULT transition was accepted"):
		return
	scene._start_run()
	if not _assert_true(scene.get("run_state") == 1 and not paused, "start did not enter PLAYING"):
		return
	if not _assert_true(scene._transition_to(2) and paused, "PLAYING to UPGRADE did not pause"):
		return
	if not _assert_true(scene._transition_to(1) and not paused, "UPGRADE to PLAYING did not resume"):
		return
	if not _assert_true(scene._transition_to(3) and paused, "PLAYING to PAUSED did not pause"):
		return
	if not _assert_true(scene._transition_to(1) and not paused, "PAUSED to PLAYING did not resume"):
		return

	scene.queue_free()
	paused = false
	await process_frame
	await process_frame
	print("TEST PASS: StateTest %d" % assertions)
	quit(0)
