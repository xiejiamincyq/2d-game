extends SceneTree

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const OverseerBossScript = preload("res://scripts/actors/OverseerBoss.gd")
const WaveDirectorScript = preload("res://scripts/systems/WaveDirector.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: BossDirectorTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var player := Node2D.new()
	var projectiles := Node2D.new()
	var enemies := Node2D.new()
	var portals := Node2D.new()
	fixture.add_child(player)
	fixture.add_child(projectiles)
	fixture.add_child(enemies)
	fixture.add_child(portals)
	player.global_position = Vector2(280.0, 0.0)

	var boss: Node2D = OverseerBossScript.new()
	boss.world_bounds = Rect2(-900.0, -600.0, 1800.0, 1200.0)
	boss.setup(5, projectiles, player)
	fixture.add_child(boss)
	await process_frame
	boss.set_physics_process(false)
	var attack_director: Node = boss.get_attack_director()
	if not _assert_true(attack_director != null, "Boss did not create its attack director"):
		return
	attack_director.set_process(false)
	boss.get_tentacle_attack().set_physics_process(false)

	var phases: Array[int] = []
	var reinforcements: Array[int] = []
	attack_director.phase_changed.connect(func(phase: int) -> void: phases.append(phase))
	boss.reinforcements_requested.connect(func(_boss: Node, count: int) -> void: reinforcements.append(count))
	if not _assert_true(attack_director.get_state_name() == "ENTRANCE", "Boss did not begin in ENTRANCE"):
		return
	attack_director.advance(attack_director.ENTRANCE_SECONDS + 0.01)
	if not _assert_true(attack_director.get_state_name() == "PHASE_1" and phases == [1], "entrance did not resolve into phase one"):
		return

	attack_director.get_pattern().start_pattern(attack_director.get_pattern().AIMED_FAN)
	attack_director.get_pattern().advance(0.46)
	if not _assert_true(projectiles.get_child_count() >= 5, "fixture did not create owned Boss projectiles"):
		return
	boss.take_damage(boss.health.max_health * 0.66, DamageTypes.PROJECTILE)
	if not _assert_true(attack_director.get_state_name() == "TRANSITION_1" and reinforcements == [6], "large threshold hit skipped transition one or its six reinforcements"):
		return
	await process_frame
	if not _assert_true(projectiles.get_child_count() == 0 and not attack_director.get_pattern().is_pattern_active(), "phase transition left Boss projectiles alive"):
		return
	attack_director.advance(attack_director.TRANSITION_SECONDS + 0.01)
	if not _assert_true(attack_director.get_state_name() == "TRANSITION_2" and reinforcements == [6, 8], "large threshold hit did not preserve transition two and its eight reinforcements"):
		return
	attack_director.advance(attack_director.TRANSITION_SECONDS + 0.01)
	if not _assert_true(attack_director.get_state_name() == "PHASE_3" and phases == [1, 2, 3], "phase jump did not resolve every combat phase exactly once"):
		return
	attack_director.advance(0.01)
	if not _assert_true(attack_director.get_pattern().is_pattern_active() and not boss.get_tentacle_attack().is_attacking(), "phase three did not begin with a mutually exclusive Broken Ring pattern"):
		return
	attack_director.set_health_phase(3)
	if not _assert_true(reinforcements == [6, 8], "repeated health update duplicated reinforcements"):
		return

	var wave_director: Node = WaveDirectorScript.new()
	fixture.add_child(wave_director)
	wave_director.set_process(false)
	wave_director.world_bounds = boss.world_bounds
	wave_director.setup(player, enemies, projectiles, portals, false)
	wave_director.active_boss = boss
	wave_director._on_boss_reinforcements_requested(boss, 20)
	var queued := 0
	for queue in wave_director.portal_spawn_queues.values():
		for kind in queue:
			queued += 1
			if not _assert_true(int(kind) in [EnemyScript.EnemyKind.SCRAPPER, EnemyScript.EnemyKind.DASHER], "Boss reinforcement whitelist included a ranged enemy"):
				return
	if not _assert_true(queued == 8, "Boss reinforcement request escaped its eight-enemy cap"):
		return

	boss.take_damage(boss.health.max_health, DamageTypes.PROJECTILE)
	if not _assert_true(attack_director.get_state_name() == "DEATH" and not boss.get_tentacle_attack().is_attacking() and reinforcements == [6, 8], "lethal damage left an attack active or requested late reinforcements"):
		return
	if not _assert_true(projectiles.get_child_count() == 0 and not attack_director.get_pattern().is_pattern_active(), "Boss death left live projectiles or an active bullet pattern"):
		return
	fixture.queue_free()
	await process_frame
	print("TEST PASS: BossDirectorTest %d" % assertions)
	quit(0)
