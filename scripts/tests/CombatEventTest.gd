extends SceneTree

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: CombatEventTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var enemy: Node = EnemyScript.new()
	root.add_child(enemy)
	enemy.setup(EnemyScript.EnemyKind.SCRAPPER, 1, root)
	await process_frame
	enemy.set_physics_process(false)
	enemy.health.set_process(false)

	var damage_events: Array[Dictionary] = []
	var death_events: Array[Dictionary] = []
	enemy.damage_resolved.connect(func(
		resolved_enemy: Node,
		source: StringName,
		amount: float,
		world_position: Vector2,
		direction: Vector2,
		killed: bool
	) -> void:
		damage_events.append({
			"enemy": resolved_enemy,
			"source": source,
			"amount": amount,
			"world_position": world_position,
			"direction": direction,
			"killed": killed,
		})
	)
	enemy.died.connect(func(resolved_enemy: Node, coin_value: int, source: StringName) -> void:
		death_events.append({"enemy": resolved_enemy, "coins": coin_value, "source": source})
	)

	var first_killed: bool = enemy.take_damage(12.0, DamageTypes.LASER, Vector2(3.0, 4.0))
	if not _assert_true(not first_killed, "a non-lethal hit reported a kill"):
		return
	if not _assert_true(damage_events.size() == 1, "an accepted hit emitted %d damage events" % damage_events.size()):
		return
	var first_event: Dictionary = damage_events[0]
	if not _assert_true(first_event["enemy"] == enemy, "damage event did not identify its enemy"):
		return
	if not _assert_true(first_event["source"] == DamageTypes.LASER, "known damage source changed"):
		return
	if not _assert_true(is_equal_approx(first_event["amount"], 12.0), "actual damage was %.2f instead of 12" % first_event["amount"]):
		return
	if not _assert_true(first_event["direction"] == Vector2(3.0, 4.0), "hit direction changed to %s" % first_event["direction"]):
		return
	if not _assert_true(not first_event["killed"], "non-lethal damage event reported a kill"):
		return

	enemy.health.begin_invulnerability(1.0)
	var rejected_killed: bool = enemy.take_damage(5.0, DamageTypes.ARC)
	var zero_killed: bool = enemy.take_damage(0.0, DamageTypes.SPIKE)
	if not _assert_true(not rejected_killed and not zero_killed, "rejected damage reported a kill"):
		return
	if not _assert_true(damage_events.size() == 1, "rejected or zero damage emitted a result event"):
		return

	enemy.health.invulnerable_time = 0.0
	var unknown_source: StringName = &"modded_unknown_source"
	var unknown_killed: bool = enemy.take_damage(2.0, unknown_source)
	if not _assert_true(not unknown_killed, "unknown-source non-lethal hit reported a kill"):
		return
	if not _assert_true(damage_events[-1]["source"] == DamageTypes.GENERIC, "unknown source did not fall back to generic"):
		return

	enemy.health.current_health = 5.0
	var lethal_killed: bool = enemy.take_damage(20.0, DamageTypes.DASH, Vector2.LEFT)
	if not _assert_true(lethal_killed, "lethal accepted damage did not report a kill"):
		return
	if not _assert_true(damage_events.size() == 3, "lethal hit did not emit exactly one result event"):
		return
	var lethal_event: Dictionary = damage_events[-1]
	if not _assert_true(is_equal_approx(lethal_event["amount"], 5.0), "overkill reported %.2f damage instead of actual 5" % lethal_event["amount"]):
		return
	if not _assert_true(lethal_event["killed"], "lethal damage event did not report death"):
		return
	if not _assert_true(death_events.size() == 1, "one enemy emitted %d death facts" % death_events.size()):
		return
	if not _assert_true(death_events[0]["source"] == DamageTypes.DASH, "death fact lost its damage source"):
		return
	if not _assert_true(death_events[0]["coins"] == enemy.coin_value, "death fact changed coin value"):
		return

	var repeated_killed: bool = enemy.take_damage(1.0, DamageTypes.PROJECTILE)
	if not _assert_true(not repeated_killed, "already-dead enemy reported a second kill"):
		return
	if not _assert_true(damage_events.size() == 3 and death_events.size() == 1, "already-dead enemy emitted duplicate facts"):
		return

	await process_frame
	print("TEST PASS: CombatEventTest %d" % assertions)
	quit(0)
