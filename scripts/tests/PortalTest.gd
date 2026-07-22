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
	for enemy in attack_enemies.get_children():
		enemy.queue_free()
	await process_frame
	attack_director._process(1.3)
	if not _assert_true(attack_director.get_active_portal_count() == 0, "closed portals remained in the wave registry"):
		return

	portal.queue_free()
	director.queue_free()
	fixture.queue_free()
	await process_frame
	print("TEST PASS: PortalTest %d" % assertions)
	quit(0)
