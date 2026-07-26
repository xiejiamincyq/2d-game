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
				absf(position.distance_to(player_position) - director.get_portal_spawn_distance()) <= 1.0,
				"portal was not placed half a screen from the player: %s" % position.distance_to(player_position)
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

	var fixture := Node2D.new()
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
	var portal_positions: Array[Vector2] = []
	for active_portal in attack_director.active_portals:
		portal_positions.append(active_portal.global_position)
		if not _assert_true(is_equal_approx(active_portal.burst_duration, 3.0 * attack_director.PORTAL_SPAWN_INTERVAL), "portal generation lifetime was not enemy count x 0.2 seconds"):
			return
	for first_index in range(portal_positions.size()):
		for second_index in range(first_index + 1, portal_positions.size()):
			if not _assert_true(portal_positions[first_index].distance_to(portal_positions[second_index]) >= attack_director.PORTAL_MIN_SEPARATION, "multiple portals overlapped at the same location"):
				return
	attack_director._process(0.5)
	if not _assert_true(attack_enemies.get_child_count() == 0, "enemies spawned before portal warning completed"):
		return
	attack_director._process(0.2)
	if not _assert_true(attack_enemies.get_child_count() == 3, "portal burst did not release exactly one enemy per portal"):
		return
	var first_batch_positions: Dictionary = {}
	for enemy in attack_enemies.get_children():
		first_batch_positions[enemy.global_position] = true
		if not _assert_true(portal_positions.has(enemy.global_position), "enemy did not spawn at a portal center"):
			return
		if not _assert_true(enemy.spawn_impulse_velocity.length() >= attack_director.PORTAL_SPAWN_IMPULSE_SPEED - 0.01, "portal enemy did not receive a random outward launch impulse"):
			return
	if not _assert_true(
		first_batch_positions.size() == attack_enemies.get_child_count(),
		"portal batch stacked multiple CharacterBody2D enemies at identical spawn points"
	):
		return
	var first_batch: Array[Node] = []
	first_batch.assign(attack_enemies.get_children())
	for spawned_enemy in first_batch:
		spawned_enemy.set_physics_process(false)
	await physics_frame
	for enemy_index in range(first_batch.size()):
		var enemy: Node2D = first_batch[enemy_index]
		var enemy_radius := float(enemy.get("body_radius"))
		if not _assert_true(
			attack_director.world_bounds.grow(-enemy_radius).has_point(enemy.global_position),
			"portal enemy body crossed the map boundary at %s" % enemy.global_position
		):
			return
		for other_index in range(enemy_index + 1, first_batch.size()):
			var other: Node2D = first_batch[other_index]
			var required_distance: float = enemy_radius + float(other.get("body_radius")) + float(attack_director.PORTAL_ENEMY_CLEARANCE)
			if not _assert_true(
				enemy.global_position.distance_to(other.global_position) >= required_distance - 0.01,
				"portal enemies began with overlapping collision bodies"
			):
				return
	var impulse_probe: Node2D = first_batch[0]
	var impulse_origin := impulse_probe.global_position
	var expected_impulse: Vector2 = impulse_probe.spawn_impulse_velocity
	impulse_probe.set_physics_process(false)
	impulse_probe._physics_process(0.1)
	var impulse_displacement := impulse_probe.global_position - impulse_origin
	if not _assert_true(impulse_probe.velocity.distance_to(expected_impulse) <= 0.01 and impulse_displacement.length() > 3.0 and impulse_displacement.normalized().dot(expected_impulse.normalized()) > 0.99, "spawn impulse was overwritten by pursuit before its separation window ended (velocity=%s expected=%s moved=%s)" % [impulse_probe.velocity, expected_impulse, impulse_displacement]):
		return
	attack_director._process(0.2)
	if not _assert_true(attack_enemies.get_child_count() == 6, "portal did not wait 0.2 seconds before releasing the next enemy"):
		return
	attack_director._process(0.2)
	if not _assert_true(attack_enemies.get_child_count() == 9, "portal did not release its final enemy at the 0.2-second cadence"):
		return
	for enemy in attack_enemies.get_children():
		if not _assert_true(director.world_bounds.has_point(enemy.global_position), "portal enemy spawned outside the map"):
			return
	for enemy in attack_enemies.get_children():
		enemy.queue_free()
	await process_frame
	attack_director._process(1.3)
	if not _assert_true(attack_director.get_active_portal_count() == 0, "closed portals remained in the wave registry"):
		return

	var hitch_fixture := Node2D.new()
	var hitch_player := Node2D.new()
	var hitch_enemies := Node2D.new()
	var hitch_projectiles := Node2D.new()
	var hitch_portals := Node2D.new()
	var hitch_director: Node = WaveDirectorScript.new()
	root.add_child(hitch_fixture)
	hitch_fixture.add_child(hitch_player)
	hitch_fixture.add_child(hitch_enemies)
	hitch_fixture.add_child(hitch_projectiles)
	hitch_fixture.add_child(hitch_portals)
	hitch_fixture.add_child(hitch_director)
	hitch_director.set_process(false)
	hitch_director.world_bounds = Rect2(-1400, -900, 2800, 1800)
	hitch_director.setup(hitch_player, hitch_enemies, hitch_projectiles, hitch_portals)
	hitch_director.spawn_queue.assign([0, 0, 0, 0, 0, 0])
	if not _assert_true(hitch_director.begin_prepared_wave(), "large-delta portal fixture did not start"):
		return
	hitch_director._process(1.1)
	if not _assert_true(hitch_enemies.get_child_count() == 6 and hitch_director.get_active_portal_count() == 0, "a frame hitch closed portals before every queued enemy was emitted"):
		return

	var transformed_fixture := Node2D.new()
	var transformed_player := Node2D.new()
	var transformed_enemies := Node2D.new()
	var transformed_projectiles := Node2D.new()
	var transformed_director: Node = WaveDirectorScript.new()
	root.add_child(transformed_fixture)
	transformed_fixture.add_child(transformed_player)
	transformed_fixture.add_child(transformed_enemies)
	transformed_fixture.add_child(transformed_projectiles)
	transformed_fixture.add_child(transformed_director)
	transformed_enemies.position = Vector2(170.0, -260.0)
	transformed_director.set_process(false)
	transformed_director.world_bounds = Rect2(-1400, -900, 2800, 1800)
	transformed_director.player = transformed_player
	transformed_director.enemy_parent = transformed_enemies
	transformed_director.projectile_parent = transformed_projectiles
	transformed_director.wave_index = 0
	var requested_spawn := Vector2(-320.0, 410.0)
	transformed_director._spawn_enemy_at(0, requested_spawn)
	var transformed_enemy: Node2D = transformed_enemies.get_child(0)
	if not _assert_true(
		transformed_enemy.global_position.distance_to(requested_spawn) <= 0.01,
		"enemy spawn world position drifted under a transformed parent: %s -> %s" % [requested_spawn, transformed_enemy.global_position]
	):
		return

	portal.queue_free()
	director.queue_free()
	fixture.queue_free()
	hitch_fixture.queue_free()
	transformed_fixture.queue_free()
	await process_frame
	print("TEST PASS: PortalTest %d" % assertions)
	quit(0)
