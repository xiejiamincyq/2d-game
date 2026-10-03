extends SceneTree

const UIScript = preload("res://scripts/ui/GameUI.gd")
const FloorScript = preload("res://scripts/world/FloorGrid.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const BossScript = preload("res://scripts/actors/OverseerBoss.gd")
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
	if run_id in ["reticle-before-v1", "reticle-after-v1"]:
		await _reticle_probe(run_id)
		return
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

func _reticle_probe(run_id: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Reticle evidence requires a real rendering driver")
		quit(2)
		return
	var dimensions_list := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]
	var targets := ["scrapper", "boss", "floor"]
	var paths := [OUTPUT + run_id + ".json"]
	for dimensions: Vector2i in dimensions_list:
		for target_name: String in targets:
			for state: String in ["hidden", "visible"]:
				paths.append(OUTPUT + "%s-%dx%d-%s-%s.png" % [run_id, dimensions.x, dimensions.y, target_name, state])
	for path: String in paths:
		if FileAccess.file_exists(path):
			push_error("Reticle capture refuses existing output: " + path)
			quit(2)
			return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await process_frame
	var orphan_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var records: Array[Dictionary] = []
	var valid := true
	for dimensions: Vector2i in dimensions_list:
		var canvas := SubViewport.new()
		canvas.size = dimensions
		canvas.world_2d = World2D.new()
		canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(canvas)
		canvas.add_child(FloorScript.new())
		var projectiles := Node2D.new()
		canvas.add_child(projectiles)
		var scrapper: Node2D = EnemyScript.new()
		scrapper.setup(EnemyScript.EnemyKind.SCRAPPER, 1, projectiles)
		scrapper.position = Vector2(dimensions) * Vector2(0.25, 0.5)
		canvas.add_child(scrapper)
		scrapper.process_mode = Node.PROCESS_MODE_DISABLED
		var boss: Node2D = BossScript.new()
		boss.setup(6, projectiles)
		boss.position = Vector2(dimensions) * Vector2(0.75, 0.5)
		canvas.add_child(boss)
		boss._physics_process(1.41) # Explicit component entrance; no Main, natural fight or saves.
		boss.process_mode = Node.PROCESS_MODE_DISABLED
		var ui: Node = UIScript.new()
		canvas.add_child(ui)
		ui.apply_viewport_size(Vector2(dimensions))
		ui.hide_start_screen()
		for target_name: String in targets:
			var point: Vector2 = {"scrapper": scrapper.position, "boss": boss.position, "floor": Vector2(dimensions) * Vector2(0.5, 0.75)}[target_name]
			for state: String in ["hidden", "visible"]:
				ui.set_aim_reticle_visible(state == "visible")
				ui.aim_reticle.set_process(false) # Fixed component aim point, not an input replay.
				ui.aim_reticle.set_screen_position(point)
				for wait_frame in range(3):
					await process_frame
				await RenderingServer.frame_post_draw
				var path: String = OUTPUT + "%s-%dx%d-%s-%s.png" % [run_id, dimensions.x, dimensions.y, target_name, state]
				var bitmap := canvas.get_texture().get_image()
				var ok := bitmap != null and not bitmap.is_empty() and bitmap.get_size() == dimensions and bitmap.save_png(ProjectSettings.globalize_path(path)) == OK
				valid = valid and ok
				records.append({"target": target_name, "state": state, "viewport": [dimensions.x, dimensions.y], "aim": [point.x, point.y], "reticle_size": [ui.aim_reticle.size.x, ui.aim_reticle.size.y], "path": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path), "saved": ok})
		canvas.queue_free()
		await process_frame
		await process_frame
		valid = valid and not is_instance_valid(canvas)
	var hashes := {}
	for path: String in ["scripts/art/VerifyUIArt.gd", "scripts/ui/GameUI.gd", "scripts/ui/AimReticle.gd", "scripts/world/FloorGrid.gd", "scripts/actors/Enemy.gd", "scripts/actors/OverseerBoss.gd", "themes/MintFarmTheme.tres", "assets/art/actors/enemies/enemy_scrapper_chibi_b_v1.png", "assets/art/actors/enemies/enemy_overseer_chibi_b_v1.png", "assets/art/environment/mint_farm_floor_b_v1.png", "assets/art/environment/floor_surface.gdshader"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	var orphan_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	valid = valid and records.size() == 24 and orphan_after <= orphan_before
	var file := FileAccess.open(OUTPUT + run_id + ".json", FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify({"run": run_id, "valid": valid, "frames": records, "source_sha256": hashes, "orphan_before": orphan_before, "orphan_after": orphan_after, "adapter": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(), "scope": "Native static GameUI / actual frozen actors at runtime scale. Explicit aim points, not natural inputs, motion, game state transitions, performance or full S3 acceptance."}, "  "))
	file.close()
	print("RETICLE_CAPTURE_COMPLETE run=%s valid=%s frames=%d" % [run_id, valid, records.size()])
	quit(0 if valid else 1)
