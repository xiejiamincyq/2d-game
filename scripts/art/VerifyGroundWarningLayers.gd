extends SceneTree

# Static real-component render at 1:1 scale; not natural combat or input evidence.
const Player = preload("res://scripts/actors/Player.gd")
const Enemy = preload("res://scripts/actors/Enemy.gd")
const Lob = preload("res://scripts/components/LobbedProjectile.gd")
const Tentacle = preload("res://scripts/components/TentacleAttack.gd")
const Pattern = preload("res://scripts/components/BossProjectilePattern.gd")
const Shot = preload("res://scripts/components/Projectile.gd")
const CASES := ["control", "marksman", "lob_rim", "lob_impact", "slam", "sweep_warning", "sweep_active", "aimed_fan", "friendly_trail", "hostile_core"]
const SOURCES := ["scripts/art/VerifyGroundWarningLayers.gd", "scripts/actors/Player.gd", "scripts/actors/Enemy.gd", "scripts/components/LobbedProjectile.gd", "scripts/components/TentacleAttack.gd", "scripts/components/BossProjectilePattern.gd", "scripts/components/Projectile.gd", "assets/art/actors/player/player_chibi_b_cardinal_atlas_v1.png", "assets/art/actors/player/player_chibi_b_weapon_cardinal_atlas_v1.png"]

class Owner extends Node2D:
	var world_bounds := Rect2()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--run="):
			run = argument.trim_prefix("--run=")
	var output := "res://build/diagnostics/ground-warning/" + run
	if run not in ["before-v1", "after-v1", "before-v2", "after-v2"] or DisplayServer.get_name() == "headless" or DirAccess.dir_exists_absolute(output):
		push_error("Need native rendering and unused --run=before/after-v1/v2")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output + "/source")
	var hashes := {}
	for path in SOURCES:
		DirAccess.make_dir_recursive_absolute((output + "/source/" + path).get_base_dir())
		if DirAccess.copy_absolute("res://" + path, output + "/source/" + path) != OK:
			quit(1)
			return
		hashes[path] = FileAccess.get_sha256("res://" + path)
	seed(20261007)
	var records: Array[Dictionary] = []
	for cardinal in range(4):
		for case_name in CASES:
			records.append(await _case(output, cardinal, case_name))
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"run": run, "source_sha256": hashes, "cases": records,
		"scope": "40 frozen real-component 256x256 renders; opaque Player body/weapon at native runtime size. No Main, stores, physics movement, natural fight, performance or human acceptance."}, "  "))
	file.close()
	print("GROUND_WARNING_CAPTURE_COMPLETE ", run, " cases=", records.size())
	quit(0)

