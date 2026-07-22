extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: OverdriveTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var scene: Node = MainScript.new()
	root.add_child(scene)
	await process_frame
	scene._start_run()
	scene._transition_to(scene.RunState.PLAYING)
	scene.overdrive_charge = scene.OVERDRIVE_MAX_CHARGE - scene.OVERDRIVE_CHARGE_PER_KILL
	var killed_enemy := Node.new()
	scene._on_enemy_killed(killed_enemy, &"test", 0)
	killed_enemy.free()
	if not _assert_true(scene.overdrive_active and scene.player.is_damage_immune(), "threshold kill did not enter invulnerable overdrive"):
		return
	if not _assert_true(is_equal_approx(scene.player.get_effective_fire_rate(), scene.player.fire_rate * 2.0), "overdrive did not double fire rate"):
		return
	scene._update_combo(4.0)
	if not _assert_true(not scene.overdrive_active and not scene.player.is_damage_immune(), "overdrive did not end and clear immunity"):
		return
	TestSupport.stop_audio(scene.audio)
	await create_timer(0.25).timeout
	scene.queue_free()
	paused = false
	await process_frame
	print("TEST PASS: OverdriveTest %d" % assertions)
	quit(0)
