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

	portal.queue_free()
	director.queue_free()
	await process_frame
	print("TEST PASS: PortalTest %d" % assertions)
	quit(0)
