extends SceneTree

const BossScript = preload("res://scripts/actors/OverseerBoss.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
var assertions := 0
var fixture: Node2D

func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: BossReadabilityTest: " + message)
	fixture.free()
	quit(1)
	return false

func _initialize() -> void:
	fixture = Node2D.new()
	root.add_child(fixture)
	var shots := Node2D.new()
	fixture.add_child(shots)
	var boss: Node = BossScript.new()
	boss.set_physics_process(false)
	boss.setup(6, shots)
	fixture.add_child(boss)
	await process_frame
	boss._physics_process(1.41) # Explicit component entrance, not natural-gameplay evidence.
	if not _check(boss.entrance_resolved and is_equal_approx(boss.modulate.a, 1.0), "fixture never reached an opaque post-entrance Boss"):
		return
	var collision: CircleShape2D
	for child in boss.get_children():
		if child is CollisionShape2D:
			collision = child.shape as CircleShape2D
	var initial_health: float = boss.health.current_health
	var events := [0, 0.0]
	boss.damage_resolved.connect(func(_actor: Node, _source: StringName, damage: float, _at: Vector2, _direction: Vector2, _killed: bool) -> void:
		events[0] += 1
		events[1] += damage
	)
	for frame in range(120):
		boss.take_damage(1.0, DamageTypes.LASER)
		var amount := float(boss.boss_flash_material.get_shader_parameter("flash_amount"))
		if not _check(amount > 0.0 and amount <= 0.4, "continuous hits erased the Boss palette: flash=%s frame=%d" % [amount, frame]):
			return
		boss._physics_process(1.0 / 60.0)
		if not _check(is_equal_approx(boss.modulate.a, 1.0) and is_equal_approx(boss.boss_visual.modulate.a, 1.0), "readability fix made the Boss translucent"):
			return
	if not _check(is_equal_approx(boss.health.current_health, initial_health - 120.0) and events[0] == 120 and is_equal_approx(events[1], 120.0), "visual feedback changed continuous damage or events"):
		return
	if not _check(collision != null and is_equal_approx(collision.radius, 56.0) and is_equal_approx(boss.body_radius, 56.0) and boss.get_phase() == 1, "visual feedback changed collision or health phase"):
		return
	boss._physics_process(0.081)
	if not _check(is_zero_approx(float(boss.boss_flash_material.get_shader_parameter("flash_amount"))), "flash failed to expire after the unchanged 80 ms duration"):
		return
	fixture.free()
	await process_frame
	print("TEST PASS: BossReadabilityTest %d" % assertions)
	quit(0)
