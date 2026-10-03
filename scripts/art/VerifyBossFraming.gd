extends "res://scripts/tests/BossCameraFramingTest.gd"

# Frozen component poses, NOT a natural-playthrough or opaque-pixel measurement.
var run_id := ""
var measurements: Array[Dictionary] = []

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Boss framing images require a real rendering driver")
		quit(1)
		return
	run_id = OS.get_environment("BOSS_FRAMING_RUN_ID")
	if run_id.is_empty() or not run_id.is_valid_filename():
		push_error("BOSS_FRAMING_RUN_ID must be a fresh filename")
		quit(1)
		return
	var output := "res://build/diagnostics/boss-framing/" + run_id
	if DirAccess.dir_exists_absolute(output):
		push_error("Refusing to overwrite evidence: " + output)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	view = SubViewport.new()
	view.world_2d = World2D.new()
	view.size = VIEWPORT_SIZES[0]
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	scene = FixtureMain.new()
	scene.audio_enabled = false
	view.add_child(scene)
	await process_frame
	scene._build_world()
	scene._begin_run({})
	_freeze_simulation(scene)
	scene.player.entrance_active = false
	scene.player.entrance_visual_offset = 0.0
	scene.player.modulate = Color.WHITE
	scene.run_state = MainScript.RunState.PLAYING
	paused = false
	camera = scene.player.get_node("PlayerCamera")
	camera.make_current()
	boss = scene.wave_director._spawn_boss_at(Vector2(0, -240))
	_freeze_simulation(scene)
	boss._physics_process(1.41)
	_freeze_simulation(scene)
	paused = false
	scene.ui.set_combo(3)
	scene.ui.set_overdrive_charge(60.0, false)
	for viewport_size in VIEWPORT_SIZES:
		view.size = viewport_size
		scene.ui.apply_viewport_size(Vector2(viewport_size))
		await process_frame
		await process_frame
		var nearby := Vector2(0, -100) if viewport_size.x == 960 else Vector2(0, -240)
		var poses := [[Vector2.ZERO, nearby], [Vector2(1300, -840), Vector2(1100, -700)], [Vector2.ZERO, Vector2(0, 750)]]
		for index in range(poses.size()):
			scene.player.global_position = poses[index][0]
			boss.global_position = poses[index][1]
			_settle_camera()
			scene.player.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var name := "%dx%d-pose%d.png" % [viewport_size.x, viewport_size.y, index]
			var path := output + "/" + name
			var save_error := view.get_texture().get_image().save_png(path)
			if save_error != OK:
				push_error("Screenshot failed: " + path)
				_cleanup()
				quit(1)
				return
			var blockers: Array[Dictionary] = []
			for control in [scene.ui.hud.grid, scene.ui.boss_health_bar, scene.ui.combo_panel, scene.ui.hud.overdrive_panel, scene.ui.hud.collection_panel, scene.ui.toast_panel]:
				if control.is_visible_in_tree():
					blockers.append({"name": control.name, "rect": _rect_array(_control_screen_rect(control))})
			measurements.append({"file": name, "sha256": FileAccess.get_sha256(path), "viewport": [viewport_size.x, viewport_size.y], "player_world": [scene.player.global_position.x, scene.player.global_position.y], "boss_world": [boss.global_position.x, boss.global_position.y], "player_rect": _rect_array(_player_screen_rect()), "boss_rect": _rect_array(_sprite_screen_rect(boss.boss_visual)), "zoom": camera.zoom.x, "ui": blockers})
	await _capture_dynamic(output)
	if failed:
		_cleanup()
		await process_frame
		quit(1)
		return
	var sources: Dictionary = {}
	for path in ["scripts/Main.gd", "scripts/ui/GameUI.gd", "scripts/art/VerifyBossFraming.gd", "scripts/tests/BossCameraFramingTest.gd", "scripts/systems/BossCameraFraming.gd", "scripts/systems/CombatView.gd", "scripts/ui/BossDirectionIndicator.gd", "scripts/actors/Player.gd", "scripts/actors/OverseerBoss.gd", "scripts/ui/HUD.gd", "scripts/ui/BossHealthBar.gd", "scripts/effects/CameraEffects.gd", "themes/MintFarmTheme.tres", "scenes/ui/HUD.tscn", "assets/art/actors/player/player_chibi_b_cardinal_atlas_v1.png", "assets/art/actors/player/player_chibi_b_weapon_cardinal_atlas_v1.png", "assets/art/actors/enemies/enemy_overseer_chibi_b_v1.png", "scripts/world/FloorGrid.gd", "scripts/world/ArenaObstacle.gd", "assets/art/environment/mint_farm_floor_b_v1.png", "assets/art/environment/mint_farm_props_b_packed_v1.png", "assets/art/environment/floor_surface.gdshader", "assets/art/environment/prop_alpha.gdshader"]:
		if FileAccess.file_exists("res://" + path):
			sources[path] = FileAccess.get_sha256("res://" + path)
	var manifest := FileAccess.open(output + "/manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"scope": "frozen component poses, conservative rectangles; no natural input", "sources": sources, "images": measurements}, "\t"))
	manifest.close()
	_cleanup()
	await process_frame
	print("BOSS FRAMING CAPTURE: %s images=%d" % [run_id, measurements.size()])
	quit(0)

func _capture_dynamic(output: String) -> void:
	var rig: Node = scene.boss_camera_framing
	if rig == null:
		return
	view.size = Vector2i(1280, 720)
	scene.ui.apply_viewport_size(Vector2(view.size))
	scene.player.global_position = Vector2.ZERO
	boss.global_position = Vector2(0, -240)
	_settle_camera()
	var frames: Array[Dictionary] = []
	DirAccess.make_dir_recursive_absolute(output + "/dynamic")
	for frame in range(240):
		var angle := float(frame) * TAU / 240.0
		scene.player.global_position = Vector2(frame * 1.0, sin(angle) * 80.0)
		var distance := 300.0 if frame < 120 else 700.0
		boss.global_position = scene.player.global_position + Vector2.UP.rotated(angle) * distance
		rig.step_framing(1.0 / 60.0)
		scene.player.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := output + "/dynamic/%03d.png" % frame
		if view.get_texture().get_image().save_png(path) != OK:
			failed = true
			push_error("Dynamic screenshot failed: " + path)
			return
		frames.append({"frame": frame, "sha256": FileAccess.get_sha256(path), "zoom": camera.zoom.x, "player_rect": _rect_array(_player_screen_rect()), "boss_rect": _rect_array(_sprite_screen_rect(boss.boss_visual)), "both_fit": rig.both_fit, "cue_visible": scene.ui.boss_direction_indicator.visible})
	var record := FileAccess.open(output + "/dynamic.json", FileAccess.WRITE)
	record.store_string(JSON.stringify({"scope": "240 consecutive controlled component frames, 1/60 solver delta, frozen physics; not natural play or realtime performance", "frames": frames}, "\t"))
	record.close()

func _rect_array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
