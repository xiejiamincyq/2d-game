extends SceneTree

const UIScript = preload("res://scripts/ui/GameUI.gd")
const FloorScript = preload("res://scripts/world/FloorGrid.gd")
const OUTPUT := "res://build/diagnostics/ui-art-v3/"

func _initialize() -> void:
	call_deferred("_run")

func _settlement_state() -> Dictionary:
	var families: Array[Dictionary] = []
	var offers: Array[Dictionary] = []
	for family in ["ballistics", "mobility", "automation"]:
		var family_label: String = {"ballistics": "火力", "mobility": "机动", "automation": "工程"}[family]
		var family_offers: Array[Dictionary] = []
		for index in range(2):
			var offer := {"id": family + str(index), "family": family, "family_label": family_label,
				"label": family_label + ("强化" if index == 0 else "协同"), "description": "提升模块效率，构建联动组合",
				"cost": 20 + index * 10, "sold": false, "capped": false,
				"affordable": not (family == "automation" and index == 1), "transaction_id": 7}
			family_offers.append(offer)
			offers.append(offer)
		families.append({"id": family, "label": family_label, "level": 2, "offers": family_offers})
	return {"wave": 2, "coins": 25, "reward_claimed": true, "can_close": true,
		"family_levels": {"ballistics": 2, "mobility": 2, "automation": 2}, "families": families, "offers": offers}

func _run() -> void:
	var run_id := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--run="):
			run_id = argument.trim_prefix("--run=")
	if run_id not in ["before", "after"] or FileAccess.file_exists(OUTPUT + run_id + ".json"):
		push_error("UI art preview requires unused --run=before/after")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await process_frame
	var orphan_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var frames: Array[Dictionary] = []
	var valid := true
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540)]:
		var canvas := SubViewport.new()
		canvas.size = dimensions
		canvas.world_2d = World2D.new()
		canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(canvas)
		canvas.add_child(FloorScript.new())
		var ui: Node = UIScript.new()
		canvas.add_child(ui)
		ui.apply_viewport_size(Vector2(dimensions))
		ui.set_continue_available(true)
		ui.set_health(73, 100)
		ui.set_shield(22, 60)
		ui.set_progression_state({"coins": 25, "family_levels": {"ballistics": 2, "mobility": 2, "automation": 2}})
		ui.set_wave(2, 6, 24)
		ui.set_run_stats(76, 85.0)
		ui.set_settlement_state(_settlement_state())
		if ui.settlement_screen.current_offers.size() != 6:
			push_error("UI preview fixture must expose all six settlement cards")
			quit(1)
			return
		for screen_name in ["start", "hud", "overdrive", "settlement", "pause", "result", "boss"]:
			ui.hide_start_screen()
			ui.hide_settlement()
			ui.hide_manual_pause()
			ui.hide_result()
			ui.hide_boss_intro()
			ui.hide_boss_health()
			ui.clear_combo()
			ui.set_overdrive_charge(63, false)
			match screen_name:
				"start": ui.show_start_screen()
				"overdrive":
					ui.set_overdrive_charge(100, true)
					ui.set_overdrive(true, 3.2)
				"settlement": ui.show_settlement()
				"pause": ui.show_manual_pause()
				"result": ui.show_result(true, "抵达阶段 6/6", 321, 299.0, {"coins": 25, "family_levels": {"ballistics": 4, "mobility": 3, "automation": 2}})
				"boss":
					ui.show_boss_health(null, "深渊监工 / OVERSEER", 10800)
					ui.set_boss_health(5800, 10800, 2)
					ui.show_boss_intro("深渊监工 / OVERSEER", 1.4)
					ui.boss_entrance_overlay.elapsed = 0.7
					ui.boss_entrance_overlay.process_mode = Node.PROCESS_MODE_DISABLED
			for wait_frame in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var filename := "%s-%dx%d-%s.png" % [run_id, dimensions.x, dimensions.y, screen_name]
			var capture := canvas.get_texture().get_image()
			var ok := capture != null and not capture.is_empty() and capture.save_png(ProjectSettings.globalize_path(OUTPUT + filename)) == OK
			valid = valid and ok
			frames.append({"screen": screen_name, "viewport": [dimensions.x, dimensions.y], "file": filename,
				"saved": ok, "theme": ui.root.theme.resource_path,
				"settlement_minimum": [ui.settlement_screen.panel.get_combined_minimum_size().x, ui.settlement_screen.panel.get_combined_minimum_size().y]})
		canvas.queue_free()
		await process_frame
		await process_frame
		valid = valid and not is_instance_valid(canvas)
	var hashes := {}
	for path in ["scripts/art/VerifyUIArt.gd", "scripts/ui/GameUI.gd", "scripts/ui/HUD.gd", "scripts/ui/PauseScreen.gd", "scripts/ui/ResultScreen.gd", "scripts/ui/SettlementScreen.gd", "scripts/ui/WaveBanner.gd", "scripts/ui/BossHealthBar.gd", "scripts/ui/BossEntranceOverlay.gd", "themes/CyberTheme.tres", "themes/MintFarmTheme.tres"]:
		if FileAccess.file_exists("res://" + path):
			hashes[path] = FileAccess.get_sha256("res://" + path)
	var orphan_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	valid = valid and orphan_after <= orphan_before
	var file := FileAccess.open(OUTPUT + run_id + ".json", FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"run": run_id, "acceptance": "component_visual_evidence_only", "valid": valid,
		"frames": frames, "source_sha256": hashes, "orphan_before": orphan_before, "orphan_after": orphan_after,
		"limitations": "Actual GameUI + FloorGrid rendered on Vulkan. Explicit synthetic UI states, not natural inputs, gameplay, save/load, performance or whole-run acceptance. No Main or stores instantiated."}, "  "))
	file.close()
	print("UI_ART_COMPLETE run=%s valid=%s frames=%d" % [run_id, valid, frames.size()])
	quit(0 if valid else 1)
