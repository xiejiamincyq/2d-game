extends SceneTree

const BossScript = preload("res://scripts/actors/OverseerBoss.gd")
const FloorScript = preload("res://scripts/world/FloorGrid.gd")
const OUTPUT := "res://build/diagnostics/boss-art/"

func _initialize() -> void:
	call_deferred("_run")

func _label(canvas: Node, text: String, at: Vector2, font_size := 20) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("123b3b"))
	canvas.add_child(label)

func _boss(canvas: Node, projectiles: Node, at: Vector2, target_at: Vector2, frozen: bool) -> Node2D:
	var target := Node2D.new()
	target.position = target_at
	canvas.add_child(target)
	var boss: Node2D = BossScript.new()
	boss.position = at
	boss.world_bounds = Rect2(0, 160, 1280, 560)
	boss.setup(6, projectiles, target)
	canvas.add_child(boss)
	if frozen:
		boss._physics_process(1.41) # Explicit component pose, not a natural entrance test.
		boss.process_mode = Node.PROCESS_MODE_DISABLED
	return boss

func _run() -> void:
	var run_id := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--run="):
			run_id = argument.trim_prefix("--run=")
	if run_id not in ["before", "after"] or FileAccess.file_exists(OUTPUT + run_id + ".json") or FileAccess.file_exists(OUTPUT + run_id + ".png"):
		push_error("Boss art diagnostic requires unused --run=before/after")
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
	_label(canvas, "FINAL BOSS / %s / native 160px presentation" % run_id, Vector2(24, 20), 26)
	_label(canvas, "Frozen right/left above; actual Boss physics + scripted target below.", Vector2(24, 60))
	_label(canvas, "Component fixed-frame preview: no Main, saves, input playtest, performance or full-run acceptance.", Vector2(24, 680), 16)
	_label(canvas, "RIGHT", Vector2(290, 160))
	_label(canvas, "LEFT", Vector2(930, 160))
	_label(canvas, "MOVING / actual Boss physics", Vector2(440, 400))
	var projectiles := Node2D.new()
	canvas.add_child(projectiles)
	var right := _boss(canvas, projectiles, Vector2(320, 285), Vector2(700, 285), true)
	var left := _boss(canvas, projectiles, Vector2(960, 285), Vector2(600, 285), true)
	var moving := _boss(canvas, projectiles, Vector2(640, 555), Vector2(1020, 555), false)
	var poses: Array[Dictionary] = []
	var capture_ok := false
	for frame in range(360):
		if frame == 180:
			moving.target_player.position = Vector2(220, 555)
		await process_frame
		poses.append({"frame": frame, "position": [moving.position.x, moving.position.y],
			"velocity": [moving.velocity.x, moving.velocity.y], "flip_h": moving.boss_visual.flip_h,
			"visual_offset": [moving.boss_visual.position.x, moving.boss_visual.position.y],
			"visual_rotation": moving.boss_visual.rotation,
			"visual_scale": [moving.boss_visual.scale.x, moving.boss_visual.scale.y],
			"entrance_resolved": moving.entrance_resolved, "alpha": moving.modulate.a})
		if frame == 300:
			await RenderingServer.frame_post_draw
			var capture := canvas.get_texture().get_image()
			capture_ok = capture != null and not capture.is_empty() and capture.save_png(ProjectSettings.globalize_path(OUTPUT + run_id + ".png")) == OK
	var report := {"run": run_id, "acceptance": "component_visual_evidence_only", "viewport": [1280, 720],
		"boss_texture": moving.boss_visual.texture.resource_path, "body_radius": moving.body_radius,
		"health": moving.health.current_health, "right_flip": right.boss_visual.flip_h, "left_flip": left.boss_visual.flip_h,
		"poses": poses, "screenshot_ok": capture_ok,
		"source_sha256": {"OverseerBoss.gd": FileAccess.get_sha256("res://scripts/actors/OverseerBoss.gd"),
			"BossAttackDirector.gd": FileAccess.get_sha256("res://scripts/components/BossAttackDirector.gd"),
			"VerifyBossArt.gd": FileAccess.get_sha256("res://scripts/art/VerifyBossArt.gd")},
		"limitations": "Frozen poses explicitly advance entrance. Moving Boss uses engine physics; plain target is relocated at frame 180. Movie Maker fixed pacing is visual evidence only, not natural input, warning wall-clock, performance, balance, or complete Boss fight. No Main or stores instantiated."}
	for boss in [right, left, moving]:
		boss.cancel_boss_attacks()
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
	print("BOSS_ART_COMPLETE run=%s valid=%s" % [run_id, valid])
	quit(0 if valid else 1)
