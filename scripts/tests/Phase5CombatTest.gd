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
	# Standard-build pacing budget. Unit weights include expected aim/travel/TTK
	# interaction time under the build curve; banners and four settlement choices
	# are added separately. Phase 6 telemetry can tune the weights, while this
	# contract prevents the five-stage table drifting outside 4:30-5:30.
	var interaction_seconds := {
		"scrapper": 0.28, "dasher": 0.24, "spitter": 0.65, "bruiser": 2.2,
		"marksman": 0.85, "lobber": 1.2, "overseer": 12.0,
	}
	var previous_stage_seconds := 0.0
	var estimated_combat_seconds := 0.0
	var total_enemy_count := 0
	for stage in director.waves:
		var stage_seconds := 0.0
		for enemy_id in interaction_seconds:
			var count := int(stage.get(enemy_id, 0))
			total_enemy_count += count
			stage_seconds += float(count) * float(interaction_seconds[enemy_id])
		if not _assert_true(stage_seconds > previous_stage_seconds, "stage pressure did not increase monotonically"):
			return
		previous_stage_seconds = stage_seconds
		estimated_combat_seconds += stage_seconds
	var estimated_run_seconds := estimated_combat_seconds + 28.0 + 11.0
	if not _assert_true(total_enemy_count == 649, "five-stage content budget changed without pacing review"):
		return
	if not _assert_true(estimated_run_seconds >= 270.0 and estimated_run_seconds <= 330.0, "standard-build duration budget %.1fs escaped 4:30-5:30" % estimated_run_seconds):
		return
	print("PACING: standard_build_estimate_seconds=%.1f enemies=%d" % [estimated_run_seconds, total_enemy_count])

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
	var locked_marksman_direction: Vector2 = (player.global_position - marksman.global_position).normalized()
	if not _assert_true(
		marksman.ranged_is_winding_up
		and is_equal_approx(marksman.ranged_windup_duration, 0.5)
		and marksman.global_position.distance_to(marksman.ranged_target_position) >= 1200.0
		and projectiles.get_child_count() == 0,
		"Marksman did not provide a long harmless 0.5 second trajectory warning"
	):
		return
	player.global_position = Vector2(0.0, 140.0)
	marksman._update_marksman(marksman.ranged_windup_duration - 0.01, player)
	if not _assert_true(projectiles.get_child_count() == 0, "Marksman fired before the 0.5 second dodge window elapsed"):
		return
	marksman._update_marksman(0.02, player)
	var marksman_shot: Node = projectiles.get_child(0)
	if not _assert_true(
		projectiles.get_child_count() == 1
		and is_equal_approx(marksman_shot.velocity.length(), EnemyScript.ENEMY_PROJECTILE_BASE_SPEED * 3.5)
		and marksman_shot.velocity.normalized().dot(locked_marksman_direction) > 0.999,
		"Marksman warning did not resolve into a locked 350% speed projectile"
	):
		return
	player.global_position = Vector2.ZERO

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
