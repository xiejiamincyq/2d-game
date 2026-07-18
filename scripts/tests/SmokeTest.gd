extends SceneTree

const MainScene = preload("res://scenes/Main.tscn")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: SmokeTest: " + message)
	paused = false
	quit(1)
	return false

func _initialize() -> void:
	var scene: Node = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	if not _assert_true(scene.run_state == scene.RunState.START, "scene did not boot into START"):
		return
	if not _assert_true(scene.world.process_mode == Node.PROCESS_MODE_PAUSABLE, "world is not pausable"):
		return

	scene._start_run()
	await process_frame
	scene.wave_director.active = false
	if not _assert_true(scene.run_state == scene.RunState.PLAYING and not paused, "start did not enter PLAYING"):
		return
	if not _assert_true(scene.player.process_mode == Node.PROCESS_MODE_PAUSABLE, "player is not pausable"):
		return
	if not _assert_true(scene.audio.bgm_player != null and scene.audio.bgm_player.playing, "BGM did not start"):
		return
	if not _assert_true(scene.upgrade_system.coins == 0 and scene.ui.hud.coin_value_label.text == "金币 0", "run did not start with a visible zero coin balance"):
		return

	scene.wave_director.active = true
	scene.wave_director.wave_index = 0
	scene.wave_director.spawn_queue.clear()
	scene.wave_director.active_enemies.clear()
	scene.wave_director.intermission = 0.0
	scene.wave_director._process(0.016)
	if not _assert_true(scene.run_state == scene.RunState.UPGRADE and paused and scene.wave_director.waiting_for_advance, "cleared wave did not enter the gated upgrade state"):
		return
	scene._on_wave_cleared(1)
	if not _assert_true(scene.wave_director.waiting_for_advance and scene.wave_director.wave_index == 0, "duplicate wave reward bypassed the upgrade gate"):
		return
	var wave_choice: Dictionary = scene.upgrade_system.pending_choices[0].duplicate(true)
	scene._on_upgrade_selected(wave_choice)
	if not _assert_true(scene.run_state == scene.RunState.PLAYING and not paused and scene.wave_director.wave_index == 1, "wave upgrade did not resume into the next wave"):
		return

	scene._toggle_manual_pause()
	if not _assert_true(scene.run_state == scene.RunState.PAUSED and paused and scene.ui.pause_panel.visible, "manual pause did not own tree and UI state"):
		return
	scene._toggle_manual_pause()
	if not _assert_true(scene.run_state == scene.RunState.PLAYING and not paused, "manual resume did not restore PLAYING"):
		return

	scene._end_run(false)
	if not _assert_true(scene.run_state == scene.RunState.RESULT and paused, "defeat did not enter RESULT"):
		return
	if not _assert_true(not scene.player.is_physics_processing() and scene.ui.result_panel.visible, "result did not stop player and show UI"):
		return

	TestSupport.stop_audio(scene.audio)
	await create_timer(0.25).timeout
	scene.queue_free()
	paused = false
	await process_frame
	await process_frame
	print("TEST PASS: SmokeTest %d" % assertions)
	quit(0)
