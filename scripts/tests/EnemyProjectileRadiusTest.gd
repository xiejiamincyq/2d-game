extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
var assertions := 0

func check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: EnemyProjectileRadiusTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	for transformed in [false, true]:
		for kind in [EnemyScript.EnemyKind.MARKSMAN, EnemyScript.EnemyKind.SPITTER, EnemyScript.EnemyKind.OVERSEER]:
			if not await test_launch(kind, transformed):
				return
	print("TEST PASS: EnemyProjectileRadiusTest %d" % assertions)
	quit(0)

func test_launch(kind: int, transformed: bool) -> bool:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var shots := Node2D.new()
	if transformed:
		shots.position = Vector2(100, 70)
		shots.rotation = 0.4
	fixture.add_child(shots)
	var target := Node2D.new()
	target.position = Vector2(500, 200)
	fixture.add_child(target)
	var enemy := EnemyScript.new()
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.setup(kind, 2, shots, target)
	enemy.position = Vector2(230, 180)
	enemy.world_bounds = Rect2(-1000, -1000, 3000, 3000)
	fixture.add_child(enemy)
	await process_frame
	var safe_rect := enemy.get_camera_safe_rect()
	var distance := (enemy.get_dynamic_ranged_min_distance(safe_rect) + enemy.get_dynamic_ranged_max_distance(safe_rect)) * 0.5
	target.global_position = enemy.global_position + Vector2.RIGHT * distance
	if not check(enemy._is_in_visible_engagement_zone(target), "fixture is outside actual ranged engagement zone"):
		return false
	enemy.ranged_target_position = target.global_position
	enemy.shoot_cooldown = 0.0
	match kind:
		EnemyScript.EnemyKind.MARKSMAN:
			enemy._fire_marksman(target)
		EnemyScript.EnemyKind.SPITTER:
			enemy._update_spitter(0.0, target)
		EnemyScript.EnemyKind.OVERSEER:
			enemy._fire_overseer_burst()
	var expected_count := 12 if kind == EnemyScript.EnemyKind.OVERSEER else 1
	if not check(shots.get_child_count() == expected_count, "actual launch count changed"):
		return false
	var radius := 3.0 if kind == EnemyScript.EnemyKind.MARKSMAN else 5.0
	var damage := 12.0 if kind == EnemyScript.EnemyKind.MARKSMAN else (7.0 if kind == EnemyScript.EnemyKind.SPITTER else 10.0)
	var speed := 910.0 if kind == EnemyScript.EnemyKind.MARKSMAN else (260.0 if kind == EnemyScript.EnemyKind.SPITTER else 310.0)
	var lifetime := 2.0 if kind == EnemyScript.EnemyKind.MARKSMAN else (6.0 if kind == EnemyScript.EnemyKind.SPITTER else 3.0)
	var shot_index := 0
	for shot in shots.get_children():
		shot.set_physics_process(false)
		var shape := shot.get_child(0) as CollisionShape2D
		if not check(shape != null and shape.shape is CircleShape2D and is_equal_approx(shape.shape.radius, radius) and shot.radius == radius,
			"kind %d declared radius %.1f but actual shape radius %.1f" % [kind, radius, shape.shape.radius]):
			return false
		if not check(shot.global_position.is_equal_approx(enemy.global_position) and shot.target_group == &"player" and shot.damage == damage and is_equal_approx(shot.velocity.length(), speed),
			"kind %d transformed %s spawn %s vs %s, damage %.1f, speed %.1f" % [kind, transformed, shot.global_position, enemy.global_position, shot.damage, shot.velocity.length()]):
			return false
		var direction := Vector2.RIGHT.rotated(TAU * shot_index / 12.0) if kind == EnemyScript.EnemyKind.OVERSEER else (target.global_position - enemy.global_position).normalized()
		if not check(shot.velocity.is_equal_approx(direction * speed), "locked aim or 12-way burst direction changed"):
			return false
		if not check(shot.lifetime == lifetime and shot.world_bounds == enemy.world_bounds and shot.pierce == 0, "lifetime, world bounds or piercing changed"):
			return false
		shot_index += 1
	await physics_frame
	await physics_frame
	for shot in shots.get_children():
		if not check(point_hits(shot, radius - 0.1), "physics server missed point inside configured circle"):
			return false
		if not check(not point_hits(shot, radius + 0.1), "physics server hit point outside configured circle"):
			return false
	fixture.queue_free()
	await process_frame
	return true

func point_hits(shot: Area2D, offset: float) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = shot.global_position + Vector2(offset, 0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in shot.get_world_2d().direct_space_state.intersect_point(query, 32):
		if hit.collider == shot:
			return true
	return false
