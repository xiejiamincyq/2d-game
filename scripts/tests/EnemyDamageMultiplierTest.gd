extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const BossScript = preload("res://scripts/actors/OverseerBoss.gd")
const PatternScript = preload("res://scripts/components/BossProjectilePattern.gd")
const LobScript = preload("res://scripts/components/LobbedProjectile.gd")
var assertions := 0
var failures := 0
var fixture: Node2D
var shots: Node2D
var player: Node

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAIL: EnemyDamageMultiplierTest: " + message)

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	fixture = Node2D.new()
	root.add_child(fixture)
	shots = Node2D.new()
	fixture.add_child(shots)
	player = PlayerScript.new()
	fixture.add_child(player)
	player.set_physics_process(false)
	player.health.set_process(false)
	await process_frame
	for kind in range(7):
		await test_enemy(kind)
	await test_boss()
	var default_lob := LobScript.new()
	shots.add_child(default_lob)
	default_lob.set_physics_process(false)
	default_lob.configure(Vector2(-100, 0), player.global_position, player)
	reset_health()
	default_lob._explode()
	check_damage(42.0, "default hostile lob impact")
	await process_frame
	# The multiplier belongs to hostile emitters, never the shared damage receiver.
	reset_health()
	player.take_damage(7.0)
	check_damage(7.0, "generic receiver amount must not be tripled")
	var friendly_enemy := EnemyScript.new()
	friendly_enemy.setup(EnemyScript.EnemyKind.SCRAPPER, 0, shots)
	friendly_enemy.position = Vector2(-500, -200)
	fixture.add_child(friendly_enemy)
	friendly_enemy.set_physics_process(false)
	var before: float = friendly_enemy.health.current_health
	var captured: Array[Node] = []
	player.fired.connect(func(shot: Node) -> void:
		shots.add_child(shot)
		shot.set_physics_process(false)
		captured.append(shot)
	)
	player._spawn_bullet(Vector2.RIGHT)
	captured[0]._try_hit(friendly_enemy)
	check(is_equal_approx(before - friendly_enemy.health.current_health, player.weapon_damage), "friendly bullet damage changed")
	fixture.queue_free()
	await process_frame
	if failures == 0:
		print("TEST PASS: EnemyDamageMultiplierTest %d" % assertions)
	else:
		print("ENEMY_DAMAGE_RED: assertions=%d failures=%d" % [assertions, failures])
	quit(0 if failures == 0 else 1)

func reset_health() -> void:
	player.health.max_health = 1000.0
	player.health.current_health = 1000.0
	player.health.invulnerable_time = 0.0
	player.shield = 0.0
	player.set_overdrive_active(false)
	player.set_dash_immunity_active(false)

func check_damage(expected: float, label: String) -> void:
	var actual: float = 1000.0 - player.health.current_health
	print("HOSTILE_DAMAGE: %s actual=%.3f expected=%.3f" % [label, actual, expected])
	check(is_equal_approx(actual, expected), "%s dealt %.3f instead of %.3f" % [label, actual, expected])

