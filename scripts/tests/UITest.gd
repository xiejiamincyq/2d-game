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
	if not _assert_true(ui.get("settlement_screen") != null and ui.get("pause_screen") != null and ui.get("result_screen") != null, "GameUI did not instantiate focused modal screens"):
		return
	if not _assert_true(ui.continue_button != null and not ui.continue_button.visible, "Continue button did not start hidden"):
		return
	ui.set_continue_available(true)
	if not _assert_true(ui.continue_button.visible and not ui.continue_button.disabled, "valid-save state did not expose an enabled Continue button"):
		return
	if not _assert_true(ui.start_panel.get_combined_minimum_size().y <= 500.0, "start screen with Continue no longer fits the 960x540 safe height"):
		return
	ui.set_progression_state({"coins": 37, "family_levels": {"ballistics": 4, "mobility": 2, "automation": 3}})
	if not _assert_true(ui.hud.coin_value_label.text == "金币 37" and ui.hud.level_label.text == "等级  火力:4  机动:2  工程:3", "HUD did not display family progression"):
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
		var settlement_required: Vector2 = ui.settlement_screen.get_required_size()
		var pause_required: Vector2 = ui.pause_screen.get_required_size()
		if not _assert_true(hud_required.x <= size.x and hud_required.y <= size.y, "HUD minimum %s exceeded viewport %s" % [hud_required, size]):
			return
		if not _assert_true(settlement_required.x <= size.x and settlement_required.y <= size.y, "settlement minimum %s exceeded viewport %s" % [settlement_required, size]):
			return
		if not _assert_true(pause_required.x <= size.x and pause_required.y <= size.y, "pause minimum %s exceeded viewport %s" % [pause_required, size]):
			return

	if not _assert_true(ui.settlement_screen.mouse_filter == Control.MOUSE_FILTER_STOP, "settlement overlay does not stop mouse input"):
		return
	if not _assert_true(ui.pause_screen.mouse_filter == Control.MOUSE_FILTER_STOP, "pause overlay does not stop mouse input"):
		return
	if not _assert_true(ui.result_screen.mouse_filter == Control.MOUSE_FILTER_STOP, "result overlay does not stop mouse input"):
		return

	ui.hide_start_screen()
	ui.show_manual_pause()
	await process_frame
	for size in [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1080)]:
		ui.apply_viewport_size(size)
		await process_frame
		var raw_pause_minimum: Vector2 = ui.pause_screen.panel.get_combined_minimum_size() + Vector2(32, 32)
		if not _assert_true(raw_pause_minimum.x <= size.x and raw_pause_minimum.y <= size.y, "visible pause minimum %s exceeded viewport %s" % [raw_pause_minimum, size]):
			return
	if not _assert_true(not ui.pause_screen.has_signal("offer_selected") and not ui.has_signal("shop_offer_selected"), "manual pause still exposed a second shop entry"):
		return
	if not _assert_true(ui.pause_screen.resume_button.has_focus(), "pause modal did not focus resume"):
		return
	ui.hide_manual_pause()
	if not _assert_true(ui.hud.pause_button.has_focus(), "closing pause modal did not return focus to HUD"):
		return

	ui.show_result(
		true,
		"抵达阶段 5/5",
		321,
		299.0,
		{"coins": 18, "family_levels": {"ballistics": 5, "mobility": 3, "automation": 2}}
	)
	if not _assert_true(
		ui.result_screen.result_label.text.contains("等级  火力:5  机动:3  工程:2")
		and not ui.result_screen.result_label.text.contains("最终等级"),
		"result screen did not use the family-level format"
	):
		return
	ui.hide_result()

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
