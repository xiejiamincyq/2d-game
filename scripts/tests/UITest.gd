extends SceneTree

const GameUIScript = preload("res://scripts/ui/GameUI.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: UITest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var ui: Node = GameUIScript.new()
	root.add_child(ui)
	await process_frame
	if not _assert_true(ui.get("hud") != null, "GameUI did not instantiate a HUD component"):
		return
	if not _assert_true(ui.get("upgrade_screen") != null and ui.get("pause_screen") != null and ui.get("result_screen") != null, "GameUI did not instantiate focused modal screens"):
		return
	ui.set_progression(37, 3)
	if not _assert_true(ui.hud.coin_value_label.text == "金币 37" and ui.hud.level_label.text == "流派等级 3", "HUD did not display coin progression"):
		return
	if not _assert_true(ui.hud.get("xp_bar") == null and ui.hud.get("xp_value_label") == null, "HUD retained the removed XP progress controls"):
		return
	var ui_font := ui.root.theme.default_font as SystemFont
	if not _assert_true(ui_font != null, "shared UI theme does not provide the CJK system font"):
		return
	if not _assert_true(ui_font.font_names.has("Microsoft YaHei UI") and ui_font.font_names.has("Noto Sans CJK SC"), "shared UI theme lost its Chinese font fallback chain"):
		return

	for size in [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1080)]:
		ui.apply_viewport_size(size)
		await process_frame
		var hud_required: Vector2 = ui.hud.get_required_size()
		var upgrade_required: Vector2 = ui.upgrade_screen.get_required_size()
		var pause_required: Vector2 = ui.pause_screen.get_required_size()
		if not _assert_true(hud_required.x <= size.x and hud_required.y <= size.y, "HUD minimum %s exceeded viewport %s" % [hud_required, size]):
			return
		if not _assert_true(upgrade_required.x <= size.x and upgrade_required.y <= size.y, "upgrade minimum %s exceeded viewport %s" % [upgrade_required, size]):
			return
		if not _assert_true(pause_required.x <= size.x and pause_required.y <= size.y, "pause shop minimum %s exceeded viewport %s" % [pause_required, size]):
			return

	if not _assert_true(ui.upgrade_screen.mouse_filter == Control.MOUSE_FILTER_STOP, "upgrade overlay does not stop mouse input"):
		return
	if not _assert_true(ui.pause_screen.mouse_filter == Control.MOUSE_FILTER_STOP, "pause overlay does not stop mouse input"):
		return
	if not _assert_true(ui.result_screen.mouse_filter == Control.MOUSE_FILTER_STOP, "result overlay does not stop mouse input"):
		return

	var choices: Array[Dictionary] = [
		{"id": "damage", "label": "超频弹芯", "description": "主武器伤害 +25%"},
		{"id": "fire_rate", "label": "灼热枪管", "description": "射速 +50%"},
		{"id": "gun_lines", "label": "分裂枪线", "description": "主武器枪线 +1"},
	]
	ui.show_upgrades(choices)
	await process_frame
	for size in [Vector2(960, 540), Vector2(1280, 720), Vector2(2560, 1080)]:
		ui.apply_viewport_size(size)
		await process_frame
		for index in range(choices.size()):
			var choice_button: Button = ui.upgrade_screen.buttons[index]
			var rendered_font: Font = choice_button.get_theme_font("font")
			if not _assert_true(choice_button.visible and not choice_button.text.is_empty(), "upgrade choice %d lost its visible text" % index):
				return
			if not _assert_true(choice_button.size.x >= 200.0, "upgrade choice %d collapsed to %.1f pixels wide at %s" % [index, choice_button.size.x, size]):
				return
			if not _assert_true(rendered_font != null and rendered_font.has_char("超".unicode_at(0)), "upgrade choice font cannot render Chinese glyphs"):
				return
			if not _assert_true(choice_button.get_theme_color("font_color").a > 0.0 and choice_button.modulate.a > 0.0 and choice_button.self_modulate.a > 0.0, "upgrade choice text became transparent"):
				return
	if not _assert_true(ui.upgrade_screen.buttons[0].has_focus(), "upgrade modal did not focus the first choice"):
		return
	ui.hide_upgrades()
	if not _assert_true(ui.hud.pause_button.has_focus(), "closing upgrade modal did not return focus to HUD"):
		return

	var selected_shop_offers: Array[Dictionary] = []
	ui.shop_offer_selected.connect(func(offer: Dictionary) -> void: selected_shop_offers.append(offer.duplicate(true)))
	ui.set_shop_state({
		"wave": 2,
		"coins": 37,
		"offers": [
			{"id": "damage", "label": "超频弹芯", "description": "主武器伤害 +25%", "family": "projectile", "kind": "support", "cost": 12, "sold": false, "capped": false, "affordable": true, "_shop_transaction": 8},
			{"id": "drone", "label": "废铁无人机", "description": "增加无人机", "family": "drone_arc", "kind": "core", "cost": 24, "sold": true, "capped": false, "affordable": true, "_shop_transaction": 8},
			{"id": "mine", "label": "静滞地刺", "description": "部署地刺", "family": "dash_spike", "kind": "core", "cost": 48, "sold": false, "capped": false, "affordable": false, "_shop_transaction": 8},
		],
	})
	ui.hide_start_screen()
	ui.show_manual_pause()
	await process_frame
	for size in [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1080)]:
		ui.apply_viewport_size(size)
		await process_frame
		var raw_pause_minimum: Vector2 = ui.pause_screen.panel.get_combined_minimum_size() + Vector2(32, 32)
		if not _assert_true(raw_pause_minimum.x <= size.x and raw_pause_minimum.y <= size.y, "visible pause shop minimum %s exceeded viewport %s" % [raw_pause_minimum, size]):
			return
		for index in range(ui.pause_screen.offer_buttons.size()):
			var offer_button: Button = ui.pause_screen.offer_buttons[index]
			if not _assert_true(offer_button.visible and not offer_button.text.is_empty(), "pause shop offer %d lost its visible text at %s" % [index, size]):
				return
			if not _assert_true(offer_button.size.x >= 200.0, "pause shop offer %d collapsed to %.1f pixels wide at %s" % [index, offer_button.size.x, size]):
				return
	if not _assert_true(ui.pause_screen.coin_label.text == "金币 37" and ui.pause_screen.wave_label.text == "第 2 波报价", "pause shop did not display wave and coins"):
		return
	if not _assert_true(ui.pause_screen.offer_buttons[0].has_focus(), "pause shop did not focus the first purchasable offer"):
		return
	if not _assert_true(not ui.pause_screen.offer_buttons[0].disabled and ui.pause_screen.offer_buttons[1].disabled and ui.pause_screen.offer_buttons[2].disabled, "pause shop offer availability states were wrong"):
		return
	if not _assert_true(ui.pause_screen.offer_buttons[0].text.contains("超频弹芯") and ui.pause_screen.offer_buttons[0].text.contains("12 金币"), "pause shop lost visible Chinese offer text"):
		return
	ui.pause_screen.offer_buttons[0].pressed.emit()
	if not _assert_true(selected_shop_offers.size() == 1 and selected_shop_offers[0]["id"] == "damage", "pause shop button did not emit its offer"):
		return
	var key_one := InputEventKey.new()
	key_one.pressed = true
	key_one.keycode = KEY_1
	ui._unhandled_input(key_one)
	if not _assert_true(selected_shop_offers.size() == 2, "number key did not activate the focused shop offer"):
		return
	var sold_shop_state: Dictionary = ui.pause_screen.current_state.duplicate(true)
	sold_shop_state["offers"][0]["sold"] = true
	sold_shop_state["offers"][0]["affordable"] = false
	ui.set_shop_state(sold_shop_state)
	await process_frame
	if not _assert_true(ui.pause_screen.resume_button.has_focus(), "shop did not move focus after the active offer became unavailable"):
		return
	ui.hide_manual_pause()
	if not _assert_true(ui.hud.pause_button.has_focus(), "closing pause modal did not return focus to HUD"):
		return

	ui.show_toast("first")
	var first_tween: Tween = ui.hud.toast_tween
	ui.show_toast("second")
	if not _assert_true(ui.hud.toast_tween != first_tween and not first_tween.is_valid(), "new toast did not kill and replace the previous tween"):
		return
	ui.hud._finish_toast()
	if not _assert_true(not ui.hud.toast_overlay.visible, "finished toast still participates in layout"):
		return

	ui.queue_free()
	await process_frame
	print("TEST PASS: UITest %d" % assertions)
	quit(0)
