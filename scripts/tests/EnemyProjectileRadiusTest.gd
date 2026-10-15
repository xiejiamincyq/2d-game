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
	var expected_spawn: Vector2 = enemy.native_visual.get_node("Facing/Skeleton2D/Torso/ArmR/ForearmR/HandR/NeedleGun/Muzzle").global_position if kind==EnemyScript.EnemyKind.MARKSMAN else enemy.global_position
	match kind:
		EnemyScript.EnemyKind.MARKSMAN:
			enemy._fire_marksman(target)
		EnemyScript.EnemyKind.SPITTER:
			enemy._update_spitter(0.0, target)
			enemy._update_spitter(enemy.ranged_windup_duration+0.01, target)
		EnemyScript.EnemyKind.OVERSEER:
			enemy._fire_overseer_burst()
			# The reviewed native burst now releases at its posed core, not the
			# collision root. Keep all real circle/parent-transform/velocity checks.
			expected_spawn = enemy.native_visual.get_node("Facing/Skeleton2D/Torso/Core/CommandOrigin").global_position
	var expected_count := 12 if kind == EnemyScript.EnemyKind.OVERSEER else 1
	if not check(shots.get_child_count() == expected_count, "actual launch count changed"):
		return false
	var radius := 3.0 if kind == EnemyScript.EnemyKind.MARKSMAN else 5.0
	var damage := 36.0 if kind == EnemyScript.EnemyKind.MARKSMAN else (21.0 if kind == EnemyScript.EnemyKind.SPITTER else 30.0)
	var speed := 910.0 if kind == EnemyScript.EnemyKind.MARKSMAN else (260.0 if kind == EnemyScript.EnemyKind.SPITTER else 310.0)
	var lifetime := 2.0 if kind == EnemyScript.EnemyKind.MARKSMAN else (6.0 if kind == EnemyScript.EnemyKind.SPITTER else 3.0)
	var shot_index := 0
	for shot in shots.get_children():
		shot.set_physics_process(false)
		var shape := shot.get_child(0) as CollisionShape2D
		if not check(shape != null and shape.shape is CircleShape2D and is_equal_approx(shape.shape.radius, radius) and shot.radius == radius,
			"kind %d declared radius %.1f but actual shape radius %.1f" % [kind, radius, shape.shape.radius]):
			return false
		if not check(shot.global_position.is_equal_approx(expected_spawn) and shot.target_group == &"player" and shot.damage == damage and is_equal_approx(shot.velocity.length(), speed),
			"kind %d transformed %s spawn %s vs %s, damage %.1f, speed %.1f" % [kind, transformed, shot.global_position, expected_spawn, shot.damage, shot.velocity.length()]):
			return false
		var direction := Vector2.RIGHT.rotated(TAU * shot_index / 12.0) if kind == EnemyScript.EnemyKind.OVERSEER else (target.global_position - expected_spawn).normalized()
		# Rotated projectile parents round-trip world origins through float32.
		# Bound absolute vector error, rather than a tiny y component's relative error.
		if not check(shot.velocity.distance_to(direction * speed)<0.001, "locked aim or 12-way burst direction changed: kind %d transformed %s actual %s expected %s" % [kind,transformed,shot.velocity,direction*speed]):
			return false
		if not check(shot.lifetime == lifetime and shot.world_bounds == enemy.world_bounds and shot.pierce == 0, "lifetime, world bounds or piercing changed"):
			return false
		shot_index += 1
	await physics_frame
	await physics_frame
	for shot in shots.get_children():
		# Layer-zero projectiles deliberately cannot be scene-query candidates.
		# Inspect the registered live shape RID/data, not just the resource field;
		# no collision property is changed to make this geometry probe pass.
		var registered := PhysicsServer2D.area_get_shape(shot.get_rid(),0)
		var collider := shot.get_child(0) as CollisionShape2D
		if not check(registered==collider.shape.get_rid() and PhysicsServer2D.shape_get_type(registered)==PhysicsServer2D.SHAPE_CIRCLE,
			"physics server registered a different shape than the actual projectile circle"):
			return false
		if not check(is_equal_approx(float(PhysicsServer2D.shape_get_data(registered)),radius),"physics server registered the wrong actual radius"):
			return false
		if not check(PhysicsServer2D.area_get_transform(shot.get_rid()).origin.distance_to(shot.global_position)<0.001,"physics server projectile transform differs from live world origin"):
			return false
		if not check(shot.collision_layer==0 and not point_hits(shot,0),"projectile leaked into scene/spawn queries"):
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
