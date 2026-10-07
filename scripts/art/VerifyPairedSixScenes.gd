extends SceneTree

# Controlled display keyframes. Never a physics/input, FPS or human acceptance claim.
const MainScript = preload("res://scripts/Main.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const BossScript = preload("res://scripts/actors/OverseerBoss.gd")
const LobScript = preload("res://scripts/components/LobbedProjectile.gd")
const ArcScript = preload("res://scripts/components/ArcPulseVisual.gd")
const SpikeScript = preload("res://scripts/components/SpikeTrap.gd")
const ShotScript = preload("res://scripts/components/Projectile.gd")
const PatternScript = preload("res://scripts/components/BossProjectilePattern.gd")
const SCENES := ["opening", "crowd", "dash", "overlap", "boss", "shop"]
const SOURCES := ["scripts/Main.gd", "scripts/actors/Player.gd", "scripts/actors/Enemy.gd",
	"scripts/actors/OverseerBoss.gd", "scripts/ui/GameUI.gd", "scripts/ui/HUD.gd", "scripts/ui/AimReticle.gd",
	"scripts/ui/SettlementScreen.gd", "scripts/components/TentacleAttack.gd",
	"scripts/components/BossProjectilePattern.gd", "scripts/components/LobbedProjectile.gd",
	"scripts/components/Projectile.gd", "scripts/components/ArcPulseVisual.gd", "scripts/components/SpikeTrap.gd",
	"scripts/effects/CombatVfx.gd", "scripts/world/FloorGrid.gd", "scripts/world/ArenaObstacle.gd"]
const DT := 1.0 / 15.0
var output := ""
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	output = OS.get_environment("PAIRED_CAPTURE_DIR")
	var count := 1 if OS.get_environment("PAIRED_SMOKE") == "1" else 30
	if DisplayServer.get_name() == "headless" or output.is_empty() or DirAccess.dir_exists_absolute(output):
		push_error("Need native renderer and a fresh capture directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in SOURCES:
		sources[path] = FileAccess.get_sha256("res://" + path)
	var records: Array[Dictionary] = []
	for scene in SCENES:
		records.append_array(await _scene(scene, count))
		if failed:
			quit(1)
			return
	var report := {"schema": "paired-six-scenes-v1", "scope": "controlled-keyframes-not-natural-input",
		"fixture_sha256": FileAccess.get_sha256("res://scripts/art/VerifyPairedSixScenes.gd"),
		"source_sha256": sources, "frames": records,
		"presentation_branches": "Only newly added Boss local-motion and Main framing hooks are conditional; their absence is the original before presentation, not a replacement implementation."}
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PAIRED_SIX_SCENES_COMPLETE frames=", records.size())
	quit(0)

func _freeze(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_freeze(child)

func _redraw(node: Node) -> void:
	if node is CanvasItem:
		node.queue_redraw()
	for child in node.get_children():
		_redraw(child)

func _vector(value: Vector2) -> Array:
	return [value.x, value.y]

func _labels(node: Node, result: Array) -> void:
	if node is Control and not node.is_visible_in_tree():
		return
	if node is Label or node is Button:
		result.append({"text": node.text, "rect": [_vector(node.get_global_rect().position), _vector(node.size)]})
	for child in node.get_children():
		_labels(child, result)

func _add_enemy(main: Node, kind: int, slot: int) -> Node:
	var enemy := EnemyScript.new()
	enemy.formation_slot_index = slot
	enemy.setup(kind, 2, main.projectiles, main.player)
	main.enemies.add_child(enemy)
	return enemy

func _scene(scene: String, count: int) -> Array[Dictionary]:
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.transparent_bg = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var main := MainScript.new()
	main.audio_enabled = false
	view.add_child(main)
	main.snapshot_store.save_path = "user://paired-six-scenes/diagnostic.json"
	seed(2026100703)
	main._begin_run({})
	main.player.advance_entrance(main.player.get_entrance_duration() + 0.01)
	main._transition_to(main.RunState.PLAYING)
	main.ui.wave_banner.hide()
	main.ui.apply_viewport_size(Vector2(1280, 720))
	main.ui.set_wave(1 if scene == "opening" else 3, 6, 24 if scene == "crowd" else 8)
	main.ui.set_run_stats(76, 85.0)
	main.ui.hud.clear_combo()
	var player: Node2D = main.player
	var camera: Camera2D = player.get_node("PlayerCamera")
	var terrain: Node2D
	var terrain_point := Vector2.ZERO
	var actors: Array[Node] = []
	var boss: Node2D
	var lob: Node2D
	var arc: Node2D
	var spike: Node2D
	var trail: Node2D
	var pattern: Node2D
	if scene == "crowd":
		for prop in main.arena_layout.get_children():
			var point: Vector2 = prop.global_position - Vector2(0, prop.obstacle_size.y + 20)
			if prop.obstacle_kind == &"greenhouse" and main.arena_layout.is_position_walkable(point, 13.0):
				terrain = prop
				terrain_point = point
				break
		if terrain == null:
			push_error("Need a real common foreground greenhouse with a walkable Player point")
			failed = true
		for slot in range(24):
			actors.append(_add_enemy(main, slot % 6, slot))
	elif scene == "overlap":
		actors.append(_add_enemy(main, EnemyScript.EnemyKind.MARKSMAN, 0))
		lob = LobScript.new()
		lob.configure(Vector2(-170, -50), Vector2(0, 45), null)
		main.projectiles.add_child(lob)
		arc = ArcScript.new()
		arc.setup(180.0, 20.0, Callable(), 0.5)
		main.projectiles.add_child(arc)
		spike = SpikeScript.new()
		spike.radius = 52.0
		main.projectiles.add_child(spike)
	elif scene == "boss":
		boss = BossScript.new()
		main.enemies.add_child(boss)
		boss.setup(6, main.projectiles, player)
		boss.get_attack_director().advance(boss.get_attack_director().ENTRANCE_SECONDS + 0.01)
		boss._update_entrance_reveal()
		main.ui.show_boss_health(boss, "深渊监工 / OVERSEER", boss.health.max_health)
		main.ui.set_boss_health(5800.0, 10800.0, 2)
		main.ui.set_combo(8)
		main.ui.show_toast("四向构筑展示")
		if "boss_camera_framing" in main:
			main.boss_camera_framing.track_boss(boss)
		pattern = PatternScript.new()
		main.projectiles.add_child(pattern)
		pattern.configure(main.projectiles, main.WORLD_BOUNDS, player, 77, 2026100703)
	elif scene == "shop":
		main.upgrade_system.add_coins(80)
		if not main.upgrade_system.prepare_settlement(2):
			failed = true
		main.ui.show_settlement()
		main.ui.set_aim_reticle_visible(false)
	if scene == "dash":
		trail = ShotScript.new()
		trail.target_group = &"enemies"
		trail.overdrive_visual = true
		trail.velocity = Vector2(220, 0)
		main.projectiles.add_child(trail)
	_freeze(main)
	for tween in get_processed_tweens():
		tween.pause()
	await process_frame
	var frames: Array[Dictionary] = []
	for index in range(count):
		var time := index * DT
		var cardinal := mini(index / 8, 3)
		player.global_position = Vector2(0, -800 + index * 2) if scene == "opening" else Vector2(-190 + index * 13, 0) if scene == "dash" else Vector2.ZERO
		if scene == "crowd" and index >= 15:
			player.global_position = terrain_point + Vector2(index - 15, 0)
		player.velocity = Vector2(100, 0)
		player.gun_angle = cardinal * PI * 0.5
		player.dash_active = scene == "dash" and index % 8 < 3
		player.dash_direction = Vector2.RIGHT.rotated(player.gun_angle)
		var overdrive := scene in ["dash", "boss"] and index >= 15
		if main.overdrive_active != overdrive:
			main.overdrive_charge = 100.0
			main._set_overdrive(overdrive)
		player._update_visual_animation(DT)
		main.combat_vfx._process(DT)
		var hit_requested := index >= 9 and (index % 3 == 0 or (scene == "crowd" and index < 15))
		for slot in range(actors.size()):
			var enemy: Node2D = actors[slot]
			var angle := TAU * slot / 24.0 + time * 0.14
			enemy.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * (28 if slot < 2 else 78) if scene == "crowd" else player.global_position + Vector2(0, 165)
			enemy.velocity = Vector2(-80, 0)
			enemy._update_static_motion(DT)
			if hit_requested:
				enemy.take_damage(1.0)
			enemy.flash_timer = maxf(0.0, enemy.flash_timer - DT)
			enemy._update_hit_flash()
			if scene == "overlap":
				enemy.ranged_is_winding_up = true
				enemy.ranged_windup_remaining = enemy.ranged_windup_duration * 0.5
				enemy.ranged_target_position = player.global_position
		if lob != null:
			lob.elapsed = lob.flight_duration * (0.25 + 0.5 * index / 30.0)
			lob.global_position = lob.start_position.lerp(lob.target_position, lob.elapsed / lob.flight_duration)
			lob._update_landing_fill()
			arc.position = player.global_position
			arc.age = fmod(time, 0.5)
			spike.position = player.global_position + Vector2(-6, -20)
		if trail != null:
			trail.position = player.global_position + Vector2(22, 0)
		if boss != null:
			boss.global_position = player.global_position + (Vector2(120, 160) if index < 15 else Vector2(280, 630)) + Vector2(sin(time) * 20, 0)
			boss.velocity = Vector2(60, 0)
			boss._update_visual_facing(player.global_position)
			# Only local motion is absent in the original baseline.
			if boss.has_method("_update_boss_motion"):
				boss._update_boss_motion(DT)
			if index % 3 == 0:
				boss.take_damage(1.0)
			boss.flash_timer = maxf(0.0, boss.flash_timer - DT)
			# take_damage already applies each version's real flash strength.
			if boss.flash_timer <= 0.0 and boss.boss_flash_material != null:
				boss.boss_flash_material.set_shader_parameter("flash_amount", 0.0)
			pattern.global_position = boss.global_position
			if index == 0:
				pattern.start_pattern(&"aimed_fan")
				boss.start_tentacle_sweep(player.global_position)
			boss.advance_tentacle_attack(DT)
		if scene == "shop":
			if index == 10 or index == 20:
				var offer: Dictionary = main.upgrade_system.settlement_offers[0 if index == 10 else 1]
				var request := {"id": offer.id, "transaction": offer.transaction}
				var accepted: bool = main.upgrade_system.claim_free_offer(request) if index == 10 else main.upgrade_system.purchase_settlement_offer(request)
				if not accepted:
					failed = true
			main.ui.settlement_screen.offer_buttons[mini(index / 5, 5)].grab_focus()
		for prop in main.arena_layout.get_children():
			if prop.has_method("update_player_occlusion"):
				prop.update_player_occlusion(player.global_position, true, DT)
		player.get_node("PlayerOcclusionOutline")._process(DT)
		_freeze(main)
		for tween in get_processed_tweens():
			tween.pause()
		# Preserve each implementation's settled Camera2D/framing output, not a shared camera crop.
		camera.reset_smoothing()
		camera.force_update_scroll()
		if "boss_camera_framing" in main:
			main.boss_camera_framing.step_framing(1.0)
		camera.reset_smoothing()
		camera.force_update_scroll()
		main.ui.aim_reticle.position = Vector2(640, 360) - main.ui.aim_reticle.size * 0.5
		_redraw(main)
		await process_frame
		await RenderingServer.frame_post_draw
		var file_name := "%s-%03d.png" % [scene, index]
		var capture := view.get_texture().get_image()
		if capture.save_png(output + "/" + file_name) != OK:
			failed = true
		var enemy_specs := []
		for enemy in actors:
			enemy_specs.append({"kind": enemy.kind, "position": _vector(enemy.global_position), "velocity": _vector(enemy.velocity), "health": enemy.health.current_health})
		var texts := []
		_labels(main.ui.root, texts)
		var flash_timers := []
		for enemy in actors:
			flash_timers.append(enemy.flash_timer)
		var condition := {"map_seed": main.map_seed, "time_s": time, "player_position": _vector(player.global_position),
			"player_velocity": _vector(player.velocity), "aim_angle": player.gun_angle, "overdrive": overdrive,
			"dash": player.dash_active, "enemy_specs": enemy_specs, "enemy_hit_requested": hit_requested,
			"terrain_obstacle": {"kind": terrain.obstacle_kind, "position": _vector(terrain.global_position),
				"size": _vector(terrain.obstacle_size), "player_walkable": main.arena_layout.is_position_walkable(player.global_position, 13.0)} if terrain != null and index >= 15 else {},
			"shop_state": main.upgrade_system.get_settlement_state() if scene == "shop" else {},
			"boss_position": _vector(boss.global_position) if boss != null else [], "player_health": player.health.current_health}
		var record := {"scene": scene, "frame": index, "condition": condition, "file": file_name,
			"sha256": FileAccess.get_sha256(output + "/" + file_name), "rendered": {
			"camera_center": _vector(camera.get_screen_center_position()), "camera_zoom": _vector(camera.zoom),
			"player_screen": _vector(view.get_canvas_transform() * player.to_global(player.get_body_visual_center())),
			"player_modulate": [player.modulate.r, player.modulate.g, player.modulate.b, player.modulate.a],
			"outline_visible": player.get_node("PlayerOcclusionOutline").visible, "ui_labels": texts,
			"terrain_alpha": terrain.modulate.a if terrain != null else 1.0, "enemy_flash_timers": flash_timers,
			"boss_texture": boss.boss_visual.texture.resource_path if boss != null and "boss_visual" in boss else "original-procedural"}}
		var hidden: Array[CanvasItem] = []
		for node in main.world.get_children():
			if node != player and node is CanvasItem and node.visible:
				node.hide()
				hidden.append(node)
		main.ui.root.hide()
		var outline: CanvasItem = player.get_node("PlayerOcclusionOutline")
		var outline_visible := outline.visible
		outline.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		var alpha_name := "%s-%03d.alpha.png" % [scene, index]
		if view.get_texture().get_image().save_png(output + "/" + alpha_name) != OK:
			failed = true
		record.player_reference_file = alpha_name
		record.player_reference_sha256 = FileAccess.get_sha256(output + "/" + alpha_name)
		frames.append(record)
		for node in hidden:
			node.show()
		main.ui.root.show()
		outline.visible = outline_visible
	view.queue_free()
	await process_frame
	await process_frame
	return frames
