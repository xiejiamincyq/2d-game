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
	push_error("TEST FAIL: BossTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var player := Node2D.new()
	var enemies := Node2D.new()
	var projectiles := Node2D.new()
	var portals := Node2D.new()
	fixture.add_child(player)
	fixture.add_child(enemies)
	fixture.add_child(projectiles)
	fixture.add_child(portals)
	player.global_position = Vector2.ZERO

	var director: Node = WaveDirectorScript.new()
	fixture.add_child(director)
	director.set_process(false)
	director.world_bounds = Rect2(-900.0, -600.0, 1800.0, 1200.0)
	director.setup(player, enemies, projectiles, portals, false)
	director.wave_index = director.waves.size() - 1
	director.wave_running = true
	director.active = true

	var event_order: Array[String] = []
	var spawned_bosses: Array[Node] = []
	var health_events: Array[Array] = []
	var defeated_count := [0]
	var finished_count := [0]
	var victory_count := [0]
	director.boss_spawned.connect(func(boss: Node, _display_name: String, _maximum_health: float) -> void:
		spawned_bosses.append(boss)
		event_order.append("spawned")
	)
	director.boss_health_changed.connect(func(current: float, maximum: float, phase: int) -> void:
		health_events.append([current, maximum, phase])
	)
	director.boss_defeated.connect(func(_boss: Node) -> void:
		defeated_count[0] += 1
		event_order.append("defeated")
	)
	director.wave_finished.connect(func(_summary: Dictionary) -> void:
		finished_count[0] += 1
		event_order.append("finished")
	)
	director.victory.connect(func() -> void:
		victory_count[0] += 1
		event_order.append("victory")
	)

	var regular_enemy := Node2D.new()
	enemies.add_child(regular_enemy)
	director.active_enemies.append(regular_enemy)
	director._process(0.016)
	if not _assert_true(not director.boss_entrance_started and director.boss_portal == null, "Boss entrance began before regular enemies were cleared"):
		return
	director.active_enemies.erase(regular_enemy)
	regular_enemy.queue_free()
	await process_frame

	director._process(0.016)
	if not _assert_true(director.boss_entrance_started and is_instance_valid(director.boss_portal), "final regular clear did not open the Boss entrance portal"):
		return
	if not _assert_true(director.boss_portal.scale.x >= 1.5 and spawned_bosses.is_empty(), "Boss portal was not visibly larger or spawned the Boss without warning"):
		return
	director._process(director.BOSS_PORTAL_WARNING_SECONDS - 0.01)
	if not _assert_true(spawned_bosses.is_empty(), "Boss spawned before the entrance warning completed"):
		return
	director._process(0.02)
	if not _assert_true(spawned_bosses.size() == 1 and director.get_active_boss() == spawned_bosses[0], "Boss did not spawn exactly once after the warning"):
		return

	var boss: Node = spawned_bosses[0]
	if not _assert_true(boss.get_script() == OverseerBossScript and boss.get_script() != EnemyScript, "Boss still used the generic Enemy implementation"):
		return
	if not _assert_true(is_equal_approx(float(boss.body_radius), 56.0), "Boss collision radius did not match the independent large-body contract"):
		return
	var boss_playable: Rect2 = director.world_bounds.grow(-float(boss.body_radius))
	if not _assert_true(boss_playable.has_point(boss.global_position), "Boss spawned outside the playable world bounds"):
		return
	if not _assert_true(not health_events.is_empty() and int(health_events[-1][2]) == 1, "Boss did not publish its initial health/phase contract"):
		return

	director._process(director.BOSS_PORTAL_BURST_SECONDS + 0.01)
	director._process(1.0)
	if not _assert_true(spawned_bosses.size() == 1, "Boss entrance created duplicate Boss instances"):
		return
	if not _assert_true(not director.complete_final_wave() and victory_count[0] == 0 and finished_count[0] == 0, "final victory was reachable while the Boss was alive"):
		return

	boss.take_damage(1.0, DamageTypes.PROJECTILE, Vector2.LEFT)
	if not _assert_true(health_events.size() >= 2 and float(health_events[-1][0]) < float(health_events[-1][1]), "Boss damage did not flow through the public health contract"):
		return
	boss.take_damage(float(boss.health.max_health), DamageTypes.PROJECTILE, Vector2.LEFT)
	await process_frame
	await process_frame
	director._process(0.016)
	if not _assert_true(defeated_count[0] == 1 and not is_instance_valid(director.get_active_boss()), "Boss cleanup did not resolve exactly once"):
		return
	if not _assert_true(finished_count[0] == 1 and director.waiting_for_advance and victory_count[0] == 0, "Boss cleanup did not gate the final clear banner before victory"):
		return
	if not _assert_true(event_order.slice(0, 3) == ["spawned", "defeated", "finished"], "Boss lifecycle events were emitted out of order: %s" % [event_order]):
		return
	if not _assert_true(director.complete_final_wave() and victory_count[0] == 1 and not director.active, "cleared Boss wave did not resolve victory"):
		return
	if not _assert_true(not director.complete_final_wave() and victory_count[0] == 1 and event_order[-1] == "victory", "final victory resolved more than once"):
		return

	fixture.queue_free()
	await process_frame
	print("TEST PASS: BossTest %d" % assertions)
	quit(0)
