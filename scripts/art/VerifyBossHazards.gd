extends SceneTree

const AttackScript = preload("res://scripts/components/TentacleAttack.gd")
const PatternScript = preload("res://scripts/components/BossProjectilePattern.gd")
const FloorScript = preload("res://scripts/world/FloorGrid.gd")
const BossTexture = preload("res://assets/art/actors/enemies/enemy_overseer_chibi_b_v1.png")
const PlayerTexture = preload("res://assets/art/actors/player/player_chibi_b_cardinal_atlas_v1.png")
const OUTPUT := "res://build/diagnostics/boss-hazards-v3/"

class VisualOwner extends Node2D:
	var world_bounds := Rect2()

class Target extends Node2D:
	var hits: Array[float] = []
	func take_damage(amount: float) -> void:
		hits.append(amount)

func _initialize() -> void:
	call_deferred("_run")

func _label(canvas: Node, caption: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = caption
	label.position = at
	label.add_theme_color_override("font_color", Color("123b3b"))
	label.add_theme_font_size_override("font_size", 18)
	canvas.add_child(label)

func _owner(canvas: Node, at: Vector2) -> Node2D:
	var owner := VisualOwner.new()
	owner.position = at
	canvas.add_child(owner)
	var visual := Sprite2D.new()
	visual.texture = BossTexture
	visual.scale = Vector2.ONE * 1.25
	owner.add_child(visual)
	return owner

func _attack(owner: Node2D, target: Node2D, shots: Node) -> Node2D:
	var attack: Node2D = AttackScript.new()
	attack.configure(owner, target, shots)
	owner.add_child(attack)
	attack.process_mode = Node.PROCESS_MODE_DISABLED
	return attack

func _target_visual(target: Node2D) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = PlayerTexture
	atlas.region = Rect2(0, 0, 128, 128)
	var visual := Sprite2D.new()
	visual.texture = atlas
	visual.scale = Vector2.ONE * 0.5
	target.add_child(visual)

func _run() -> void:
	var run_id := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--run="):
			run_id = argument.trim_prefix("--run=")
	if run_id not in ["before", "after"] or FileAccess.file_exists(OUTPUT + run_id + ".json") or FileAccess.file_exists(OUTPUT + run_id + ".png"):
		push_error("Boss hazard capture requires unused --run=before/after")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await process_frame
	var orphan_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var canvas := SubViewport.new()
	canvas.size = Vector2i(1280, 720)
	canvas.world_2d = World2D.new()
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var screen := TextureRect.new()
	screen.texture = canvas.get_texture()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	canvas.add_child(FloorScript.new())
	_label(canvas, "BOSS HAZARDS / " + run_id + " / native 1280x720", Vector2(24, 16))
	_label(canvas, "SWEEP: locked sector, 1s warning / 18 damage", Vector2(24, 62))
	_label(canvas, "AIMED FAN: locked direction / 0.45s warning", Vector2(670, 62))
	_label(canvas, "SLAM: 3 locked targets / 90px diameter", Vector2(24, 416))
	_label(canvas, "SWEEP OFFSET: same cycle, later phase", Vector2(670, 416))
	_label(canvas, "Scripted fixed-step components, not Main, natural Boss fight, real clock, balance or performance acceptance.", Vector2(24, 686))
	var shots := Node2D.new()
	shots.process_mode = Node.PROCESS_MODE_DISABLED
	canvas.add_child(shots)
	var target := Target.new()
	target.position = Vector2(330, 230)
	canvas.add_child(target)
	_target_visual(target)
	var sweep_owner := _owner(canvas, Vector2(105, 230))
	var sweep := _attack(sweep_owner, target, shots)
	var offset_owner := _owner(canvas, Vector2(700, 550))
	var offset_target := Target.new()
	offset_target.position = Vector2(960, 550)
	canvas.add_child(offset_target)
	_target_visual(offset_target)
	var offset_sweep := _attack(offset_owner, offset_target, shots)
	var slam_owner := _owner(canvas, Vector2(105, 540))
	var slam_target := Target.new()
	slam_target.position = Vector2(355, 540)
	canvas.add_child(slam_target)
	_target_visual(slam_target)
	var slam := _attack(slam_owner, slam_target, shots)
	var targets: Array[Vector2] = [Vector2(185, 540), Vector2(355, 540), Vector2(525, 540)]
	var pattern_owner := _owner(canvas, Vector2(700, 230))
	var ranged_target := Node2D.new()
	ranged_target.position = Vector2(1100, 230)
	canvas.add_child(ranged_target)
	var pattern: Node2D = PatternScript.new()
	pattern_owner.add_child(pattern)
	pattern.configure(shots, Rect2(640, 110, 640, 270), ranged_target, 77, 12345)
	pattern.process_mode = Node.PROCESS_MODE_DISABLED
	var poses: Array[Dictionary] = []
	var capture_ok := false
	for frame in range(360):
		if frame % 120 == 0:
			sweep.cancel_attack()
			offset_sweep.cancel_attack()
			slam.cancel_attack()
			pattern.cancel(true)
			await process_frame
			pattern.configure(shots, Rect2(640, 110, 640, 270), ranged_target, 77, 12345)
			sweep.start_sweep(target.position)
			offset_sweep.start_sweep(offset_target.position)
			offset_sweep.advance_attack(0.56)
			slam.start_slam(targets)
		if frame % 120 == 20:
			pattern.start_pattern(&"aimed_fan")
		# Components use explicit delta here; no claim that Movie Maker is real-time gameplay.
		sweep.advance_attack(1.0 / 60.0)
		offset_sweep.advance_attack(1.0 / 60.0)
		slam.advance_attack(1.0 / 60.0)
		pattern.advance(1.0 / 60.0)
		for shot in shots.get_children():
			if not shot.is_queued_for_deletion():
				shot._physics_process(1.0 / 60.0)
		await process_frame
		var shot_poses: Array = []
		for shot in shots.get_children():
			shot_poses.append({"position": [shot.global_position.x, shot.global_position.y],
				"velocity": [shot.velocity.x, shot.velocity.y], "radius": shot.radius, "damage": shot.damage})
		poses.append({"frame": frame, "sweep_stage": sweep.attack_stage, "sweep_elapsed": sweep.elapsed,
			"offset_stage": offset_sweep.attack_stage, "slam_stage": slam.attack_stage,
			"target_hits": target.hits.duplicate(), "offset_hits": offset_target.hits.duplicate(),
			"slam_hits": slam_target.hits.duplicate(), "shot_count": shots.get_child_count(),
			"pattern_total": pattern.get_total_spawned(), "shot_poses": shot_poses})
		if frame in [30, 85]:
			await RenderingServer.frame_post_draw
			var capture := canvas.get_texture().get_image()
			var suffix := ".png" if frame == 30 else "-projectiles.png"
			var saved := capture != null and not capture.is_empty() and capture.save_png(ProjectSettings.globalize_path(OUTPUT + run_id + suffix)) == OK
			capture_ok = saved if frame == 30 else capture_ok and saved
	var report := {"run": run_id, "acceptance": "component_visual_evidence_only", "viewport": [1280, 720],
		"screenshot_ok": capture_ok, "poses": poses, "source_sha256": {},
		"limitations": "Scripted component cycles with plain visual owners/targets, explicit deltas and manual projectile movement. Movie Maker is fixed-pacing evidence, not a natural Boss fight or runtime clock/performance test. No Main, snapshot store or real save used."}
	for path in ["scripts/components/TentacleAttack.gd", "scripts/components/BossProjectilePattern.gd", "scripts/components/BossProjectile.gd", "scripts/art/VerifyBossHazards.gd"]:
		report.source_sha256[path] = FileAccess.get_sha256("res://" + path)
	for attack in [sweep, offset_sweep, slam]:
		attack.cancel_attack()
	pattern.clear()
	await process_frame
	canvas.queue_free()
	screen.queue_free()
	await process_frame
	await process_frame
	report["owned_nodes_freed"] = not is_instance_valid(canvas) and not is_instance_valid(screen)
	report["orphan_before"] = orphan_before
	report["orphan_after"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var valid: bool = capture_ok and report.owned_nodes_freed and report.orphan_after <= orphan_before
	var file := FileAccess.open(OUTPUT + run_id + ".json", FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("BOSS_HAZARDS_COMPLETE run=%s valid=%s" % [run_id, valid])
	quit(0 if valid else 1)
