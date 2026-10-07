extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
class Target extends Node2D:
	var hits: Array[float] = []
	var stealthed := false
	func take_damage(amount: float) -> bool:
		hits.append(amount)
		return true
	func is_stealthed() -> bool:
		return stealthed
var failures := 0
var assertions := 0
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: ScrapperAttackTest " + label)
func _initialize() -> void:
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	arena.add_child(target)
	var enemy := EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.SCRAPPER, 0, arena, target)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	var attack = enemy.get("basic_attack")
	check(attack != null, "basic chaser has no diverse attack controller")
	if attack != null:
		target.position = Vector2(50, 0)
		check(attack.begin(enemy, target, 0), "claw did not start")
		var heading: Vector2 = attack.direction
		attack.advance(0.49)
		attack.resolve_hit(enemy, target)
		check(target.hits.is_empty(), "warning dealt damage")
		attack.advance(0.02)
		attack.resolve_hit(enemy, target)
		attack.resolve_hit(enemy, target)
		check(target.hits == [24.0], "claw must hit once with current base damage")
		attack.cancel()
		target.hits.clear()
		check(attack.begin(enemy, target, 0), "displacement claw rejected")
		enemy.position = Vector2(20, 0)
		target.position = Vector2(75, 0)
		attack.advance(0.51)
		attack.resolve_hit(enemy, target)
		check(target.hits.is_empty(), "displaced actor damaged outside locked claw warning")
		attack.cancel()
		enemy.position = Vector2.ZERO
		target.position = Vector2(50, 0)
		check(attack.begin(enemy, target, 0), "second claw rejected")
		target.position = Vector2(0, 50)
		attack.advance(0.51)
		attack.resolve_hit(enemy, target)
		check(target.hits.is_empty() and attack.direction == heading, "claw tracked dodging player")
		attack.cancel()
		target.position = Vector2(110, 0)
		check(attack.begin(enemy, target, 1), "pounce did not start")
		attack.advance(0.59)
		check(attack.get_velocity() == Vector2.ZERO, "pounce moved during warning")
		attack.advance(0.02)
		check(attack.get_velocity().is_equal_approx(Vector2(330, 0)), "pounce speed/direction wrong")
		target.position = Vector2(0, 110)
		check(attack.direction == heading, "pounce homed after locking")
		var wall := StaticBody2D.new()
		wall.position = Vector2(45, 0)
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(12, 160)
		shape.shape = rectangle
		wall.add_child(shape)
		arena.add_child(wall)
		for frame in range(18):
			await physics_frame
			enemy._physics_process(1.0 / 60.0)
		check(enemy.position.x <= 25.1, "pounce penetrated physical wall")
		check(target.hits.is_empty(), "pounce hit player outside actual collision reach")
		attack.cancel()
		check(not attack.is_active() and attack.get_velocity() == Vector2.ZERO, "cancel left an active strike")
		target.position = enemy.position + Vector2(50, 0)
		attack.cooldown = 0.0
		enemy.is_attacking = true
		enemy._physics_process(0.01)
		check(not attack.is_active(), "new strike stacked with old melee")
		enemy.is_attacking = false
		attack.cooldown = 0.0
		enemy.spawn_impulse_remaining = 0.3
		enemy._physics_process(0.01)
		check(not attack.is_active(), "birth impulse started strike")
		enemy.spawn_impulse_remaining = 0.0
		attack.begin(enemy, target, 0)
		target.stealthed = true
		enemy._physics_process(0.01)
		check(not attack.is_active(), "hidden target did not cancel warning")
		check(attack.cooldown >= 3.9, "cancel did not enforce attack cooldown")
	arena.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("TEST PASS: ScrapperAttackTest %d" % assertions)
	quit(0 if failures == 0 else 1)
