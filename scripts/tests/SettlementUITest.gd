extends SceneTree

const GameUIScript = preload("res://scripts/ui/GameUI.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: SettlementUITest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var ui: Node = GameUIScript.new()
	root.add_child(ui)
	await process_frame
	if not _assert_true(ui.get("settlement_screen") != null, "GameUI did not instantiate the unified settlement screen"):
		return
	if not _assert_true(ui.get("wave_banner") != null, "GameUI did not instantiate the wave banner"):
		return
	ui.set_progression_state({"coins": 91, "family_levels": {"ballistics": 2, "mobility": 1, "automation": 3}})
	if not _assert_true(ui.hud.level_label.text == "等级  火力:2  机动:1  工程:3" and ui.hud.coin_value_label.text == "金币 91", "HUD did not display the three family levels"):
		return

	var offers: Array[Dictionary] = []
	var families: Array[Dictionary] = []
	var index := 0
	for family in [
		{"id": "ballistics", "label": "火力"},
		{"id": "mobility", "label": "机动"},
		{"id": "automation", "label": "工程"},
	]:
		var family_offers: Array[Dictionary] = []
		for slot in range(2):
			var offer := {
				"id": "%s_%d" % [family["id"], slot],
				"label": "%s模块%d" % [family["label"], slot + 1],
				"description": "可读的中文联动说明",
				"family": family["id"],
				"family_label": family["label"],
				"cost": 20 + index * 3,
				"sold": false,
				"capped": false,
				"affordable": index != 5,
				"_settlement_transaction": 7,
			}
			family_offers.append(offer)
			offers.append(offer)
			index += 1
		families.append({"id": family["id"], "label": family["label"], "offers": family_offers})

	var state := {
		"wave": 2,
		"coins": 91,
		"transaction": 7,
		"reward_claimed": false,
		"can_close": false,
		"family_levels": {"ballistics": 2, "mobility": 1, "automation": 3},
		"families": families,
		"offers": offers,
	}
	var selected: Array[Dictionary] = []
	var close_count := [0]
	ui.settlement_offer_selected.connect(func(offer: Dictionary) -> void: selected.append(offer.duplicate(true)))
	ui.settlement_close_requested.connect(func() -> void: close_count[0] += 1)
	ui.set_settlement_state(state)
	ui.hide_start_screen()
	ui.show_settlement()
	await process_frame

	if not _assert_true(ui.settlement_screen.offer_buttons.size() == 6, "settlement did not expose six offer buttons"):
		return
	if not _assert_true(ui.settlement_screen.close_button.disabled, "settlement could close before the free reward"):
		return
	for size in [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1080)]:
		ui.apply_viewport_size(size)
		await process_frame
		var minimum: Vector2 = ui.settlement_screen.get_required_size()
		if not _assert_true(minimum.x <= size.x and minimum.y <= size.y, "settlement minimum %s exceeded viewport %s" % [minimum, size]):
			return
		for button in ui.settlement_screen.offer_buttons:
			if not _assert_true(button.visible and not button.text.is_empty() and button.size.x >= 200.0, "settlement card lost text or width at %s" % [size]):
				return
	if not _assert_true(ui.settlement_screen.offer_buttons[0].text.contains("免费领取") and ui.settlement_screen.offer_buttons[0].has_focus(), "free reward state was not visible or focused"):
		return

	var key_six := InputEventKey.new()
	key_six.pressed = true
	key_six.keycode = KEY_6
	ui._unhandled_input(key_six)
	if not _assert_true(selected.size() == 1 and selected[0]["id"] == "automation_1", "number key 6 did not select the sixth settlement card"):
		return

	state["reward_claimed"] = true
	state["can_close"] = true
	state["families"][2]["offers"][1]["affordable"] = false
	state["offers"][5]["affordable"] = false
	ui.set_settlement_state(state)
	await process_frame
	if not _assert_true(not ui.settlement_screen.close_button.disabled and ui.settlement_screen.offer_buttons[0].text.contains("20 金币"), "paid settlement state did not expose prices and close"):
		return
	ui.settlement_screen.close_button.pressed.emit()
	if not _assert_true(close_count[0] == 1, "settlement close button did not emit"):
		return

	var finished_contexts: Array[StringName] = []
	ui.wave_banner_finished.connect(func(context: StringName) -> void: finished_contexts.append(context))
	ui.show_wave_banner("侦测到第 3 波敌人", &"wave_intro", 5.0)
	if not _assert_true(ui.wave_banner.visible and ui.wave_banner.message_label.text == "侦测到第 3 波敌人", "wave intro banner did not display its exact message"):
		return
	ui.wave_banner.finish_message()
	if not _assert_true(not ui.wave_banner.visible and finished_contexts == [&"wave_intro"], "wave banner did not finish exactly once"):
		return

	ui.queue_free()
	await process_frame
	print("TEST PASS: SettlementUITest %d" % assertions)
	quit(0)
