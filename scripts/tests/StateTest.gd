extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

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
	var permanent_fire_rate: float = scene.player.fire_rate * 1.5
	var permanent_weapon_damage: float = scene.player.weapon_damage * 1.25
	scene.player.fire_rate = permanent_fire_rate
	scene.player.weapon_damage = permanent_weapon_damage
	scene.player.set_overdrive_active(true)
	scene.player.set_dash_immunity_active(true)
	if not _assert_true(scene._transition_to(2) and paused, "PLAYING to UPGRADE did not pause"):
		return
	if not _assert_true(
		is_equal_approx(scene.player.get_effective_fire_rate(), permanent_fire_rate),
		"upgrade pause did not clear temporary fire-rate modifiers"
	):
		return
	if not _assert_true(
		is_equal_approx(scene.player.weapon_damage, permanent_weapon_damage),
		"temporary-state cleanup changed permanent weapon damage"
	):
		return
	if not _assert_true(not scene.player.is_damage_immune(), "upgrade pause left temporary immunity active"):
		return
	if not _assert_true(scene._transition_to(1) and not paused, "UPGRADE to PLAYING did not resume"):
		return
	scene.player.set_overdrive_active(true)
	scene.player.set_dash_immunity_active(true)
	if not _assert_true(scene._transition_to(3) and paused, "PLAYING to PAUSED did not pause"):
		return
	if not _assert_true(not scene.player.is_damage_immune(), "manual pause left temporary immunity active"):
		return
	if not _assert_true(scene._transition_to(1) and not paused, "PAUSED to PLAYING did not resume"):
		return
	scene.player.set_overdrive_active(true)
	if not _assert_true(scene._transition_to(4) and paused, "PLAYING to RESULT did not pause"):
		return
	if not _assert_true(
		is_equal_approx(scene.player.get_effective_fire_rate(), permanent_fire_rate)
		and not scene.player.is_damage_immune(),
		"result transition did not restore runtime modifiers"
	):
		return

	TestSupport.stop_audio(scene.audio)
	await create_timer(0.25).timeout
	scene.queue_free()
	paused = false
	await process_frame
	await process_frame
	print("TEST PASS: StateTest %d" % assertions)
	quit(0)
