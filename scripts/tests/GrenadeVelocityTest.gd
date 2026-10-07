extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
var assertions := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAIL: GrenadeVelocityTest: " + message)

func _initialize() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var player := PlayerScript.new()
	fixture.add_child(player)
	player.set_physics_process(false)
	await process_frame
	var shots: Array[Node] = []
	player.fired.connect(func(shot: Node) -> void:
		fixture.add_child(shot)
		shot.set_physics_process(false)
		shots.append(shot)
	)
	player.activate_build_evolution("orbital_storm")
	var motions: Array[Vector2] = [Vector2.ZERO, Vector2(235, 0), Vector2(-235, 0), Vector2(0, 235), Vector2(100, -50), Vector2(1031.25, 0)]
	for base_speed in [620.0, 900.0]:
		player.projectile_speed = base_speed
		for motion in motions:
			for aim in [Vector2.RIGHT, Vector2(-1, 1).normalized()]:
				player.velocity = motion
				player._spawn_bullet(aim)
				var shot: Node = shots[-1]
				var expected: Vector2 = motion * 0.30 + aim * base_speed * 0.48
				check(shot.velocity.is_equal_approx(expected), "launch %s aim %s base %.1f: %s expected %s" % [motion, aim, base_speed, shot.velocity, expected])
				check(is_equal_approx(shot.damage, player.weapon_damage * 3.0), "damage changed")
				shot.enemy_provider = func() -> Array: return []
				var start: Vector2 = shot.global_position
				shot._physics_process(0.05)
				check(shot.global_position.is_equal_approx(start + expected * 0.05), "actual grenade displacement did not follow launch velocity")
				shot.queue_free()
	player.active_build_evolutions.erase("orbital_storm")
	player.projectile_speed = 620.0
	player.velocity = Vector2(100, 50)
	player._spawn_bullet(Vector2.RIGHT)
	check(shots[-1].velocity.is_equal_approx(Vector2(720, 50)), "ordinary bullet inheritance changed")
	fixture.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("TEST PASS: GrenadeVelocityTest %d" % assertions)
	quit(0 if failures == 0 else 1)
