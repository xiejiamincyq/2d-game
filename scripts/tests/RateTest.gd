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
