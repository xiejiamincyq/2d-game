extends SceneTree

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const OverseerBossScript = preload("res://scripts/actors/OverseerBoss.gd")
const WaveDirectorScript = preload("res://scripts/systems/WaveDirector.gd")

class StealthPlayer extends Node2D:
	var stealth_active := false
	func is_stealthed() -> bool:
		return stealth_active

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
	var player := StealthPlayer.new()
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
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	boss.set_physics_process(false)
	boss.process_mode = Node.PROCESS_MODE_ALWAYS
	var attack_director: Node = boss.get_attack_director()
	if not _assert_true(attack_director != null, "Boss did not create its attack director"):
		return
	attack_director.set_process(false)
	boss.get_tentacle_attack().set_physics_process(false)

	var phases: Array[int] = []
	var reinforcements: Array[int] = []
	attack_director.phase_changed.connect(func(phase: int) -> void: phases.append(phase))
	boss.reinforcements_requested.connect(func(_boss: Node, count: int) -> void: reinforcements.append(count))
	var entrance_finished_count := [0]
	boss.entrance_finished.connect(func() -> void: entrance_finished_count[0] += 1)
	if not _assert_true(attack_director.get_state_name() == "ENTRANCE", "Boss did not begin in ENTRANCE"):
		return
	if not _assert_true(boss.process_mode == Node.PROCESS_MODE_ALWAYS and boss.scale.x < 0.25 and boss.modulate.a < 0.2, "Boss entrance did not begin as an unpaused reveal animation (mode=%s scale=%s alpha=%s)" % [boss.process_mode, boss.scale.x, boss.modulate.a]):
		return
	boss._physics_process(attack_director.ENTRANCE_SECONDS * 0.5)
	if not _assert_true(entrance_finished_count[0] == 0 and projectiles.get_child_count() == 0 and boss.scale.x > 0.25 and boss.scale.x < 1.0, "Boss entrance animation did not hold combat during its reveal"):
		return
	boss._physics_process(attack_director.ENTRANCE_SECONDS * 0.5 + 0.01)
	if not _assert_true(attack_director.get_state_name() == "PHASE_1" and phases == [1], "entrance did not resolve into phase one"):
		return
	if not _assert_true(entrance_finished_count[0] == 1 and boss.process_mode == Node.PROCESS_MODE_PAUSABLE and boss.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(boss.modulate.a, 1.0), "Boss reveal did not resume normal combat exactly once (count=%s mode=%s scale=%s alpha=%s)" % [entrance_finished_count[0], boss.process_mode, boss.scale, boss.modulate.a]):
		return
	if not _assert_true(is_equal_approx(OverseerBossScript.MOVE_SPEED, 63.8), "Boss did not receive the global 10 percent movement-speed increase"):
		return
	player.stealth_active = true
	attack_director.attack_gap = 0.0
	boss._physics_process(0.2)
	if not _assert_true(attack_director.target_hidden and not boss.get_tentacle_attack().is_attacking() and not attack_director.get_pattern().is_pattern_active(), "Boss retained targeting while the player was invisible"):
		return
	player.stealth_active = false
	boss._physics_process(0.01)
	if not _assert_true(not attack_director.target_hidden, "Boss did not reacquire the player after invisibility ended"):
		return
	boss.global_position = player.global_position + Vector2(120.0, 0.0)
	attack_director.attack_gap = 0.0
	attack_director.advance(0.01)
	if not _assert_true(attack_director.get_last_attack_class() == &"melee" and boss.get_tentacle_attack().is_attacking() and not attack_director.get_pattern().is_pattern_active(), "close-range Boss scheduling did not reserve a telegraphed melee-only window"):
		return
	boss.get_tentacle_attack().advance_attack(boss.get_tentacle_attack().SWEEP_WARNING_SECONDS + boss.get_tentacle_attack().SWEEP_ACTIVE_SECONDS + 0.01)
	attack_director.advance(0.01)
	if not _assert_true(not boss.get_tentacle_attack().is_attacking(), "Boss restarted melee immediately when its previous attack ended"):
		return
	attack_director.advance(attack_director.ATTACK_RECOVERY_SECONDS - 0.03)
	if not _assert_true(not boss.get_tentacle_attack().is_attacking(), "Boss ignored the post-attack recovery window"):
		return
	attack_director.advance(0.03)
	if not _assert_true(boss.get_tentacle_attack().is_attacking(), "Boss did not resume attacking after its recovery window"):
		return
	attack_director._cancel_active_attacks()
	attack_director.get_pattern().advance(attack_director.get_pattern().PATTERN_BLANK_WINDOW_SECONDS + 0.01)
	boss.global_position = player.global_position + Vector2(430.0, 0.0)
	attack_director.attack_gap = 0.0
	attack_director.advance(0.01)
	if not _assert_true(attack_director.get_last_attack_class() == &"ranged" and attack_director.get_pattern().is_pattern_active() and not boss.get_tentacle_attack().is_attacking(), "long-range Boss scheduling did not choose a readable projectile pattern"):
		return
	attack_director.get_pattern().advance(0.46)
	var interrupted_projectile_count := projectiles.get_child_count()
	if not _assert_true(interrupted_projectile_count >= 5, "ranged interruption fixture did not fire projectiles before cancellation"):
		return
	boss.global_position = player.global_position + Vector2(120.0, 0.0)
	attack_director.advance(0.01)
	if not _assert_true(not attack_director.get_pattern().is_pattern_active() and projectiles.get_child_count() == interrupted_projectile_count, "Boss interruption removed bullets that had already been fired"):
		return
	var outside_safe_rect: Vector2 = boss.get_combat_safe_rect().end + Vector2(180.0, 120.0)
	boss.global_position = outside_safe_rect
	var recovery_direction: Vector2 = boss.get_combat_movement_direction(player)
	if not _assert_true(recovery_direction.dot(boss.get_combat_safe_rect().get_center() - outside_safe_rect) > 0.0, "off-screen Boss movement did not return toward the camera-safe combat area"):
		return
	var anchor_pattern: Node2D = attack_director.get_pattern()
	boss.global_position = Vector2(640.0, 512.0)
	attack_director.advance(0.016)
	if not _assert_true(anchor_pattern.global_position.distance_to(boss.global_position) < 0.01, "bullet pattern did not anchor to the Boss position"):
		return
	boss.global_position = Vector2(-420.0, 300.0)
	attack_director.advance(0.016)
	if not _assert_true(anchor_pattern.global_position.distance_to(boss.global_position) < 0.01, "bullet pattern did not follow the Boss after it moved"):
		return

	attack_director.get_pattern().advance(attack_director.get_pattern().PATTERN_BLANK_WINDOW_SECONDS + 0.01)
	attack_director.get_pattern().start_pattern(attack_director.get_pattern().AIMED_FAN)
	attack_director.get_pattern().advance(0.46)
	if not _assert_true(projectiles.get_child_count() >= 5, "fixture did not create owned Boss projectiles"):
		return
	var transition_projectile_count := projectiles.get_child_count()
	boss.take_damage(boss.health.max_health * 0.66, DamageTypes.PROJECTILE)
	if not _assert_true(attack_director.get_state_name() == "TRANSITION_1" and reinforcements == [6], "large threshold hit skipped transition one or its six reinforcements"):
		return
	await process_frame
	if not _assert_true(projectiles.get_child_count() == transition_projectile_count and not attack_director.get_pattern().is_pattern_active(), "phase transition removed bullets that were already in flight"):
		return
	attack_director.advance(attack_director.TRANSITION_SECONDS + 0.01)
	if not _assert_true(attack_director.get_state_name() == "TRANSITION_2" and reinforcements == [6, 8], "large threshold hit did not preserve transition two and its eight reinforcements"):
		return
	attack_director.advance(attack_director.TRANSITION_SECONDS + 0.01)
	if not _assert_true(attack_director.get_state_name() == "PHASE_3" and phases == [1, 2, 3], "phase jump did not resolve every combat phase exactly once"):
		return
	attack_director.advance(attack_director.INITIAL_ATTACK_DELAY_SECONDS - 0.01)
	if not _assert_true(not attack_director.get_pattern().is_pattern_active() and not boss.get_tentacle_attack().is_attacking(), "phase three ignored its initial attack grace period"):
		return
	attack_director.advance(0.02)
	if not _assert_true(attack_director.get_pattern().is_pattern_active() and not boss.get_tentacle_attack().is_attacking(), "phase three did not begin with a mutually exclusive Broken Ring pattern after its grace period"):
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
	var death_cleared_pattern: bool = not attack_director.get_pattern().is_pattern_active()
	if not _assert_true(attack_director.get_state_name() == "DEATH" and death_cleared_pattern and not boss.get_tentacle_attack().is_attacking() and reinforcements == [6, 8], "lethal damage left an attack active or requested late reinforcements"):
		return
	await process_frame
	if not _assert_true(projectiles.get_child_count() == 0, "Boss death left live projectiles"):
		return
	fixture.queue_free()
	await process_frame
	print("TEST PASS: BossDirectorTest %d" % assertions)
	quit(0)
