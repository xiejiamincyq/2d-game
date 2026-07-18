extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: RateTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var contract_player: Node = PlayerScript.new()
	root.add_child(contract_player)
	await process_frame
	contract_player.set_physics_process(false)
	contract_player.fire_rate = 19.5
	if not _assert_true(
		is_equal_approx(contract_player.get_effective_fire_rate(), 19.5),
		"base fire rate was not returned as the effective rate"
	):
		return
	contract_player.set_overdrive_active(true)
	contract_player.set_overdrive_active(true)
	if not _assert_true(
		is_equal_approx(contract_player.get_effective_fire_rate(), 39.0),
		"repeated overdrive activation stacked the fire-rate modifier"
	):
		return
	contract_player.set_overdrive_active(false)
	if not _assert_true(
		is_equal_approx(contract_player.get_effective_fire_rate(), 19.5),
		"ending overdrive did not restore the permanent fire rate"
	):
		return
	contract_player.set_fire_rate_modifier(&"dash_overclock", 1.5)
	contract_player.set_fire_rate_modifier(&"dash_overclock", 1.5)
	if not _assert_true(
		is_equal_approx(contract_player.get_effective_fire_rate(), 29.25),
		"reapplying one temporary fire-rate source accumulated"
	):
		return
	contract_player.clear_fire_rate_modifier(&"dash_overclock")
	if not _assert_true(
		is_equal_approx(contract_player.get_effective_fire_rate(), 19.5),
		"clearing a temporary fire-rate source changed the permanent value"
	):
		return
	contract_player.queue_free()
	await process_frame

	var counts: Array[int] = []
	for hz in [30, 60, 120]:
		Input.action_release("fire")
		var player: Node = PlayerScript.new()
		root.add_child(player)
		await process_frame
		player.set_physics_process(false)
		player.fire_rate = 19.5
		player.fire_timer = 0.0
		var counter := [0]
		player.fired.connect(func(shot: Node) -> void:
			counter[0] += 1
			shot.free()
		)
		Input.action_press("fire")
		var delta := 1.0 / float(hz)
		for frame in range(hz * 10):
			player._physics_process(delta)
		counts.append(counter[0])
		Input.action_release("fire")
		player.queue_free()
		await process_frame

	var minimum: int = counts.min()
	var maximum: int = counts.max()
	if not _assert_true(maximum - minimum <= 1, "30/60/120 Hz shot counts diverged: %s" % [counts]):
		return
	for count in counts:
		if not _assert_true(count >= 194 and count <= 196, "shot count %d was not near 195" % count):
			return
	print("TEST PASS: RateTest %d" % assertions)
	quit(0)
