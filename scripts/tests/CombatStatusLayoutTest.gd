extends SceneTree

const UIScript = preload("res://scripts/ui/GameUI.gd")
const SIZES := [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(2560, 1080)]

var assertions := 0
var failed := false
var view: SubViewport
var ui: GameUI

func _initialize() -> void:
	await process_frame
	await _run()
	if is_instance_valid(view):
		view.free()
	await process_frame
	await process_frame
	if failed:
		quit(1)
		return
	print("TEST PASS: CombatStatusLayoutTest %d" % assertions)
	quit(0)

func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	failed = true
	push_error("TEST FAIL: CombatStatusLayoutTest: " + message)
	return false

func _run() -> void:
	view = SubViewport.new()
	view.size = SIZES[0]
	root.add_child(view)
	ui = UIScript.new()
	view.add_child(ui)
	ui.hide_start_screen()
	ui.show_boss_health(null, "深渊监工 / OVERSEER", 10800)
	ui.set_combo(27)
	await _settle_layout()
	# Actual old GameUI first: RED must be the visible overlap, not a missing API.
	var boss_rect := _rect(ui.boss_health_bar)
	var combo_rect := _rect(ui.combo_panel)
	print("STATUS REGRESSION Boss=%s combo=%s" % [boss_rect, combo_rect])
	if not _check(ui.boss_health_bar.is_visible_in_tree() and ui.combo_panel.is_visible_in_tree() and not boss_rect.intersects(combo_rect), "Boss health bar obscures the actual visible combo card"):
		return
	ui.hide_boss_health()
	ui.clear_combo()
	ui.set_collection_window(3.0, 3.0)
	await _settle_layout()
	var collection_rect := _rect(ui.hud.collection_panel)
	var charge_rect := _rect(ui.hud.overdrive_panel)
	print("COLLECTION REGRESSION countdown=%s charge=%s" % [collection_rect, charge_rect])
	if not _check(ui.hud.collection_panel.is_visible_in_tree() and not collection_rect.intersects(charge_rect), "collection countdown obscures the bottom overdrive charge bar"):
		return
	ui.set_collection_window(0.0, 3.0)
	# Also cover the existing two-column HUD without claiming a fifth native size.
	for dimensions in SIZES + [Vector2i(800, 600)]:
		view.size = dimensions
		ui.apply_viewport_size(Vector2(dimensions))
		for mode in ["boss_combo", "boss_overdrive", "boss_toast", "boss_all", "ordinary_combo", "ordinary_overdrive", "ordinary_toast", "boss_only", "clear", "collection", "collection_overdrive", "boss_combo_toast_collection"]:
			ui.hide_boss_health()
			ui.clear_combo()
			ui.hud._finish_toast()
			ui.set_collection_window(0.0, 3.0)
			ui.set_overdrive_charge(60.0, false)
			if mode.begins_with("boss"):
				ui.show_boss_health(null, "深渊监工 / OVERSEER", 10800)
				ui.set_boss_health(5800, 10800, 2)
			if "combo" in mode or mode == "boss_all":
				ui.set_combo(9999)
			if "overdrive" in mode:
				ui.set_overdrive(true, 3.2)
			if "toast" in mode or mode == "boss_all":
				ui.show_toast("激光协同强化")
				ui.hud.toast_tween.kill() # Explicit component state, not natural timing.
			if "collection" in mode:
				ui.set_collection_window(0.2, 3.0) # Covers the actual fade tail too.
				if "overdrive" in mode:
					ui.set_overdrive_charge(100.0, true)
			await _settle_layout()
			if not _verify_visible_controls("%s/%s" % [dimensions, mode]):
				return
			var settled_rects := ui.get_combat_occluder_rects()
			await _settle_layout()
			if not _check(ui.get_combat_occluder_rects() == settled_rects, "settled status layout kept moving without a state change"):
				return
			if "combo" in mode or mode == "boss_all":
				if not _check(ui.combo_panel.is_visible_in_tree() and ui.combo_label.text == "连杀 x9999", "layout hid or changed a real combo"):
					return
			if "overdrive" in mode:
				if not _check(ui.combo_label.text.contains("超载 3.2s") and ui.combo_label.text.contains("无敌 · 全武器强化"), "layout lost the complete overdrive message"):
					return
			if "collection" in mode:
				if not _check(ui.hud.collection_panel.is_visible_in_tree() and ui.hud.collection_label.text == "倒计时：0.2s" and is_equal_approx(ui.hud.collection_bar.value, 0.2) and is_equal_approx(ui.hud.collection_bar.max_value, 3.0) and is_equal_approx(ui.hud.collection_panel.modulate.a, 0.2 / 0.35), "layout changed the collection countdown/value/fade contract"):
					return
		ui.show_boss_health(null, "深渊监工 / OVERSEER", 10800)
		ui.set_overdrive(true, 3.2)
		await _settle_layout()
		ui.show_start_screen()
		if not _check(not ui.combo_panel.is_visible_in_tree() and not ui.boss_health_bar.is_visible_in_tree() and not ui.hud.collection_panel.is_visible_in_tree(), "HUD visibility did not hide combat and collection panels synchronously"):
			return
		await _settle_layout()
		if not _check(not ui.combo_panel.is_visible_in_tree() and not ui.toast_panel.is_visible_in_tree(), "detached HUD messages leaked onto the title"):
			return
		ui.hide_start_screen()
		if not _check(ui.combo_panel.is_visible_in_tree() and ui.boss_health_bar.is_visible_in_tree() and ui.hud.collection_panel.is_visible_in_tree(), "HUD visibility did not restore combat and collection panels synchronously"):
			return
		await _settle_layout()
		if not _check(ui.combo_panel.is_visible_in_tree() and ui.boss_health_bar.is_visible_in_tree(), "HUD visibility restoration lost combat messages"):
			return

