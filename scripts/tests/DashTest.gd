extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const ArenaObstacleScript = preload("res://scripts/world/ArenaObstacle.gd")
var assertions := 0
const THIN_WALL := Rect2(80.0, -100.0, 20.0, 200.0)

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: DashTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not await _test_open_space() or not await _test_original_sweep() or not await _test_thin_wall_red_case():
		return
	for stealth in [false, true]:
		if not await _test_terrain_cases(stealth) or not await _test_enemy_sweeps(stealth):
			return
		if not await _test_timing_and_reset(stealth) or not await _test_world_bounds(stealth):
			return
	if not await _test_evolved_timing():
		return
	print("TEST PASS: DashTest %d" % assertions)
	quit(0)

func _fixture(start := Vector2.ZERO, rect := Rect2(), stealth := false) -> Dictionary:
	var scene := Node2D.new()
	root.add_child(scene)
	var wall: StaticBody2D
	if rect.size != Vector2.ZERO:
		wall = ArenaObstacleScript.new()
		wall.setup(rect, &"planter")
		scene.add_child(wall)
	var player: CharacterBody2D = PlayerScript.new()
	player.position = start
	scene.add_child(player)
	player.set_physics_process(false)
	if stealth:
		player._activate_assassin_stealth()
	# Flush deferred stealth changes and register the real bodies in physics space.
	await process_frame
	await physics_frame
	await physics_frame
	return {"scene": scene, "player": player, "wall": wall}

func _dispose(fixture: Dictionary) -> void:
	fixture.scene.queue_free()
	await process_frame

func _finish_dash(player: Node, hz := 60) -> void:
	for step in range(64):
		if not player.dash_active:
			break
		player._update_dash(1.0 / float(hz))

func _enemy(fixture: Dictionary, position: Vector2) -> Node:
	var enemy: Node = EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.BRUISER, 1, fixture.scene)
	enemy.position = position
	fixture.scene.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func _test_open_space() -> bool:
	for hz in [30, 60, 120]:
		for direction: Vector2 in [Vector2.RIGHT, Vector2(1.0, 1.0).normalized()]:
			var fixture := await _fixture()
			var player: Node = fixture.player
			player._start_dash(direction)
			_finish_dash(player, hz)
			var endpoint: Vector2 = player.global_position
			var ended: bool = not player.dash_active
			await _dispose(fixture)
			if not _assert_true(ended and endpoint.distance_to(direction * 165.0) <= 0.01, "%d Hz open dash ended at %s" % [hz, endpoint]):
				return false
	return true

func _test_original_sweep() -> bool:
	var fixture := await _fixture()
	var enemy := _enemy(fixture, Vector2(82.0, 0.0))
	var before: float = enemy.health.current_health
	fixture.player._start_dash(Vector2.RIGHT)
	fixture.player._update_dash(0.16)
	var damaged: bool = enemy.health.current_health < before
	await _dispose(fixture)
	return _assert_true(damaged, "dash sweep missed an enemy crossed between endpoints")

func _test_thin_wall_red_case() -> bool:
	var fixture := await _fixture(Vector2.ZERO, THIN_WALL)
	var wall_player: CharacterBody2D = fixture.player
	var wall_collision := KinematicCollision2D.new()
	var fixture_blocks := wall_player.test_move(wall_player.global_transform, Vector2(165.0, 0.0), wall_collision)
	if not _assert_true(fixture_blocks and wall_collision.get_collider() == fixture.wall, "thin-wall fixture must block the real player body's swept motion"):
		return false
	wall_player._start_dash(Vector2.RIGHT)
	wall_player._update_dash(0.16)
	var dash_end_x := wall_player.global_position.x
	var maximum_contact_x: float = THIN_WALL.position.x - wall_player.get_body_radius()
	await _dispose(fixture)
	# Staying on the near side catches tunnelling even when the endpoint is clear.
	return _assert_true(dash_end_x <= maximum_contact_x + 0.1, "dash crossed a thin terrain wall: end x %.3f, near-side limit %.3f" % [dash_end_x, maximum_contact_x])

