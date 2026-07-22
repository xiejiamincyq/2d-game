extends SceneTree

const WaveDirectorScript = preload("res://scripts/systems/WaveDirector.gd")
const SpawnPortalScript = preload("res://scripts/world/SpawnPortal.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PortalTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var director: Node = WaveDirectorScript.new()
	root.add_child(director)
	director.set_process(false)
	director.world_bounds = Rect2(-1400, -900, 2800, 1800)
	var playable: Rect2 = director.world_bounds.grow(-director.PORTAL_WORLD_MARGIN)
	var players: Array[Vector2] = [
		Vector2.ZERO,
		playable.position,
		Vector2(playable.end.x, playable.position.y),
		playable.end,
		Vector2(playable.position.x, playable.end.y),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x504f5254
	for player_position in players:
		for sample_index in range(256):
			var position: Vector2 = director.sample_portal_position(player_position, rng)
			if not _assert_true(playable.has_point(position), "portal left playable bounds at %s" % position):
				return
			if not _assert_true(
				position.distance_to(player_position) >= director.PORTAL_MIN_SAFE_DISTANCE,
				"portal spawned inside the %dpx safety ring" % director.PORTAL_MIN_SAFE_DISTANCE
			):
				return

	var portal: Node = SpawnPortalScript.new()
	root.add_child(portal)
	portal.configure(Vector2(320.0, -140.0), 0.2, 0.3)
	if not _assert_true(portal.state == portal.State.WARNING and portal.visible, "portal did not begin in visible warning state"):
		return
	portal.advance(0.2)
	if not _assert_true(portal.state == portal.State.BURST, "portal warning did not advance to burst"):
		return
	portal.advance(0.3)
	if not _assert_true(portal.state == portal.State.CLOSED and not portal.visible, "portal burst did not close deterministically"):
		return
	if not _assert_true(not portal.advance(1.0), "closed portal advanced a second time"):
		return

	var fixture := Node.new()
	var attack_player := Node2D.new()
	var attack_enemies := Node2D.new()
	var attack_projectiles := Node2D.new()
	var attack_portals := Node2D.new()
	var attack_director: Node = WaveDirectorScript.new()
	root.add_child(fixture)
	fixture.add_child(attack_player)
	fixture.add_child(attack_enemies)
	fixture.add_child(attack_projectiles)
	fixture.add_child(attack_portals)
	fixture.add_child(attack_director)
	attack_director.set_process(false)
	attack_director.world_bounds = Rect2(-1400, -900, 2800, 1800)
	attack_director.setup(attack_player, attack_enemies, attack_projectiles, attack_portals)
	attack_director.spawn_queue.assign([0, 0, 0, 0, 0, 0, 0, 0, 0])
	if not _assert_true(attack_director.begin_prepared_wave(), "portal attack did not begin a prepared wave"):
		return
	if not _assert_true(attack_director.get_active_portal_count() == 3, "wave did not open three portal warnings"):
		return
	attack_director._process(0.5)
	if not _assert_true(attack_enemies.get_child_count() == 0, "enemies spawned before portal warning completed"):
		return
	attack_director._process(0.3)
	if not _assert_true(attack_enemies.get_child_count() == 6, "portal burst did not release the first paced enemy batch"):
		return
	attack_director._process(0.1)
	if not _assert_true(attack_enemies.get_child_count() == 9, "portal burst did not release later enemy batches"):
		return
	for enemy in attack_enemies.get_children():
		if not _assert_true(director.world_bounds.has_point(enemy.global_position), "portal enemy spawned outside the map"):
			return
	# Portal and enemy layers may be nested under transformed world nodes in a
	# gameplay scene. Their positions are world-space contracts, not local ones.
	# This recreates the reported edge-flight symptom: assigning a global point
	# before reparenting offsets the node and sends its first pursuit vector in
	# the wrong direction.
	var transformed_world := Node2D.new()
	transformed_world.position = Vector2(260.0, -170.0)
	var transformed_player := Node2D.new()
	transformed_player.global_position = Vector2(120.0, 80.0)
	var transformed_enemies := Node2D.new()
	var transformed_projectiles := Node2D.new()
	var transformed_portals := Node2D.new()
	var transformed_director: Node = WaveDirectorScript.new()
	root.add_child(transformed_world)
	transformed_world.add_child(transformed_player)
	transformed_world.add_child(transformed_enemies)
	transformed_world.add_child(transformed_projectiles)
	transformed_world.add_child(transformed_portals)
	root.add_child(transformed_director)
	transformed_director.set_process(false)
	transformed_director.world_bounds = Rect2(-1400, -900, 2800, 1800)
	transformed_director.player = transformed_player
	transformed_director.enemy_parent = transformed_enemies
	transformed_director.projectile_parent = transformed_projectiles
	transformed_director.portal_parent = transformed_portals
	transformed_director.wave_index = 0
	var intended_enemy_position := Vector2(-315.0, 395.0)
	var portal_seed := 0x51A7
	var expected_portal_rng := RandomNumberGenerator.new()
	expected_portal_rng.seed = portal_seed
	var expected_portal_positions: Array[Vector2] = []
	for index in range(3):
		expected_portal_positions.append(transformed_director.sample_portal_position(transformed_player.global_position, expected_portal_rng))
	transformed_director.spawn_rng.seed = portal_seed
	transformed_director.spawn_queue.assign([0, 0, 0, 0, 0, 0, 0, 0, 0])
	transformed_director.prepared_wave = true
	if not _assert_true(transformed_director.begin_prepared_wave(), "transformed portal attack did not begin"):
		return
	for index in range(transformed_portals.get_child_count()):
		var transformed_portal: Node2D = transformed_portals.get_child(index)
		if not _assert_true(transformed_portal.global_position.distance_to(expected_portal_positions[index]) <= 0.01, "portal global spawn point shifted after entering a transformed layer"):
			return
	transformed_director._spawn_enemy_at(0, intended_enemy_position)
	var transformed_enemy: Node2D = transformed_enemies.get_child(0)
	if not _assert_true(transformed_enemy.global_position.distance_to(intended_enemy_position) <= 0.01, "enemy global spawn point shifted after entering a transformed layer"):
		return
	for enemy in attack_enemies.get_children():
		enemy.queue_free()
	await process_frame
	attack_director._process(1.3)
	if not _assert_true(attack_director.get_active_portal_count() == 0, "closed portals remained in the wave registry"):
		return

	portal.queue_free()
	director.queue_free()
	fixture.queue_free()
	transformed_world.queue_free()
	transformed_director.queue_free()
	await process_frame
	print("TEST PASS: PortalTest %d" % assertions)
	quit(0)
