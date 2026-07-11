extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: DamageTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var player: Node = PlayerScript.new()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.health.set_process(false)
	player.shield = 20.0

	var accepted: Array[Variant] = []
	accepted.append(player.take_damage(8.0))
	for repeat_index in range(4):
		player.health._process(0.1)
		var before_hit: float = player.health.invulnerable_time
		accepted.append(player.take_damage(8.0))
		if repeat_index < 3 and not _assert_true(
			is_equal_approx(player.health.invulnerable_time, before_hit),
			"a rejected hit refreshed the invulnerability timer"
		):
			return

	if not _assert_true(accepted == [true, false, false, false, true], "accepted-hit sequence was %s" % [accepted]):
		return
	if not _assert_true(is_equal_approx(player.shield, 4.0), "shield was %.2f instead of 4.0" % player.shield):
		return
	if not _assert_true(is_equal_approx(player.health.current_health, 100.0), "health changed while shield covered accepted hits"):
		return

	player.queue_free()
	await process_frame
	print("TEST PASS: DamageTest %d" % assertions)
	quit(0)