func _test_terrain_cases(stealth: bool) -> bool:
	for hz in [30, 60, 120]:
		for corner in [false, true]:
			var rect := Rect2(80.0, 80.0, 20.0, 20.0) if corner else THIN_WALL
			var fixture := await _fixture(Vector2.ZERO, rect, stealth)
			var player: Node = fixture.player
			player._start_dash(Vector2.ONE if corner else Vector2.RIGHT)
			for step in range(64):
				if not player.dash_active:
					break
				player._update_dash(1.0 / float(hz))
				var point: Vector2 = player.global_position
				var closest := point.clamp(rect.position, rect.end)
				var near_limit: float = 80.0 - PlayerScript.BODY_RADIUS / (sqrt(2.0) if corner else 1.0)
				if not _assert_true(point.x <= near_limit + 0.1 and point.distance_to(closest) >= PlayerScript.BODY_RADIUS - 0.1, "terrain sweep crossed/embedded: stealth=%s hz=%d corner=%s at %s" % [stealth, hz, corner, point]):
					return false
			if not _assert_true(not player.dash_active and player.global_position.length() > 30.0, "terrain contact must not cancel all approach or leave dash active"):
				return false
			if stealth and not _assert_true(player.collision_layer == 0 and player.collision_mask == 0 and player.player_collision.disabled, "terrain sweep changed disabled stealth body"):
				return false
			await _dispose(fixture)
	for direction: Vector2 in [Vector2.LEFT, Vector2.DOWN]:
		var start := Vector2(80.0 - PlayerScript.BODY_RADIUS, 0.0)
		var fixture := await _fixture(start, THIN_WALL, stealth)
		fixture.player._start_dash(direction)
		_finish_dash(fixture.player)
		var endpoint: Vector2 = fixture.player.global_position
		await _dispose(fixture)
		if not _assert_true(endpoint.distance_to(start + direction * 165.0) <= 0.1, "touching wall must allow outward/parallel dash: %s stealth=%s" % [direction, stealth]):
			return false
	for contact_case in [{"depth": 0.0, "direction": Vector2.RIGHT}, {"depth": 0.01, "direction": Vector2.RIGHT}, {"depth": 0.01, "direction": Vector2.LEFT}]:
		var contact_x := THIN_WALL.position.x - PlayerScript.BODY_RADIUS
		var start := Vector2(contact_x + float(contact_case.depth), 0.0)
		var direction: Vector2 = contact_case.direction
		var fixture := await _fixture(start, THIN_WALL, stealth)
		fixture.player._start_dash(direction)
		_finish_dash(fixture.player)
		var endpoint: Vector2 = fixture.player.global_position
		await _dispose(fixture)
		if direction == Vector2.RIGHT:
			if not _assert_true(endpoint.x <= start.x + 0.001 and endpoint.x >= contact_x - 0.1 and absf(endpoint.y) <= 0.001, "contact/shallow-overlap inward dash increased penetration: depth=%s stealth=%s start=%s end=%s" % [contact_case.depth, stealth, start, endpoint]):
				return false
		elif not _assert_true(endpoint.distance_to(start + direction * 165.0) <= 0.02, "0.01px shallow overlap must allow outward escape: stealth=%s start=%s end=%s" % [stealth, start, endpoint]):
			return false
	var embedded := await _fixture(Vector2(90.0, 0.0), THIN_WALL, stealth)
	embedded.player._start_dash(Vector2.RIGHT)
	_finish_dash(embedded.player)
	var embedded_end: Vector2 = embedded.player.global_position
	await _dispose(embedded)
	return _assert_true(embedded_end.distance_to(Vector2(90.0, 0.0)) <= 0.001, "embedded start must reject unverified motion")

func _test_enemy_sweeps(stealth: bool) -> bool:
	for with_wall in [false, true]:
		var fixture := await _fixture(Vector2.ZERO, THIN_WALL if with_wall else Rect2(), stealth)
		var player: Node = fixture.player
		var enemy := _enemy(fixture, Vector2(48.0 if with_wall else 82.0, 0.0))
		var behind := _enemy(fixture, Vector2(145.0, 0.0))
		await physics_frame
		await physics_frame
		var before: float = enemy.health.current_health
		var behind_before: float = behind.health.current_health
		player._start_dash(Vector2.RIGHT)
		_finish_dash(player)
		# Run no-op updates after completion too: one dash must never deal repeat hits.
		player._update_dash(0.16)
		if not _assert_true(enemy.health.current_health < before, "dash sweep missed an enemy crossed between endpoints"):
			return false
		if not _assert_true(is_equal_approx(before - enemy.health.current_health, player.dash_melee_damage), "one crossed enemy must take exactly one dash hit"):
			return false
		if with_wall:
			if not _assert_true(player.global_position.x <= 63.2 and is_equal_approx(behind.health.current_health, behind_before), "wall stopped movement but damage swept beyond actual path"):
				return false
		elif not _assert_true(absf(player.global_position.x - 165.0) <= 0.01 and is_equal_approx(behind_before - behind.health.current_health, player.dash_melee_damage), "terrain-only sweep must retain passage through enemies"):
			return false
		await _dispose(fixture)
	return true

