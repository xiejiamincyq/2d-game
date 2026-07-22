extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const WaveDirectorScript = preload("res://scripts/systems/WaveDirector.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: EnemyBehaviorTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var original_window_size := root.size
	root.size = Vector2i(960, 540)

	var fixture := Node2D.new()
	root.add_child(fixture)
	var camera := Camera2D.new()
	camera.global_position = Vector2(180.0, -120.0)
	camera.enabled = true
	fixture.add_child(camera)
	var player := Node2D.new()
	player.global_position = camera.global_position
	player.add_to_group("player")
	fixture.add_child(player)
	var projectiles := Node2D.new()
	fixture.add_child(projectiles)
	var spitter: Node = EnemyScript.new()
	spitter.setup(EnemyScript.EnemyKind.SPITTER, 2, projectiles)
	spitter.world_bounds = Rect2(-1400, -900, 2800, 1800)
	fixture.add_child(spitter)
	await process_frame
	await process_frame

	var safe_rect: Rect2 = spitter.get_camera_safe_rect()
	var camera_center := camera.get_screen_center_position()
	var runtime_view_size: Vector2 = spitter.get_viewport().get_visible_rect().size
	if not _assert_true(safe_rect.get_center().distance_to(camera_center) <= 0.01, "safe rect did not use Camera2D screen center"):
		return
	if not _assert_true(safe_rect.size.distance_to(runtime_view_size - Vector2(96, 96)) <= 0.01, "safe rect did not reserve a 48px margin: %s" % safe_rect):
		return

	var small_min: float = spitter.get_dynamic_ranged_min_distance(Rect2(Vector2.ZERO, Vector2(864, 444)))
	var medium_min: float = spitter.get_dynamic_ranged_min_distance(Rect2(Vector2.ZERO, Vector2(1184, 624)))
	var large_min: float = spitter.get_dynamic_ranged_min_distance(Rect2(Vector2.ZERO, Vector2(1824, 984)))
	if not _assert_true(small_min >= 150.0 and small_min < medium_min and medium_min < large_min and large_min <= spitter.ranged_keep_min, "minimum ranged distance did not adapt to viewport size: %.1f/%.1f/%.1f" % [small_min, medium_min, large_min]):
		return

	spitter.global_position = safe_rect.end + Vector2(80, 0)
	var outside_return: Vector2 = spitter._get_ranged_desired_velocity(player.global_position - spitter.global_position, safe_rect)
	var closest_visible_point: Vector2 = spitter.global_position.clamp(safe_rect.position, safe_rect.end)
	if not _assert_true(is_equal_approx(outside_return.length(), 1.0) and outside_return.dot((closest_visible_point - spitter.global_position).normalized()) > 0.99, "offscreen Spitter did not return toward the visible zone at full speed: %s" % outside_return):
		return
	spitter.global_position = Vector2(safe_rect.end.x - 1.0, safe_rect.get_center().y)
	var edge_direction: Vector2 = spitter.constrain_ranged_direction(Vector2.RIGHT, safe_rect)
	if not _assert_true(edge_direction.x <= 0.0, "Spitter movement could still escape through the visible right edge: %s" % edge_direction):
		return

	spitter.shoot_cooldown = 0.0
	spitter.global_position = safe_rect.end + Vector2(10, 0)
	spitter._update_spitter(1.0, player)
	if not _assert_true(projectiles.get_child_count() == 0, "offscreen Spitter fired before entering the visible engagement zone"):
		return
	var runtime_min: float = spitter.get_dynamic_ranged_min_distance(safe_rect)
	spitter.global_position = player.global_position + Vector2(runtime_min + 24.0, 0)
	spitter.shoot_cooldown = 0.0
	spitter._update_spitter(1.0, player)
	if not _assert_true(projectiles.get_child_count() == 1, "visible Spitter inside its distance ring did not fire"):
		return

	var sampler: Node = WaveDirectorScript.new()
	sampler.world_bounds = Rect2(-1400, -900, 2800, 1800)
	fixture.add_child(sampler)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5A17
	var view_sizes: Array[Vector2] = [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080)]
	var player_positions: Array[Vector2] = [Vector2.ZERO, Vector2(1100, 650), Vector2(-1100, -650)]
	for view_size in view_sizes:
		for player_position in player_positions:
			var visible_rect := Rect2(player_position - view_size * 0.5, view_size).grow(-48.0)
			var allowed_rect: Rect2 = sampler.world_bounds.grow(-24.0).intersection(visible_rect)
			var dynamic_min: float = spitter.get_dynamic_ranged_min_distance(visible_rect)
			var dynamic_max: float = spitter.get_dynamic_ranged_max_distance(visible_rect)
			for sample_index in range(250):
				var point: Vector2 = sampler.sample_spitter_spawn_position(player_position, visible_rect, rng)
				var distance: float = point.distance_to(player_position)
				if not _assert_true(allowed_rect.has_point(point) and distance >= dynamic_min - 0.01 and distance <= dynamic_max + 0.01, "Spitter spawn escaped world/safe/ring intersection at %s/%s: %s distance %.1f" % [view_size, player_position, point, distance]):
					return

	var spawned_enemies := Node2D.new()
	fixture.add_child(spawned_enemies)
	sampler.player = player
	sampler.enemy_parent = spawned_enemies
	sampler.projectile_parent = projectiles
	sampler.wave_index = 1
	sampler._spawn_enemy(EnemyScript.EnemyKind.SPITTER)
	var spawned_spitter: Node2D = spawned_enemies.get_child(0)
	var production_safe_rect: Rect2 = sampler.get_camera_safe_rect()
	var production_distance := spawned_spitter.global_position.distance_to(player.global_position)
	if not _assert_true(
		production_safe_rect.has_point(spawned_spitter.global_position)
		and production_distance >= EnemyScript.calculate_dynamic_ranged_min_distance(production_safe_rect) - 0.01
		and production_distance <= EnemyScript.calculate_dynamic_ranged_max_distance(production_safe_rect) + 0.01,
		"WaveDirector did not route a real Spitter spawn through the visible distance-ring sampler"
	):
		return

	# Enemy pursuit must not use whichever node happened to join the global
	# player group first. During reloads or UI previews that can be a stale node
	# near a map edge, which makes a newborn enemy sprint in the wrong direction.
	var stale_player := Node2D.new()
	stale_player.global_position = Vector2(0.0, -860.0)
	stale_player.add_to_group("player")
	fixture.add_child(stale_player)
	var directed_enemy: Node = EnemyScript.new()
	directed_enemy.setup(EnemyScript.EnemyKind.SCRAPPER, 1, projectiles)
	directed_enemy.target_player = player
	fixture.add_child(directed_enemy)
	if not _assert_true(directed_enemy.get_target_player() == player, "enemy pursuit selected a stale global player instead of its wave owner"):
		return
	var wave_enemy_count := spawned_enemies.get_child_count()
	sampler._spawn_enemy(EnemyScript.EnemyKind.SCRAPPER)
	var wave_directed_enemy: Node = spawned_enemies.get_child(wave_enemy_count)
	if not _assert_true(wave_directed_enemy.get_target_player() == player, "WaveDirector did not bind a spawned enemy to its wave owner"):
		return
	player.global_position = Vector2(280.0, 620.0)
	wave_directed_enemy.global_position = Vector2(100.0, 100.0)
	wave_directed_enemy._physics_process(0.1)
	if not _assert_true(wave_directed_enemy.velocity.y > 0.0, "newborn enemy pursued the stale player above the map instead of its current wave owner"):
		return

	for child in projectiles.get_children():
		child.queue_free()
	fixture.queue_free()
	root.size = original_window_size
	await process_frame
	await process_frame
	print("TEST PASS: EnemyBehaviorTest %d" % assertions)
	quit(0)
