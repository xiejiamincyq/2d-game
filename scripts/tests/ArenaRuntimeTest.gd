extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: ArenaRuntimeTest: " + message)
	paused = false
	quit(1)
	return false

func _initialize() -> void:
	var scene: Node = MainScript.new()
	scene.audio_enabled = false
	root.add_child(scene)
	await process_frame
	scene._start_run()
	await physics_frame

	if not _assert_true(scene.arena_layout != null, "main scene did not create an arena layout"):
		return
	var descriptors: Array[Dictionary] = scene.arena_layout.get_obstacle_descriptors()
	if not _assert_true(descriptors.size() >= 9, "starting a run did not generate obstacle terrain"):
		return
	if not _assert_true(scene.arena_layout.is_position_walkable(scene.player.global_position, scene.player.get_body_radius()), "player spawned inside an obstacle"):
		return

	var obstacle_rect: Rect2 = descriptors[0]["rect"]
	var player_radius: float = scene.player.get_body_radius()
	scene.player.set_physics_process(false)
	scene.player.global_position = Vector2(obstacle_rect.position.x - player_radius - 4.0, obstacle_rect.get_center().y)
	await physics_frame
	var collision: KinematicCollision2D = scene.player.move_and_collide(Vector2.RIGHT * (obstacle_rect.size.x + player_radius * 2.0 + 16.0), true)
	if not _assert_true(collision != null and collision.get_collider().is_in_group(&"arena_obstacles"), "player movement was not blocked by obstacle collision"):
		return

	if not _assert_true(scene.wave_director.arena_navigation == scene.arena_layout, "wave director did not receive the shared arena navigation"):
		return
	var resolved_portal: Vector2 = scene.wave_director.resolve_arena_spawn_position(obstacle_rect.get_center(), 48.0)
	if not _assert_true(scene.arena_layout.is_position_walkable(resolved_portal, 48.0), "portal position was not resolved away from obstacle terrain"):
		return
	scene.wave_director._spawn_enemy_at(EnemyScript.EnemyKind.SCRAPPER, obstacle_rect.get_center())
	var spawned_enemy: Node = scene.wave_director.active_enemies.back()
	if not _assert_true(spawned_enemy.arena_navigation == scene.arena_layout, "spawned enemy did not receive shared navigation"):
		return
	if not _assert_true(scene.arena_layout.is_position_walkable(spawned_enemy.global_position, spawned_enemy.body_radius), "enemy remained inside obstacle after spawn resolution"):
		return
	var ranged_enemy: Node = EnemyScript.new()
	ranged_enemy.setup(EnemyScript.EnemyKind.SPITTER, 1, scene.projectiles, scene.player)
	ranged_enemy.set_arena_navigation(scene.arena_layout)
	ranged_enemy.set_physics_process(false)
	scene.enemies.add_child(ranged_enemy)
	scene.arena_layout.flow_fields.clear()
	for i in range(16):
		ranged_enemy.global_position = Vector2(-900.0 + i * 80.0, -420.0)
		ranged_enemy._apply_arena_navigation(Vector2.RIGHT, ranged_enemy.global_position + Vector2(240.0, 0.0))
	if not _assert_true(scene.arena_layout.flow_fields.is_empty(), "ranged local movement repeatedly rebuilt global flow fields"):
		return
	var boss_rect: Rect2 = descriptors[1]["rect"]
	var spawned_boss: Node = scene.wave_director._spawn_boss_at(boss_rect.get_center())
	if not _assert_true(spawned_boss != null and spawned_boss.arena_navigation == scene.arena_layout, "Boss did not receive shared navigation"):
		return
	if not _assert_true(scene.arena_layout.is_position_walkable(spawned_boss.global_position, spawned_boss.body_radius), "Boss remained inside obstacle after spawn resolution"):
		return

	if not _assert_true(scene._save_stable_snapshot("wave_intro", 1), "arena run snapshot could not be saved"):
		return
	var snapshot: Dictionary = scene.snapshot_store.load_snapshot()
	if not _assert_true(int(snapshot.get("map_seed", -1)) == scene.map_seed, "map seed was not persisted for continue"):
		return
	if not _assert_true(int(snapshot.get("map_generator_version", -1)) == 2, "new map generator version was not persisted"):
		return

	scene.snapshot_store.clear_snapshot()
	TestSupport.stop_audio(scene.audio)
	await create_timer(0.15).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	print("TEST PASS: ArenaRuntimeTest %d" % assertions)
	quit(0)