func _case(output: String, cardinal: int, case_name: String) -> Dictionary:
	var view := SubViewport.new()
	view.size = Vector2i(256, 256)
	view.transparent_bg = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([Vector2.ZERO, Vector2(256, 0), Vector2(256, 256), Vector2(0, 256)])
	floor.color = Color("9bd7bd")
	floor.z_index = -100
	view.add_child(floor)
	var holder := Node2D.new()
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	view.add_child(holder)
	var player := Player.new()
	player.position = Vector2(128, 128)
	holder.add_child(player)
	player.begin_entrance()
	player.advance_entrance(player.get_entrance_duration() + 0.01)
	player.gun_angle = [PI * 0.5, -PI * 0.5, PI, 0.0][cardinal]
	player.queue_redraw()
	var shots := Node2D.new()
	shots.z_index = 22
	holder.add_child(shots)
	var mechanics := {}
	match case_name:
		"marksman":
			var enemy := Enemy.new()
			enemy.setup(Enemy.EnemyKind.MARKSMAN, 0, shots, player)
			enemy.position = Vector2(128, 228)
			holder.add_child(enemy)
			enemy.ranged_is_winding_up = true
			enemy.ranged_windup_remaining = enemy.ranged_windup_duration * 0.5
			enemy.ranged_target_position = player.position
			enemy.queue_redraw()
			mechanics = {"target": enemy.ranged_target_position, "windup": enemy.ranged_windup_remaining, "duration": enemy.ranged_windup_duration, "radius": enemy.body_radius}
		"lob_rim", "lob_impact":
			var lob := Lob.new()
			lob.configure(Vector2(0, 240), Vector2(128, 200), null)
			shots.add_child(lob)
			lob.elapsed = lob.flight_duration * 0.5
			lob.global_position = lob.start_position.lerp(lob.target_position, 0.5)
			lob._update_landing_fill()
			lob.queue_redraw()
			mechanics = {"target": lob.target_position, "damage": lob.damage, "radius": lob.splash_radius, "duration": lob.flight_duration, "elapsed": lob.elapsed, "position": lob.global_position}
			if case_name == "lob_impact":
				lob._explode()
		"slam", "sweep_warning", "sweep_active":
			var boss := Owner.new()
			boss.position = Vector2(0, 128)
			holder.add_child(boss)
			var attack := Tentacle.new()
			attack.configure(boss, player, shots)
			boss.add_child(attack)
			if case_name == "slam":
				attack.start_slam([Vector2(128, 173), Vector2(288.1, 173)])
			else:
				attack.start_sweep(boss.position + Vector2.RIGHT.rotated(deg_to_rad(27)) * 128)
				if case_name == "sweep_active":
					attack.advance_attack(1.001)
			mechanics = {"kind": attack.attack_kind, "stage": attack.attack_stage, "elapsed": attack.elapsed, "angle": attack.sweep_angle, "targets": attack.slam_targets.duplicate(), "sweep_radius": attack.SWEEP_RANGE, "slam_radius": attack.SLAM_RADIUS}
		"aimed_fan":
			var pattern := Pattern.new()
			pattern.position = Vector2(0, 128)
			shots.add_child(pattern)
			pattern.configure(shots, Rect2(-500, -500, 1000, 1000), player, 77, 20261007)
			pattern.start_pattern(&"aimed_fan")
			mechanics = {"elapsed": pattern._elapsed, "plan": pattern._active_plan, "cursor": pattern._event_cursor, "rng_state": pattern._rng.state, "spawned": pattern._total_spawned}
		"friendly_trail", "hostile_core":
			var bullet := Shot.new()
			bullet.overdrive_visual = case_name == "friendly_trail"
			bullet.target_group = &"enemies" if bullet.overdrive_visual else &"player"
			bullet.velocity = Vector2(220, 0)
			bullet.position = Vector2(150, 128) if bullet.overdrive_visual else Vector2(128, 128)
			shots.add_child(bullet)
			bullet.queue_redraw()
			mechanics = {"position": bullet.position, "velocity": bullet.velocity, "radius": bullet.radius, "damage": bullet.damage, "pierce": bullet.pierce, "lifetime": bullet.lifetime, "target": bullet.target_group}
	await process_frame
	# Flush updated callbacks without advancing the frozen gameplay nodes.
	for node in holder.get_children():
		_queue_descendants(node)
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := view.get_texture().get_image()
	var name := "%d-%s.png" % [cardinal, case_name]
	if capture.is_empty() or capture.save_png(ProjectSettings.globalize_path(output + "/" + name)) != OK:
		push_error("Native capture failed")
		quit(1)
	var record := {"cardinal": cardinal, "case": case_name, "file": name, "sha256": FileAccess.get_sha256(output + "/" + name), "mechanics": mechanics}
	# Same real Player, including actual sweep damage tint, on transparent background.
	floor.hide()
	for node in holder.get_children():
		if node != player and node is CanvasItem:
			node.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var alpha_name := "%d-%s-player-alpha.png" % [cardinal, case_name]
	var alpha_capture := view.get_texture().get_image()
	if alpha_capture.is_empty() or alpha_capture.save_png(ProjectSettings.globalize_path(output + "/" + alpha_name)) != OK:
		push_error("Native Player alpha capture failed")
		quit(1)
	record["player_alpha_file"] = alpha_name
	record["player_alpha_sha256"] = FileAccess.get_sha256(output + "/" + alpha_name)
	record["player_health"] = player.health.current_health
	record["player_hit_timer"] = player.visual_hit_timer
	view.queue_free()
	await process_frame
	return record

func _queue_descendants(node: Node) -> void:
	if node is CanvasItem:
		node.queue_redraw()
	for child in node.get_children():
		_queue_descendants(child)
