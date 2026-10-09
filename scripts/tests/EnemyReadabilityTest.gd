extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
var assertions := 0
var fixture: Node2D

func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: EnemyReadabilityTest: " + message)
	fixture.free()
	quit(1)
	return false

func _initialize() -> void:
	fixture = Node2D.new()
	root.add_child(fixture)
	var target := Node2D.new()
	target.position = Vector2(10000, 10000)
	fixture.add_child(target)
	for kind in EnemyScript.EnemyKind.values():
		var enemy: CharacterBody2D = EnemyScript.new()
		enemy.set_physics_process(false)
		enemy.setup(kind, 6, fixture, target)
		fixture.add_child(enemy)
		await process_frame
		var initial_health: float = enemy.health.current_health
		var initial_speed: float = enemy.speed
		var initial_damage: float = enemy.contact_damage
		var initial_radius: float = enemy.body_radius
		var collision: CircleShape2D
		for child in enemy.get_children():
			if child is CollisionShape2D:
				collision = child.shape as CircleShape2D
		var events := [0, 0.0, 0, 0]
		enemy.damage_resolved.connect(func(_actor: Node, source: StringName, damage: float, _at: Vector2, _direction: Vector2, killed: bool) -> void:
			events[0] += 1
			events[1] += damage
			if source == DamageTypes.LASER:
				events[2] += 1
			if killed:
				events[3] += 1
		)
		for frame in range(120):
			enemy.take_damage(0.1, DamageTypes.LASER)
			var amount := float(enemy.static_flash_material.get_shader_parameter("flash_amount"))
			if not _check(is_equal_approx(amount, 0.35), "continuous hits erased palette or lost feedback: kind=%d frame=%d flash=%s" % [kind, frame, amount]):
				return
			if not _check(is_equal_approx(enemy.flash_timer, 0.08), "accepted hit changed the 80 ms timer"):
				return
			enemy._physics_process(1.0 / 60.0)
			var visual: Node2D = enemy.native_visual if enemy.native_visual != null else enemy.static_visual
			if not _check(is_equal_approx(enemy.modulate.a, 1.0) and is_equal_approx(visual.modulate.a, 1.0), "feedback made actor translucent"):
				return
		if not _check(is_equal_approx(enemy.health.current_health, initial_health - 12.0) and events[0] == 120 and events[2] == 120 and is_equal_approx(events[1], 12.0), "feedback changed continuous damage or events"):
			return
		if not _check(collision != null and is_equal_approx(collision.radius, initial_radius) and is_equal_approx(enemy.body_radius, initial_radius) and is_equal_approx(enemy.speed, initial_speed) and is_equal_approx(enemy.contact_damage, initial_damage), "feedback changed combat geometry or balance"):
			return
		enemy.take_damage(0.1, DamageTypes.LASER)
		enemy._physics_process(0.079)
		if not _check(is_equal_approx(float(enemy.static_flash_material.get_shader_parameter("flash_amount")), 0.35), "flash expired before 80 ms"):
			return
		enemy._physics_process(0.0011)
		if not _check(is_zero_approx(float(enemy.static_flash_material.get_shader_parameter("flash_amount"))), "flash failed to expire after 80 ms"):
			return
		var accepted_events: int = events[0]
		enemy.take_damage(0.0, DamageTypes.LASER)
		enemy.health.begin_invulnerability(1.0)
		enemy.take_damage(1.0, DamageTypes.LASER)
		if not _check(events[0] == accepted_events and is_zero_approx(enemy.flash_timer) and is_zero_approx(float(enemy.static_flash_material.get_shader_parameter("flash_amount"))), "rejected damage restarted flash or emitted resolved damage"):
			return
		enemy.health.invulnerable_time = 0.0
		var deaths := [0]
		enemy.died.connect(func(_actor: Node, _coins: int, _source: StringName) -> void: deaths[0] += 1)
		if not _check(enemy.take_damage(enemy.health.current_health, DamageTypes.LASER) and enemy.death_resolved and deaths[0] == 1 and events[3] == 1, "feedback broke lethal damage"):
			return
		enemy.take_damage(1.0, DamageTypes.LASER)
		if not _check(deaths[0] == 1 and events[3] == 1, "death feedback resolved twice"):
			return
		await process_frame
		if not _check(not is_instance_valid(enemy), "dead actor was not freed"):
			return
	fixture.free()
	await process_frame
	print("TEST PASS: EnemyReadabilityTest %d" % assertions)
	quit(0)
