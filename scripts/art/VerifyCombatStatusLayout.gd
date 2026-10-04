extends "res://scripts/tests/CombatStatusLayoutTest.gd"

const FloorScript = preload("res://scripts/world/FloorGrid.gd")
const SOURCES := ["scripts/art/VerifyCombatStatusLayout.gd", "scripts/tests/CombatStatusLayoutTest.gd", "scripts/ui/GameUI.gd", "scripts/ui/HUD.gd", "scripts/ui/BossHealthBar.gd", "scripts/ui/BossDirectionIndicator.gd", "scripts/ui/AimReticle.gd", "themes/MintFarmTheme.tres", "scenes/ui/HUD.tscn", "scripts/world/FloorGrid.gd", "assets/art/environment/mint_farm_floor_b_v1.png", "assets/art/environment/floor_surface.gdshader"]

func _initialize() -> void:
	var run_id := OS.get_environment("COMBAT_STATUS_RUN_ID")
	var output := "res://build/diagnostics/combat-status/" + run_id
	if DisplayServer.get_name() == "headless" or run_id.is_empty() or not run_id.is_valid_filename() or DirAccess.dir_exists_absolute(output):
		push_error("Status capture requires real rendering and a fresh safe run ID")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output + "/source")
	var hashes := {}
	# Freeze the exact before/after fixture and production bytes before rendering.
	for path: String in SOURCES:
		var destination: String = output + "/source/" + path
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		if DirAccess.copy_absolute("res://" + path, destination) != OK:
			push_error("Source freeze failed: " + path)
			quit(1)
			return
		hashes[path] = FileAccess.get_sha256(destination)
	await process_frame
	var records: Array[Dictionary] = []
	for dimensions in SIZES:
		view = SubViewport.new()
		view.size = dimensions
		view.world_2d = World2D.new()
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		view.add_child(FloorScript.new())
		ui = UIScript.new()
		view.add_child(ui)
		ui.apply_viewport_size(Vector2(dimensions))
		ui.hide_start_screen()
		for mode: String in ["boss_combo", "boss_overdrive", "boss_all", "ordinary_toast"]:
			ui.hide_boss_health()
			ui.clear_combo()
			ui.hud._finish_toast()
			if mode.begins_with("boss"):
				ui.show_boss_health(null, "深渊监工 / OVERSEER", 10800)
				ui.set_boss_health(5800, 10800, 2)
			if mode == "boss_combo" or mode == "boss_all":
				ui.set_combo(9999)
			if mode == "boss_overdrive":
				ui.set_overdrive(true, 3.2)
			if mode == "boss_all" or mode == "ordinary_toast":
				ui.show_toast("激光协同强化")
				ui.hud.toast_tween.kill()
			for timing: String in ["first_draw", "settled"]:
				if timing == "first_draw":
					await process_frame
				else:
					await _settle_layout()
				await RenderingServer.frame_post_draw
				var record := _capture_image(dimensions, mode, timing, output)
				if record.is_empty():
					failed = true
					break
				records.append(record)
			if failed:
				break
		view.free()
		view = null
		ui = null
		if failed:
			break
	for path: String in hashes:
		if FileAccess.get_sha256("res://" + path) != hashes[path]:
			failed = true
	var file := FileAccess.open(output + "/manifest.json", FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"run": run_id, "valid": not failed and records.size() == 32, "images": records, "source_sha256": hashes, "scope": "Actual GameUI/FloorGrid, first rendered frame and settled fixed messages at four sizes; no Main, stores, natural input or performance"}, "\t"))
	file.close()
	await process_frame
	print("STATUS CAPTURE: %s valid=%s frames=%d" % [run_id, not failed, records.size()])
	quit(1 if failed or records.size() != 32 else 0)

func _capture_image(dimensions: Vector2i, mode: String, timing: String, output: String) -> Dictionary:
	var path := output + "/%dx%d-%s-%s.png" % [dimensions.x, dimensions.y, mode, timing]
	var bitmap := view.get_texture().get_image()
	if bitmap == null or bitmap.is_empty() or bitmap.get_size() != dimensions or bitmap.save_png(path) != OK:
		return {}
	var panels: Array[Dictionary] = []
	for control in ui.get_combat_occluders():
		panels.append({"path": str(control.get_path()), "rect": _serialize_rect(_rect(control))})
	var labels: Array[Dictionary] = []
	for label: Label in [ui.combo_label, ui.toast_label, ui.boss_health_bar.name_label, ui.boss_health_bar.phase_label, ui.boss_health_bar.health_value_label]:
		if label.is_visible_in_tree():
			var minimum := label.get_minimum_size()
			labels.append({"text": label.text, "rect": _serialize_rect(_rect(label)), "minimum_size": [minimum.x, minimum.y]})
	return {"file": path.get_file(), "sha256": FileAccess.get_sha256(path), "viewport": [dimensions.x, dimensions.y], "mode": mode, "timing": timing, "panels": panels, "labels": labels, "combo": ui.combo_label.text, "toast": ui.toast_label.text}

func _serialize_rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
