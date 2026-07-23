extends SceneTree

const OverseerBossScript = preload("res://scripts/actors/OverseerBoss.gd")
const TentacleAttackScript = preload("res://scripts/components/TentacleAttack.gd")

class DamageTarget:
	extends CharacterBody2D
	var damage_events: Array[float] = []

	func _ready() -> void:
		add_to_group(&"player")

	func take_damage(amount: float, _source: StringName = &"generic") -> bool:
		damage_events.append(amount)
		return true

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: BossTentacleTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var projectiles := Node2D.new()
	fixture.add_child(projectiles)
	var player := DamageTarget.new()
	fixture.add_child(player)
	player.global_position = Vector2(240.0, 0.0)

	var boss: Node2D = OverseerBossScript.new()
	fixture.add_child(boss)
	boss.global_position = Vector2.ZERO
	boss.setup(1, projectiles, player)
	await process_frame
	boss.set_physics_process(false)
	var attack: Node = boss.get_tentacle_attack()
	attack.set_physics_process(false)

	if not _assert_true(attack != null, "OverseerBoss did not expose its TentacleAttack component"):
		return
	if not _assert_true(
		is_equal_approx(attack.SWEEP_WARNING_SECONDS, 0.65)
		and is_equal_approx(attack.SWEEP_RANGE, 300.0)
		and is_equal_approx(attack.SWEEP_ARC_DEGREES, 78.0)
		and is_equal_approx(attack.SWEEP_DAMAGE, 18.0),
		"sweep combat constants did not match the contract"
	):
		return
	if not _assert_true(boss.start_tentacle_sweep(player.global_position), "Boss rejected a valid sweep start"):
		return
	attack.advance_attack(0.64)
	if not _assert_true(player.damage_events.is_empty(), "sweep damaged during its warning"):
		return
	if not _assert_true(attack.is_point_in_sweep(player.global_position), "sweep warning geometry excluded a visibly warned point"):
		return
	player.global_position = Vector2(0.0, 240.0)
	attack.advance_attack(0.02)
	attack.advance_attack(attack.SWEEP_ACTIVE_SECONDS)
	if not _assert_true(player.damage_events.is_empty(), "player could not evade by leaving the warned sweep sector"):
		return

	player.global_position = Vector2(240.0, 0.0)
	boss.start_tentacle_sweep(player.global_position)
	attack.advance_attack(attack.SWEEP_WARNING_SECONDS + 0.01)
	attack.advance_attack(0.08)
	if not _assert_true(player.damage_events == [18.0], "sweep did not hit once for 18 damage"):
		return
	attack.advance_attack(attack.SWEEP_ACTIVE_SECONDS)
	if not _assert_true(player.damage_events == [18.0], "one sweep hit the player more than once"):
		return

	player.damage_events.clear()
	var locked_targets: Array[Vector2] = attack.make_slam_targets(Vector2(210.0, 30.0), 3)
	if not _assert_true(locked_targets.size() == 3, "slam did not lock three target points"):
		return
	for first in range(locked_targets.size()):
		for second in range(first + 1, locked_targets.size()):
			if not _assert_true(
				locked_targets[first].distance_to(locked_targets[second]) >= 160.0,
				"slam markers left less than a 70px edge-to-edge channel"
			):
				return
	player.global_position = locked_targets[1]
	if not _assert_true(boss.start_tentacle_slam(locked_targets), "Boss rejected valid slam targets"):
		return
	var warning_targets: Array[Vector2] = attack.get_slam_targets()
	attack.advance_attack(0.74)
	if not _assert_true(player.damage_events.is_empty() and projectiles.get_child_count() == 0, "slam damaged or spawned projectiles during warning"):
		return
	player.global_position += Vector2(300.0, 0.0)
	if not _assert_true(attack.get_slam_targets() == warning_targets, "slam targets tracked the player after lock-on"):
		return
	attack.advance_attack(0.02)
	if not _assert_true(player.damage_events.is_empty(), "player could not evade a locked slam marker"):
		return
	if not _assert_true(projectiles.get_child_count() == 18, "three slam markers did not emit exactly six projectiles each"):
		return
	for shot in projectiles.get_children():
		if not _assert_true(
			shot.is_in_group(attack.get_projectile_group())
			and int(shot.get_meta(&"boss_owner_id", 0)) == boss.get_instance_id(),
			"slam projectile was missing Boss ownership cleanup metadata"
		):
			return

	player.global_position = locked_targets[1]
	var slam_hit_targets: Array[Vector2] = attack.make_slam_targets(player.global_position, 2)
	player.global_position = slam_hit_targets[0]
	boss.start_tentacle_slam(slam_hit_targets)
	attack.advance_attack(attack.SLAM_WARNING_SECONDS)
	if not _assert_true(player.damage_events == [20.0], "slam did not hit a marked point for 20 damage"):
		return
	if not _assert_true(projectiles.get_child_count() == 30, "two slam markers did not add exactly twelve projectiles"):
		return

	var cancel_targets: Array[Vector2] = attack.make_slam_targets(Vector2(100.0, 100.0), 2)
	boss.start_tentacle_slam(cancel_targets)
	boss.cancel_tentacle_attack()
	attack.advance_attack(attack.SLAM_WARNING_SECONDS + 0.1)
	await process_frame
	if not _assert_true(projectiles.get_child_count() == 0 and not attack.is_attacking(), "cancel left pending damage or owned projectiles"):
		return

	boss.take_damage(float(boss.health.max_health))
	await process_frame
	await process_frame
	if not _assert_true(projectiles.get_child_count() == 0, "Boss death did not clean up owned slam projectiles"):
		return

	fixture.queue_free()
	await process_frame
	print("TEST PASS: BossTentacleTest %d" % assertions)
	quit(0)
