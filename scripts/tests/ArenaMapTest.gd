extends SceneTree

const ArenaLayoutScript = preload("res://scripts/world/ArenaLayout.gd")

const BOUNDS := Rect2(-1400.0, -900.0, 2800.0, 1800.0)
const CENTER_SAFE_RECT := Rect2(-300.0, -220.0, 600.0, 440.0)

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: ArenaMapTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var first := ArenaLayoutScript.new()
	root.add_child(first)
	first.generate(BOUNDS, 20260831)
	await process_frame
	var first_descriptors: Array[Dictionary] = first.get_obstacle_descriptors()
	if not _assert_true(first_descriptors.size() >= 9 and first_descriptors.size() <= 13, "obstacle density left the arena empty or overcrowded"):
		return

	for descriptor in first_descriptors:
		var rect: Rect2 = descriptor["rect"]
		if not _assert_true(BOUNDS.grow(-72.0).encloses(rect), "an obstacle escaped the arena margin"):
			return
		if not _assert_true(not rect.intersects(CENTER_SAFE_RECT), "an obstacle blocked the player start safe zone"):
			return

	var second := ArenaLayoutScript.new()
	root.add_child(second)
	second.generate(BOUNDS, 20260831)
	await process_frame
	if not _assert_true(first_descriptors == second.get_obstacle_descriptors(), "the same map seed produced a different layout"):
		return

	var third := ArenaLayoutScript.new()
	root.add_child(third)
	third.generate(BOUNDS, 20260832)
	await process_frame
	if not _assert_true(first_descriptors != third.get_obstacle_descriptors(), "different map seeds produced the same layout"):
		return

	var route_targets := [
		Vector2(-1120.0, 0.0),
		Vector2(1120.0, 0.0),
		Vector2(0.0, -680.0),
		Vector2(0.0, 680.0),
	]
	for target in route_targets:
		if not _assert_true(first.is_reachable(Vector2.ZERO, target, 26.0), "a generated obstacle layout sealed an arena route"):
			return

	var collision_count := 0
	for obstacle in first.get_children():
		if obstacle is StaticBody2D and obstacle.get_node_or_null("CollisionShape2D") != null:
			collision_count += 1
	if not _assert_true(collision_count == first_descriptors.size(), "visual obstacles and collision bodies diverged"):
		return

	var sweep := ArenaLayoutScript.new()
	root.add_child(sweep)
	for seed_value in range(32):
		sweep.generate(BOUNDS, seed_value)
		var descriptors := sweep.get_obstacle_descriptors()
		if not _assert_true(descriptors.size() >= 9 and descriptors.size() <= 13, "seed %d produced invalid obstacle density" % seed_value):
			return
		for target in route_targets:
			if not _assert_true(sweep.is_reachable(Vector2.ZERO, target, 26.0), "seed %d sealed an arena route" % seed_value):
				return

	first.queue_free()
	second.queue_free()
	third.queue_free()
	sweep.queue_free()
	await process_frame
	print("TEST PASS: ArenaMapTest %d" % assertions)
	quit(0)
