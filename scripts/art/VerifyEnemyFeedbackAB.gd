extends SceneTree

const Enemy = preload("res://scripts/actors/Enemy.gd")
const Boss = preload("res://scripts/actors/OverseerBoss.gd")
const Damage = preload("res://scripts/components/DamageTypes.gd")
const Projectile = preload("res://scripts/components/Projectile.gd")
const BossShot = preload("res://scripts/components/BossProjectile.gd")
const Lob = preload("res://scripts/components/LobbedProjectile.gd")
const Player = preload("res://scripts/actors/Player.gd")
var actors: Array[Node2D] = []
var captures := {}
var output := ""
var canvas: SubViewport

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> bool:
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var bitmap := canvas.get_texture().get_image()
	var path := output + "/" + label + ".png"
	var ok := bitmap != null and not bitmap.is_empty() and bitmap.save_png(path) == OK
	captures[label] = {"ok": ok, "sha256": FileAccess.get_sha256(path), "viewport": [1280, 720]}
	return ok

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
	for actor in actors:
		actor.free()
	actors.clear()
	var attacks := await render_attacks()
	valid = valid and attacks.valid
	var report := {"valid": valid, "scope": "1280x720 native Vulkan controlled real actor damage and manually advanced locked attacks; not Main/normal-input gameplay or performance acceptance", "hit_actors": 22, "captures": captures, "attacks": attacks, "style": "A crisp lines plus B compact dark outlined core", "source_sha256": {}}
	for path in ["scripts/effects/EnemyHitFeedback.gd", "scripts/effects/HostileAttackDrawing.gd", "scripts/actors/Enemy.gd", "scripts/actors/OverseerBoss.gd", "scripts/components/ScrapperAttack.gd", "scripts/components/Projectile.gd", "scripts/components/BossProjectile.gd", "scripts/components/LobbedProjectile.gd", "scripts/components/TentacleAttack.gd"]:
		report.source_sha256[path] = FileAccess.get_sha256("res://" + path)
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	canvas.free()
	screen.free()
	await process_frame
	print("ENEMY_FEEDBACK_AB_COMPLETE valid=%s" % valid)
	quit(0 if valid else 1)

func render_attacks() -> Dictionary:
	var target := Node2D.new()
	canvas.add_child(target)
	var claw := Enemy.new()
	claw.setup(0, 0, canvas, target)
	canvas.add_child(claw)
	claw.process_mode = Node.PROCESS_MODE_DISABLED
	claw.position = Vector2(180, 140)
	target.position = claw.position + Vector2(55, 0)
	claw.basic_attack.begin(claw, target, 0)
	var pounce := Enemy.new()
	pounce.setup(0, 0, canvas, target)
	canvas.add_child(pounce)
	pounce.process_mode = Node.PROCESS_MODE_DISABLED
	pounce.position = Vector2(180, 300)
	target.position = pounce.position + Vector2(100, 0)
	pounce.basic_attack.begin(pounce, target, 1)
	var heavy := Enemy.new()
	heavy.setup(3, 0, canvas, target)
	canvas.add_child(heavy)
	heavy.position = Vector2(560, 140)
	heavy.process_mode = Node.PROCESS_MODE_DISABLED
	var boss := Boss.new()
	boss.setup(5, canvas, target)
	canvas.add_child(boss)
	boss.position = Vector2(1090, 230)
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	boss.entrance_resolved = true
	boss.scale = Vector2.ONE
	boss.rotation = 0.0
	boss.modulate.a = 1.0
	boss.start_tentacle_sweep(Vector2(840, 320))
	for index in range(4):
		var shot: Area2D = BossShot.new() if index == 3 else Projectile.new()
		shot.target_group = &"player"
		shot.radius = 5
		shot.tint = Color("f27a4b")
		shot.velocity = Vector2.RIGHT.rotated(index * PI * 0.5) * 260
		canvas.add_child(shot)
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		shot.position = Vector2(200 + index * 130, 520)
	var lob := Lob.new()
	canvas.add_child(lob)
	lob.process_mode = Node.PROCESS_MODE_DISABLED
	lob.configure(Vector2(760, 510), Vector2(915, 510), target)
	var valid := true
	var active_claw := 0
	var active_pounce := 0
	var active_boss := 0
	for frame in range(90):
		claw.basic_attack.advance(1.0 / 60.0)
		pounce.basic_attack.advance(1.0 / 60.0)
		pounce.position += pounce.basic_attack.get_velocity() / 60.0
		claw._queue_visual_redraw()
		pounce._queue_visual_redraw()
		target.position = heavy.position + Vector2(18, 0)
		heavy._update_melee_attack(1.0 / 60.0, target, 18.0)
		heavy._queue_visual_redraw()
		boss.advance_tentacle_attack(1.0 / 60.0)
		if is_instance_valid(lob) and not lob.is_queued_for_deletion():
			lob._physics_process(1.0 / 60.0)
		active_claw += int(not claw.basic_attack.get_attack_strokes(claw).is_empty())
		active_pounce += int(not pounce.basic_attack.get_attack_strokes(pounce).is_empty())
		active_boss += int(boss.tentacle_attack.attack_stage == boss.tentacle_attack.AttackStage.ACTIVE)
		if frame % 2 == 0:
			valid = await capture("attack-frame-%03d" % (frame / 2)) and valid
		if frame in [28, 33, 40, 51, 63, 89]:
			valid = await capture("attack-state-%02d" % frame) and valid
	# Dense acceptance sample: real small actors and simultaneous accepted damage.
	var player := Player.new()
	canvas.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector2(575, 400)
	for row in range(4):
		for column in range(12):
			var enemy := Enemy.new()
			enemy.setup(column % 6, 0, canvas)
			canvas.add_child(enemy)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.position = Vector2(120 + column * 80, 90 + row * 125)
			enemy.take_damage(1, Damage.LASER, Vector2.RIGHT)
			if column == 0:
				target.position = enemy.position + Vector2(50, 0)
				enemy.basic_attack.begin(enemy, target, 0)
				enemy.basic_attack.advance(0.56)
				enemy._queue_visual_redraw()
	valid = await capture("dense-hits") and valid
	return {"valid": valid and active_claw > 0 and active_pounce > 0 and active_boss > 0, "controlled_steps": 90, "active_claw_steps": active_claw, "active_pounce_steps": active_pounce, "active_boss_steps": active_boss, "animation_frames": 45, "dense_actors": 48}
