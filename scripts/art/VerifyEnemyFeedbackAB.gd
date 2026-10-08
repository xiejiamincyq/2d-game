extends SceneTree

const Enemy = preload("res://scripts/actors/Enemy.gd")
const Boss = preload("res://scripts/actors/OverseerBoss.gd")
const Damage = preload("res://scripts/components/DamageTypes.gd")
var actors: Array[Node2D] = []
var output := ""
var canvas: SubViewport

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> bool:
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var bitmap := canvas.get_texture().get_image()
	return bitmap != null and not bitmap.is_empty() and bitmap.save_png(output + "/" + label + ".png") == OK

func run() -> void:
	var run_id := OS.get_environment("ENEMY_FEEDBACK_RUN_ID")
	output = "res://build/diagnostics/enemy-feedback-ab/" + run_id
	if DisplayServer.get_name() == "headless" or run_id.is_empty() or not run_id.is_valid_filename() or DirAccess.dir_exists_absolute(output):
		push_error("Native rendering and fresh run ID required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1280, 720)
	canvas.world_2d = World2D.new()
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var screen := TextureRect.new()
	screen.texture = canvas.get_texture()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	var background := ColorRect.new()
	background.color = Color("9bd7bd")
	background.size = Vector2(1280, 720)
	background.z_index = -100
	canvas.add_child(background)
	var valid := true
	for row in range(3):
		for kind in range(7):
			var enemy := Enemy.new()
			enemy.setup(kind, 0, canvas)
			canvas.add_child(enemy)
			enemy.position = Vector2(90 + kind * 150, 145 + row * 160)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			if row > 0:
				enemy.take_damage(1.0, Damage.PROJECTILE, Vector2.LEFT if row == 1 else Vector2.RIGHT)
				valid = valid and enemy.hit_feedback.life > 0.0
			actors.append(enemy)
	var boss := Boss.new()
	boss.setup(5, canvas)
	canvas.add_child(boss)
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	boss.position = Vector2(1120, 485)
	boss.entrance_resolved = true
	boss.scale = Vector2.ONE
	boss.rotation = 0.0
	boss.modulate.a = 1.0
	boss.take_damage(40, Damage.LASER, Vector2.LEFT)
	actors.append(boss)
	valid = await capture("hit-bright") and valid
	background.color = Color("9bd7bd").darkened(0.35)
	valid = await capture("hit-dark") and valid
	for actor in actors:
		actor.hit_feedback._process(0.20)
		valid = valid and is_zero_approx(actor.hit_feedback.life)
	valid = await capture("hit-expired") and valid
	var report := {"valid": valid, "scope": "1280x720 native Vulkan controlled real actor damage calls, not Main/normal-input gameplay or performance acceptance", "actors": actors.size(), "style": "A crisp lines plus B compact dark outlined core", "source_sha256": {}}
	for path in ["scripts/effects/EnemyHitFeedback.gd", "scripts/actors/Enemy.gd", "scripts/actors/OverseerBoss.gd"]:
		report.source_sha256[path] = FileAccess.get_sha256("res://" + path)
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	canvas.free()
	screen.free()
	await process_frame
	print("ENEMY_FEEDBACK_AB_COMPLETE valid=%s" % valid)
	quit(0 if valid else 1)
