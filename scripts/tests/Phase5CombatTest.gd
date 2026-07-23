extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const WaveDirectorScript = preload("res://scripts/systems/WaveDirector.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: Phase5CombatTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	root.size = Vector2i(960, 540)
	var director: Node = WaveDirectorScript.new()
	root.add_child(director)
	director.set_process(false)
	if not _assert_true(director.waves.size() == 5, "phase table did not contain exactly five stages"):
		return
	for kind_name in ["MARKSMAN", "LOBBER", "OVERSEER"]:
		if not _assert_true(EnemyScript.EnemyKind.has(kind_name), "enemy roster is missing %s" % kind_name):
			return
	var boss_kind := int(EnemyScript.EnemyKind.get("OVERSEER", -1))
	for stage_index in range(director.waves.size()):
		var stage: Dictionary = director.waves[stage_index]
		var boss_count := int(stage.get("overseer", 0))
		if not _assert_true(boss_count == (1 if stage_index == 4 else 0), "boss placement was invalid in stage %d" % (stage_index + 1)):
			return
	if not _assert_true(boss_kind >= 0, "final boss kind was not registered"):
		return

	var fixture := Node2D.new()
	root.add_child(fixture)
	var player := Node2D.new()
	player.global_position = Vector2.ZERO
	player.add_to_group(&"player")
	fixture.add_child(player)
	var projectiles := Node2D.new()
	fixture.add_child(projectiles)

	var marksman: Node = EnemyScript.new()
	marksman.setup(EnemyScript.EnemyKind.MARKSMAN, 2, projectiles, player)
	fixture.add_child(marksman)
	await process_frame
	var marksman_safe: Rect2 = marksman.get_camera_safe_rect()
	marksman.global_position = Vector2((marksman.get_dynamic_ranged_min_distance(marksman_safe) + marksman.get_dynamic_ranged_max_distance(marksman_safe)) * 0.5, 0.0)
	marksman.shoot_cooldown = 0.0
	marksman._update_marksman(0.1, player)
	if not _assert_true(marksman.ranged_is_winding_up and projectiles.get_child_count() == 0, "Marksman did not telegraph before firing"):
		return
	marksman._update_marksman(marksman.ranged_windup_duration + 0.01, player)
	if not _assert_true(projectiles.get_child_count() == 1, "Marksman telegraph did not resolve into a projectile"):
		return

	var lobber: Node = EnemyScript.new()
	lobber.setup(EnemyScript.EnemyKind.LOBBER, 2, projectiles, player)
	fixture.add_child(lobber)
	await process_frame
	var lobber_safe: Rect2 = lobber.get_camera_safe_rect()
	lobber.global_position = Vector2(-(lobber.get_dynamic_ranged_min_distance(lobber_safe) + lobber.get_dynamic_ranged_max_distance(lobber_safe)) * 0.5, 0.0)
	lobber.shoot_cooldown = 0.0
	lobber._update_lobber(0.1, player)
	if not _assert_true(lobber.ranged_is_winding_up and projectiles.get_child_count() == 1, "Lobber did not warn before launching"):
		return
	lobber._update_lobber(lobber.ranged_windup_duration + 0.01, player)
	var lobbed_shot: Node = projectiles.get_child(projectiles.get_child_count() - 1)
	if not _assert_true(projectiles.get_child_count() == 2 and float(lobbed_shot.get("splash_radius")) >= 60.0, "Lobber did not create a slow splash projectile"):
		return

	var boss: Node = EnemyScript.new()
	boss.setup(EnemyScript.EnemyKind.OVERSEER, 5, projectiles, player)
	fixture.add_child(boss)
	boss.global_position = Vector2(280.0, 0.0)
	await process_frame
	var reinforcement_count := [0]
	boss.reinforcements_requested.connect(func(_enemy: Node, count: int) -> void: reinforcement_count[0] += count)
	boss.health.current_health = boss.health.max_health * 0.6
	boss._update_overseer(0.1, player, 280.0)
	if not _assert_true(reinforcement_count[0] > 0, "final boss did not request portal reinforcements at its health threshold"):
		return
	boss.shoot_cooldown = 0.0
	boss._update_overseer(0.1, player, 280.0)
	if not _assert_true(boss.ranged_is_winding_up, "final boss attack had no readable windup"):
		return
	var before_boss_burst := projectiles.get_child_count()
	boss._update_overseer(boss.ranged_windup_duration + 0.01, player, 280.0)
	if not _assert_true(projectiles.get_child_count() >= before_boss_burst + 8, "final boss telegraph did not resolve into a projectile burst"):
		return

	var portal_layer := Node2D.new()
	fixture.add_child(portal_layer)
	director.player = player
	director.enemy_parent = fixture
	director.projectile_parent = projectiles
	director.portal_parent = portal_layer
	director.world_bounds = Rect2(-900, -600, 1800, 1200)
	director._on_boss_reinforcements_requested(boss, 12)
	var queued_reinforcements := 0
	for queue in director.portal_spawn_queues.values():
		queued_reinforcements += (queue as Array).size()
	if not _assert_true(director.get_active_portal_count() >= 2 and queued_reinforcements == 12, "boss reinforcements did not arrive through multiple timed portals"):
		return

	director.queue_free()
	fixture.queue_free()
	await process_frame
	print("TEST PASS: Phase5CombatTest %d" % assertions)
	quit(0)
