extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const ProjectileScript = preload("res://scripts/components/Projectile.gd")
var assertions := 0

func check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: HostileEffectPaletteTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	for kind in [EnemyScript.EnemyKind.MARKSMAN, EnemyScript.EnemyKind.SPITTER, EnemyScript.EnemyKind.OVERSEER]:
		if not await test_launch(kind):
			return
	var friendly := ProjectileScript.new()
	var unchanged := friendly.tint == Color.CYAN and friendly.target_group == &"enemies" and friendly.radius == 4.0
	friendly.free()
	if not check(unchanged, "shared friendly defaults changed"):
		return
	print("TEST PASS: HostileEffectPaletteTest %d" % assertions)
	quit(0)

func test_launch(kind: int) -> bool:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var shots := Node2D.new()
	shots.process_mode = Node.PROCESS_MODE_DISABLED
	fixture.add_child(shots)
	var target := Node2D.new()
	fixture.add_child(target)
	var enemy := EnemyScript.new()
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.setup(kind, 2, shots, target)
	enemy.position = Vector2(230, 180)
	fixture.add_child(enemy)
	var safe_rect := enemy.get_camera_safe_rect()
	target.position = enemy.position + Vector2.RIGHT * (enemy.get_dynamic_ranged_min_distance(safe_rect) + enemy.get_dynamic_ranged_max_distance(safe_rect)) * 0.5
	enemy.ranged_target_position = target.position
	enemy.shoot_cooldown = 0.0
	match kind:
		EnemyScript.EnemyKind.MARKSMAN:
			enemy._fire_marksman(target)
		EnemyScript.EnemyKind.SPITTER:
			enemy._update_spitter(0.0, target)
			enemy._update_spitter(0.19, target)
		EnemyScript.EnemyKind.OVERSEER:
			enemy._fire_overseer_burst()
	if not check(shots.get_child_count() == (12 if kind == EnemyScript.EnemyKind.OVERSEER else 1), "actual producer failed to launch"):
		return false
	for shot in shots.get_children():
		var expected := Color("82cf45") if kind == EnemyScript.EnemyKind.SPITTER else Color("f27a4b")
		if not check(shot.tint.is_equal_approx(expected), "kind %d still uses legacy hostile tint %s" % [kind, shot.tint]):
			return false
		if not check(shot.target_group == &"player" and not shot.overdrive_visual, "hostile ownership/overdrive contract changed"):
			return false
	fixture.queue_free()
	await process_frame
	return true
