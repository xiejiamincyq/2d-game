extends SceneTree

const Enemy = preload("res://scripts/actors/Enemy.gd")
class Target extends Node2D:
	var hits := 0
	func take_damage(_amount: float) -> void:
		hits += 1
var assertions := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: EnemyCompactAttackTest " + label)

func _initialize() -> void:
	await process_frame
	var target := Target.new()
	root.add_child(target)
	var enemy := Enemy.new()
	enemy.setup(0, 0, root, target)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	check(is_equal_approx(enemy.attack_windup, 0.18), "ordinary windup remains long")
	check(is_equal_approx(enemy.attack_recovery, 0.20), "ordinary recovery remains long")
	check(enemy.has_method("should_show_attack_marker"), "missing head warning state")
	if enemy.has_method("should_show_attack_marker"):
		check(not enemy.should_show_attack_marker(), "idle marker visible")
		for move in range(2):
			enemy.basic_attack.cancel()
			target.position = Vector2(50, 0)
			enemy.basic_attack.begin(enemy, target, move)
			check(enemy.should_show_attack_marker(), "warning marker absent")
			enemy.basic_attack.advance(0.23 if move == 0 else 0.31)
			check(enemy.basic_attack.stage == enemy.basic_attack.Stage.ACTIVE, "compact warning not ended")
			check(not enemy.should_show_attack_marker(), "marker persists into damage phase")
			check(enemy.basic_attack.get_attack_strokes(enemy).size() <= 1, "ordinary attack still has three strokes")
			enemy.basic_attack.advance(0.31)
			check(enemy.basic_attack.stage == enemy.basic_attack.Stage.RECOVERY or not enemy.basic_attack.is_active(), "recovery not entered")
			check(not enemy.should_show_attack_marker(), "recovery marker visible")
			enemy.basic_attack.advance(0.21)
			check(not enemy.basic_attack.is_active(), "recovery still blocks pursuit")
			check(enemy.basic_attack.cooldown >= 4.47, "shorter action unintentionally increased special attack rate")
		enemy.basic_attack.cancel()
		enemy.basic_attack.cooldown = 0.0
		target.position = Vector2(155, 0)
		enemy.basic_attack.consider(enemy, target, 0.0)
		check(not enemy.basic_attack.is_active(), "pounce still starts beyond physical reach")
		enemy.is_attacking = true
		enemy.attack_timer = 0.10
		check(enemy.should_show_attack_marker(), "legacy close attack lacks marker")
		enemy.attack_timer = -0.01
		check(not enemy.should_show_attack_marker(), "close marker remains after hit")
		enemy.attack_timer = -0.20
		enemy._update_melee_attack(0.0, target, 100.0)
		check(is_equal_approx(enemy.attack_cooldown, 0.64), "ordinary cycle was buffed by recovery reduction")
	for kind in [3, 6]:
		var heavy := Enemy.new()
		heavy.setup(kind, 0, root, target)
		root.add_child(heavy)
		heavy.process_mode = Node.PROCESS_MODE_DISABLED
		check(is_equal_approx(heavy.attack_windup, 0.50 if kind == 3 else 0.32), "heavy warning changed")
		heavy.free()
	for hz in [30, 60, 120]:
		var chaser := Enemy.new()
		chaser.setup(0, 0, root, target)
		root.add_child(chaser)
		chaser.process_mode = Node.PROCESS_MODE_DISABLED
		target.position = Vector2(20, 0)
		target.hits = 0
		for tick in range(hz * 10):
			chaser._update_melee_attack(1.0 / hz, target, 20.0)
		check(target.hits == 10, "ordinary attacks increased over ten seconds at %dHz" % hz)
		chaser.free()
	enemy.is_attacking = false
	enemy.basic_attack.begin(enemy, target, 0)
	enemy.basic_attack.advance(0.35)
	await physics_frame
	var old_position := enemy.position
	enemy._physics_process(0.01)
	check(enemy.velocity.length() > 1.0 and enemy.position != old_position, "special recovery still freezes flock pursuit")
	var undecorated_target := Node2D.new()
	root.add_child(undecorated_target)
	undecorated_target.position = enemy.position + Vector2(50, 0)
	enemy.basic_attack.cancel()
	enemy.basic_attack.begin(enemy, undecorated_target, 0)
	enemy.basic_attack.advance(0.23)
	enemy.basic_attack.resolve_hit(enemy, undecorated_target)
	check(not enemy.basic_attack.did_hit, "non-damage target incorrectly consumed hit")
	undecorated_target.free()
	enemy.free()
	target.free()
	await process_frame
	print("TEST %s: EnemyCompactAttackTest %d" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(0 if failures == 0 else 1)