func _settle_layout() -> void:
	for _frame in range(4):
		await process_frame

func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _verify_visible_controls(context: String) -> bool:
	var controls := ui.get_combat_occluders()
	var screen := Rect2(Vector2.ZERO, Vector2(view.size))
	var charge_rect := _rect(ui.hud.overdrive_panel)
	if not _check(absf(charge_rect.end.y - (view.size.y - 18.0)) < 0.1 and absf(charge_rect.get_center().x - view.size.x * 0.5) < 0.1, "bottom charge bar lost its centered original 18px inset"):
		return false
	if ui.hud.collection_panel.is_visible_in_tree():
		var collection_rect := _rect(ui.hud.collection_panel)
		if not _check(absf(collection_rect.get_center().x - view.size.x * 0.5) < 0.1 and charge_rect.position.y - collection_rect.end.y >= 7.9, "collection countdown is not centered above the charge bar with the 8px gap"):
			return false
	if ui.boss_health_bar.is_visible_in_tree():
		var boss_rect := _rect(ui.boss_health_bar)
		var saved_position: Vector2 = ui.boss_health_bar.position
		var saved_size: Vector2 = ui.boss_health_bar.size
		ui.boss_health_bar.get_preferred_width(Vector2(1920, 1080))
		if not _check(ui.boss_health_bar.position == saved_position and ui.boss_health_bar.size == saved_size, "preferred width query changed container-owned geometry"):
			return false
		var row_height := maxf(boss_rect.size.y, ui.combo_panel.size.y if ui.combo_panel.is_visible_in_tree() else 0.0)
		var expected_top := _rect(ui.hud.grid).end.y + 2.0 + (row_height - boss_rect.size.y) * 0.5
		if not _check(absf(boss_rect.position.y - expected_top) <= 1.0, "%s Boss bar drifted from the compact shared status row: actual=%s expected_y=%s" % [context, boss_rect, expected_top]):
			return false
		for index in ui.boss_health_bar.threshold_markers.size():
			var marker: Control = ui.boss_health_bar.threshold_markers[index]
			var expected_x: float = 3.0 + (boss_rect.size.x - 6.0) * ui.boss_health_bar.thresholds[index] - 1.5
			if not _check(absf(marker.position.x - expected_x) < 0.1 and marker.size == Vector2(3, 15), "resized Boss phase marker lost its actual health ratio"):
				return false
	for index in range(controls.size()):
		var rect := _rect(controls[index])
		if not _check(screen.encloses(rect), "%s panel %s clipped by viewport: %s" % [context, controls[index].name, rect]):
			return false
		for other in range(index + 1, controls.size()):
			if not _check(not rect.intersects(_rect(controls[other])), "%s visible panels overlap: %s / %s" % [context, controls[index].name, controls[other].name]):
				return false
	for label: Label in [ui.combo_label, ui.toast_label, ui.hud.collection_label, ui.hud.overdrive_label, ui.boss_health_bar.name_label, ui.boss_health_bar.phase_label, ui.boss_health_bar.health_value_label]:
		if not label.is_visible_in_tree():
			continue
		if not _check(label.size.x + 0.01 >= label.get_minimum_size().x and label.size.y + 0.01 >= label.get_minimum_size().y, "%s text area is smaller than actual font content: %s size=%s min=%s" % [context, label.text, label.size, label.get_minimum_size()]):
			return false
	return true
