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
		if not _assert_true(hud_required.x <= size.x and hud_required.y <= size.y, "HUD minimum %s exceeded viewport %s" % [hud_required, size]):
			return
		if not _assert_true(upgrade_required.x <= size.x and upgrade_required.y <= size.y, "upgrade minimum %s exceeded viewport %s" % [upgrade_required, size]):
			return

	if not _assert_true(ui.upgrade_screen.mouse_filter == Control.MOUSE_FILTER_STOP, "upgrade overlay does not stop mouse input"):
		return
	if not _assert_true(ui.pause_screen.mouse_filter == Control.MOUSE_FILTER_STOP, "pause overlay does not stop mouse input"):
		return
	if not _assert_true(ui.result_screen.mouse_filter == Control.MOUSE_FILTER_STOP, "result overlay does not stop mouse input"):
		return

	var choices: Array[Dictionary] = [
		{"id": "a", "label": "A", "description": "Alpha"},
		{"id": "b", "label": "B", "description": "Beta"},
		{"id": "c", "label": "C", "description": "Gamma"},
	]
	ui.show_upgrades(choices)
	await process_frame
	if not _assert_true(ui.upgrade_screen.buttons[0].has_focus(), "upgrade modal did not focus the first choice"):
		return
	ui.hide_upgrades()
	if not _assert_true(ui.hud.pause_button.has_focus(), "closing upgrade modal did not return focus to HUD"):
		return

	ui.show_manual_pause()
	await process_frame
	if not _assert_true(ui.pause_screen.resume_button.has_focus(), "pause modal did not focus resume"):
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