func _test_timing_and_reset(stealth: bool) -> bool:
	var blocked := await _fixture(Vector2.ZERO, THIN_WALL, stealth)
	var open := await _fixture(Vector2(0.0, 500.0), Rect2(), stealth)
	var player: Node = blocked.player
	var control: Node = open.player
	player._start_dash(Vector2.RIGHT)
	control._start_dash(Vector2.RIGHT)
	# Actual physics entry point, so cooldown/stealth time advance as during play.
	player._physics_process(0.08)
	control._physics_process(0.08)
	if not _assert_true(player.dash_active and is_equal_approx(player.dash_timer, control.dash_timer) and is_equal_approx(player.dash_cooldown_remaining, control.dash_cooldown_remaining), "wall collision changed active duration or cooldown"):
		return false
	var stopped_at: Vector2 = player.global_position
	# Pause cleanup must not unlock the remaining portion of an already blocked dash.
	player.clear_runtime_modifiers()
	control.clear_runtime_modifiers()
	blocked.wall.queue_free()
	await process_frame
	await physics_frame
	player.dash_direction = Vector2.DOWN
	for delta in [0.04, 0.04]:
		player._physics_process(delta)
		control._physics_process(delta)
		if not _assert_true(player.dash_active == control.dash_active and is_equal_approx(player.dash_timer, control.dash_timer) and is_equal_approx(player.dash_cooldown_remaining, control.dash_cooldown_remaining) and player.is_damage_immune() == control.is_damage_immune() and is_equal_approx(player.stealth_remaining, control.stealth_remaining), "wall collision changed remaining skill timing/state"):
			return false
	if not _assert_true(player.global_position.distance_to(stopped_at) <= 0.01, "turning/removing wall resumed the stopped dash"):
		return false
	player.dash_cooldown_remaining = 0.0
	player._start_dash(Vector2.RIGHT)
	_finish_dash(player)
	if not _assert_true(player.global_position.distance_to(stopped_at + Vector2(165.0, 0.0)) <= 0.01, "next dash retained stale wall-stop state"):
		return false
	await _dispose(blocked)
	await _dispose(open)
	return true

func _test_evolved_timing() -> bool:
	var blocked := await _fixture(Vector2.ZERO, THIN_WALL)
	var open := await _fixture(Vector2(0.0, 500.0))
	for player: Node in [blocked.player, open.player]:
		player.activate_build_evolution("rift_overdrive")
		player.set_dash_immunity_active(true)
		player._start_dash(Vector2.RIGHT)
	var elapsed := 0.0
	for delta in [0.08, 0.08, 0.20]:
		elapsed += delta
		var expected_stealth := 0.0 if elapsed < 0.16 else PlayerScript.ASSASSIN_STEALTH_SECONDS - (elapsed - 0.16)
		for player: Node in [blocked.player, open.player]:
			player._physics_process(delta)
			if not _assert_true(player.dash_active == (elapsed < 0.16) and is_equal_approx(player.stealth_remaining, expected_stealth) and is_equal_approx(player.dash_cooldown_remaining, player.get_effective_dash_cooldown() - elapsed), "evolved dash timing differs from expected clock at %.2fs" % elapsed):
				return false
			if not _assert_true(player.is_damage_immune(), "terrain collision/skill completion cleared active dash immunity source"):
				return false
	await _dispose(blocked)
	await _dispose(open)
	return true

func _test_world_bounds(stealth: bool) -> bool:
	var fixture := await _fixture(Vector2.ZERO, Rect2(), stealth)
	var player: Node = fixture.player
	player.world_bounds = Rect2(-50.0, -50.0, 150.0, 150.0)
	player._start_dash(Vector2.ONE)
	_finish_dash(player)
	var endpoint: Vector2 = player.global_position
	await _dispose(fixture)
	var limit := 100.0 - PlayerScript.BODY_RADIUS
	return _assert_true(endpoint.distance_to(Vector2(limit, limit)) <= 0.1, "dash escaped body-inset world bounds")
