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
	var aim_reticle := ui.get("aim_reticle") as Control
	if not _assert_true(
		aim_reticle != null
		and aim_reticle.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and aim_reticle.size.x >= 48.0
		and aim_reticle.size.y >= 48.0,
		"GameUI did not provide a conspicuous mouse-transparent aim reticle"
	):
		return
	aim_reticle.call("set_screen_position", Vector2(320.0, 180.0))
	if not _assert_true(aim_reticle.get_rect().get_center().distance_to(Vector2(320.0, 180.0)) <= 0.01, "aim reticle was not centered on the mouse position"):
		return
	ui.set_aim_reticle_visible(true)
	if not _assert_true(aim_reticle.visible, "aim reticle did not become visible for gameplay"):
		return
	ui.set_aim_reticle_visible(false)
	if not _assert_true(not aim_reticle.visible, "aim reticle remained visible over a modal screen"):
		return
	if not _assert_true(ui.get("settlement_screen") != null and ui.get("pause_screen") != null and ui.get("result_screen") != null, "GameUI did not instantiate focused modal screens"):
		return
	var pause_restart_button := ui.pause_screen.get("restart_button") as Button
	if not _assert_true(
		pause_restart_button != null
		and pause_restart_button.get_combined_minimum_size().y >= 44.0
		and pause_restart_button.focus_mode == Control.FOCUS_ALL,
		"pause menu did not expose a keyboard-focusable restart option"
	):
		return
	if not _assert_true(
		String(ui.pause_screen.resume_button.focus_neighbor_bottom) != ""
		and String(pause_restart_button.focus_neighbor_top) != "",
		"pause menu did not link resume and restart in its focus chain"
	):
		return
	var pause_restart_requests := [0]
	ui.restart_requested.connect(func() -> void: pause_restart_requests[0] += 1)
	pause_restart_button.pressed.emit()
	if not _assert_true(pause_restart_requests[0] == 1, "pause restart button did not reuse GameUI's restart request"):
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
	ui.set_collection_window(5.0, 5.0)
	if not _assert_true(ui.hud.collection_panel.visible and ui.hud.collection_label.text == "倒计时：5.0s" and is_equal_approx(ui.hud.collection_bar.value, 5.0), "HUD did not show only the requested five-second countdown text"):
		return
	ui.set_collection_window(2.4, 5.0)
	if not _assert_true(ui.hud.collection_label.text == "倒计时：2.4s" and is_equal_approx(ui.hud.collection_bar.value, 2.4), "collection countdown text did not update smoothly"):
		return
	ui.set_collection_window(0.0, 5.0)
	if not _assert_true(not ui.hud.collection_panel.visible, "collection countdown remained visible after the upgrade transition"):
		return
	var ui_font := ui.root.theme.default_font as SystemFont
	if not _assert_true(ui_font != null, "shared UI theme does not provide the CJK system font"):
		return
	if not _assert_true(ui_font.font_names.has("Microsoft YaHei UI") and ui_font.font_names.has("Noto Sans CJK SC"), "shared UI theme lost its Chinese font fallback chain"):
		return
	if not _assert_true(ui.root.theme.default_font_size >= 16, "shared UI theme body text fell below 16px"):
		return
	var dark_backdrop := Color(0.015, 0.025, 0.04)
	var label_color: Color = ui.root.theme.get_color("font_color", "Label")
	var button_color: Color = ui.root.theme.get_color("font_color", "Button")
	var button_background := dark_backdrop
	var button_style: StyleBox = ui.start_button.get_theme_stylebox("normal")
	if button_style is StyleBoxFlat:
		button_background = button_style.bg_color
	if not _assert_true(_contrast_ratio(label_color, dark_backdrop) >= 4.5, "default label contrast fell below 4.5:1"):
		return
	if not _assert_true(_contrast_ratio(button_color, button_background) >= 4.5, "default button contrast fell below 4.5:1"):
		return
	for button in [ui.start_button, ui.continue_button, ui.hud.pause_button, ui.pause_screen.resume_button, pause_restart_button, ui.result_screen.restart_button, ui.settlement_screen.close_button]:
		if not _assert_true(button.get_combined_minimum_size().y >= 44.0 and button.focus_mode == Control.FOCUS_ALL, "%s lost its 44px keyboard-focusable target" % button.name):
			return

	for size in [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1080)]:
		ui.apply_viewport_size(size)
		await process_frame
		ui.show_boss_intro("深渊监工 / OVERSEER", 1.4)
		if not _assert_true(ui.boss_entrance_overlay.visible and ui.boss_entrance_overlay.get_intro_center().distance_to(size * 0.5) <= 0.01, "Boss entrance overlay was not centered at %s" % size):
			return
		ui.hide_boss_intro()
		var hud_required: Vector2 = ui.hud.get_required_size()
		var settlement_required: Vector2 = ui.settlement_screen.get_required_size()
		var pause_required: Vector2 = ui.pause_screen.get_required_size()
		if not _assert_true(ui.result_screen.has_method("get_required_size"), "result screen does not expose the shared viewport-size contract"):
			return
		var result_required: Vector2 = ui.result_screen.get_required_size()
		if not _assert_true(hud_required.x <= size.x and hud_required.y <= size.y, "HUD minimum %s exceeded viewport %s" % [hud_required, size]):
			return
		if not _assert_true(settlement_required.x <= size.x and settlement_required.y <= size.y, "settlement minimum %s exceeded viewport %s" % [settlement_required, size]):
			return
		if not _assert_true(pause_required.x <= size.x and pause_required.y <= size.y, "pause minimum %s exceeded viewport %s" % [pause_required, size]):
			return
		if not _assert_true(result_required.x <= size.x and result_required.y <= size.y, "result minimum %s exceeded viewport %s" % [result_required, size]):
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

func _contrast_ratio(first: Color, second: Color) -> float:
	var lighter := maxf(_relative_luminance(first), _relative_luminance(second))
	var darker := minf(_relative_luminance(first), _relative_luminance(second))
	return (lighter + 0.05) / (darker + 0.05)

func _relative_luminance(color: Color) -> float:
	return (
		0.2126 * _linear_channel(color.r)
		+ 0.7152 * _linear_channel(color.g)
		+ 0.0722 * _linear_channel(color.b)
	)

func _linear_channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)