func test_enemy(kind: int) -> void:
	var base_damage: Array[float] = [8, 6, 5, 18, 5, 8, 24]
	var enemy := EnemyScript.new()
	enemy.setup(kind, 2, shots, player)
	fixture.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position = Vector2(100, 0)
	player.position = Vector2(110, 0)
	reset_health()
	enemy.attack_cooldown = 0.0
	enemy._update_melee_attack(0.0, player, 10.0)
	enemy._update_melee_attack(enemy.attack_windup + 0.01, player, 10.0)
	check_damage(base_damage[kind] * 3.0, "kind %d melee" % kind)
	reset_health()
	enemy._update_melee_attack(0.01, player, 10.0)
	check_damage(0.0, "kind %d attack remains once-only" % kind)
	if kind in [EnemyScript.EnemyKind.SPITTER, EnemyScript.EnemyKind.MARKSMAN, EnemyScript.EnemyKind.LOBBER, EnemyScript.EnemyKind.OVERSEER]:
		var safe: Rect2 = enemy.get_camera_safe_rect()
		player.global_position = enemy.global_position + Vector2.RIGHT * ((enemy.get_dynamic_ranged_min_distance(safe) + enemy.get_dynamic_ranged_max_distance(safe)) * 0.5)
		enemy.ranged_target_position = player.global_position
		enemy.shoot_cooldown = 0.0
		var before := shots.get_child_count()
		var expected := 0.0
		match kind:
			EnemyScript.EnemyKind.SPITTER:
				enemy._update_spitter(0.0, player)
				enemy._update_spitter(0.19, player)
				expected = 21.0
			EnemyScript.EnemyKind.MARKSMAN:
				enemy._fire_marksman(player)
				expected = 36.0
			EnemyScript.EnemyKind.LOBBER:
				enemy._fire_lobber(player)
				expected = 48.0
			EnemyScript.EnemyKind.OVERSEER:
				enemy._fire_overseer_burst()
				expected = 30.0
		var count := shots.get_child_count() - before
		check(count == (12 if kind == EnemyScript.EnemyKind.OVERSEER else 1), "kind %d launch count=%d" % [kind, count])
		for index in range(before, shots.get_child_count()):
			var shot := shots.get_child(index)
			shot.set_physics_process(false)
			reset_health()
			if kind == EnemyScript.EnemyKind.LOBBER:
				shot._explode()
			else:
				shot._try_hit(player)
			check_damage(expected, "kind %d emitted attack %d" % [kind, index - before])
	enemy.queue_free()
	await process_frame

func test_boss() -> void:
	player.global_position = Vector2(240, 0)
	var boss := BossScript.new()
	fixture.add_child(boss)
	boss.world_bounds = Rect2(-1000, -1000, 2000, 2000)
	boss.setup(1, shots, player)
	boss.set_physics_process(false)
	var attack: Node = boss.get_tentacle_attack()
	reset_health()
	check(boss.start_tentacle_sweep(player.global_position), "boss rejected sweep")
	attack.set_physics_process(false)
	attack.advance_attack(0.99)
	check_damage(0.0, "boss sweep warning remains harmless")
	attack.advance_attack(0.02)
	check_damage(54.0, "boss active sweep")
	reset_health()
	attack.advance_attack(0.05)
	check_damage(0.0, "boss sweep remains once-only")
	attack.advance_attack(0.3)
	var points: Array[Vector2] = attack.make_slam_targets(player.global_position, 2)
	player.global_position = points[0]
	reset_health()
	var before := shots.get_child_count()
	check(boss.start_tentacle_slam(points), "boss rejected slam")
	attack.set_physics_process(false)
	attack.advance_attack(1.09)
	check_damage(0.0, "slam warning remains harmless")
	attack.advance_attack(0.02)
	check_damage(60.0, "boss slam impact")
	check(shots.get_child_count() - before == 12, "slam projectile count changed")
	for index in range(before, shots.get_child_count()):
		var shot := shots.get_child(index)
		shot.set_physics_process(false)
		reset_health()
		shot._try_hit(player)
		check_damage(18.0, "boss slam fragment %d" % [index - before])
	await process_frame
	var pattern := PatternScript.new()
	fixture.add_child(pattern)
	pattern.set_process(false)
	pattern.configure(shots, boss.world_bounds, player, boss.get_instance_id(), 93)
	before = shots.get_child_count()
	check(pattern.start_pattern(PatternScript.AIMED_FAN), "boss rejected aimed fan")
	pattern.advance(0.45)
	check(shots.get_child_count() > before, "boss fan emitted no projectiles")
	for index in range(before, shots.get_child_count()):
		var shot := shots.get_child(index)
		shot.set_physics_process(false)
		reset_health()
		shot._try_hit(player)
		check_damage(27.0, "boss fan projectile %d" % [index - before])
	await process_frame
