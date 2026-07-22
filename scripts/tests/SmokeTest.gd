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
	if not _assert_true(
		scene.run_state == scene.RunState.WAVE_INTRO and paused and scene.ui.wave_banner.visible,
		"start did not enter the first wave introduction gate"
	):
		return
	if not _assert_true(scene.ui.wave_banner.message_label.text == "侦测到第 1 波敌人", "first wave banner copy was incorrect"):
		return
	scene.ui.wave_banner.finish_message()
	if not _assert_true(scene.run_state == scene.RunState.PLAYING and not paused, "wave introduction did not enter PLAYING"):
		return
	scene.wave_director.active = false
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
	for portal in scene.wave_director.active_portals.duplicate():
		scene.wave_director._on_portal_closed(portal)
	scene.wave_director.prepared_wave = false
	scene.wave_director.wave_running = true
	scene.wave_director.waiting_for_advance = false
	scene.wave_director._process(0.016)
	if not _assert_true(
		scene.run_state == scene.RunState.WAVE_CLEAR and paused and scene.wave_director.waiting_for_advance,
		"cleared wave did not enter the clear banner gate"
	):
		return
	if not _assert_true(scene.ui.wave_banner.message_label.text == "第 1 波清剿完成", "wave clear banner copy was incorrect"):
		return
	scene.ui.wave_banner.finish_message()
	if not _assert_true(scene.run_state == scene.RunState.SETTLEMENT and paused and scene.ui.settlement_screen.visible, "clear banner did not open unified settlement"):
		return
	var settlement: Dictionary = scene.upgrade_system.get_settlement_state()
	var settlement_offers: Array[Dictionary] = []
	for family in settlement["families"]:
		for offer in family["offers"]:
			settlement_offers.append(offer)
	if not _assert_true(settlement_offers.size() == 6 and not settlement["can_close"], "settlement did not contain two cards per family behind the reward gate"):
		return
	var free_offer: Dictionary = settlement_offers[0]
	var free_family := String(free_offer["family"])
	var free_family_level := int(scene.upgrade_system.family_levels[free_family])
	scene._on_settlement_offer_selected(free_offer)
	settlement = scene.upgrade_system.get_settlement_state()
	if not _assert_true(settlement["reward_claimed"] and settlement["can_close"] and int(scene.upgrade_system.family_levels[free_family]) == free_family_level + 1, "free reward did not unlock close and increase its family level"):
		return
	var paid_offer: Dictionary = {}
	for family in settlement["families"]:
		for offer in family["offers"]:
			if not bool(offer["sold"]):
				paid_offer = offer
				break
		if not paid_offer.is_empty():
			break
	var paid_family := String(paid_offer["family"])
	var paid_family_level := int(scene.upgrade_system.family_levels[paid_family])
	scene.upgrade_system.add_coins(int(paid_offer["cost"]))
	scene._on_settlement_offer_selected(paid_offer)
	if not _assert_true(scene.upgrade_system.coins == 0 and int(scene.upgrade_system.family_levels[paid_family]) == paid_family_level, "paid card changed coins or family level incorrectly"):
		return
	scene.wave_director.waiting_for_advance = false
	scene._on_settlement_close_requested()
	if not _assert_true(
		scene.run_state == scene.RunState.SETTLEMENT
		and scene.ui.settlement_screen.visible
		and not bool(scene.upgrade_system.get_settlement_state()["closed"]),
		"failed wave preflight consumed or hid the settlement"
	):
		return
	scene.wave_director.waiting_for_advance = true
	scene._on_settlement_close_requested()
	if not _assert_true(scene.run_state == scene.RunState.WAVE_INTRO and paused and scene.wave_director.wave_index == 1, "closing settlement did not prepare the next wave introduction"):
		return
	scene.ui.wave_banner.finish_message()
	if not _assert_true(scene.run_state == scene.RunState.PLAYING and not paused, "second wave introduction did not resume combat"):
		return
	scene.wave_director.active = false

	scene._toggle_manual_pause()
	if not _assert_true(scene.run_state == scene.RunState.PAUSED and paused and scene.ui.pause_panel.visible, "manual pause did not own tree and UI state"):
		return
	if not _assert_true(not scene.ui.pause_screen.has_signal("offer_selected") and not scene.ui.has_signal("shop_offer_selected"), "manual pause still exposed a second card shop"):
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
