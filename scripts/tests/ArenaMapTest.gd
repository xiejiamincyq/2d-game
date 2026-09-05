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
	var shifted_centers := 0
	for descriptor in first_descriptors:
		if not ArenaLayoutScript.CANDIDATE_CENTERS.has(Rect2(descriptor["rect"]).get_center()):
			shifted_centers += 1
	if not _assert_true(shifted_centers == first_descriptors.size(), "new maps still place obstacles at fixed template centers"):
		return
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

	var route_obstacle: Dictionary = first_descriptors[0]
	for descriptor in first_descriptors:
		var center: Vector2 = Rect2(descriptor["rect"]).get_center()
		if absf(center.x) < 900.0 and absf(center.y) < 500.0:
			route_obstacle = descriptor
			break
	var route_rect: Rect2 = route_obstacle["rect"]
	var route_position := route_rect.get_center() + Vector2(-route_rect.size.x * 0.5 - 110.0, 0.0)
	var route_target := route_rect.get_center() + Vector2(route_rect.size.x * 0.5 + 110.0, 0.0)
	var initial_direction: Vector2 = first.get_navigation_direction(route_position, route_target, 26.0)
	if not _assert_true(initial_direction.length() > 0.9 and absf(initial_direction.y) > 0.1, "navigation pointed directly into a blocking obstacle"):
		return
	for step in range(40):
		if route_position.distance_to(route_target) <= 72.0:
			break
		var direction: Vector2 = first.get_navigation_direction(route_position, route_target, 26.0)
		route_position += direction * 48.0
		if not _assert_true(first.is_position_walkable(route_position, 26.0), "navigation entered obstacle space on step %d" % step):
			return
	if not _assert_true(route_position.distance_to(route_target) <= 72.0, "navigation failed to route around an obstacle"):
		return

	var blocked_center := route_rect.get_center()
	var resolved_spawn: Vector2 = first.resolve_spawn_position(blocked_center, 26.0)
	if not _assert_true(resolved_spawn != blocked_center and first.is_position_walkable(resolved_spawn, 26.0), "blocked spawn was not moved to a safe position"):
		return
	var avoidance_start := route_rect.get_center() + Vector2(-route_rect.size.x * 0.5 - 48.0, 0.0)
	var avoidance_direction: Vector2 = first.get_avoidance_direction(avoidance_start, Vector2.RIGHT, 26.0)
	if not _assert_true(avoidance_direction.length() > 0.9 and absf(avoidance_direction.y) > 0.1, "local avoidance kept steering into a nearby obstacle"):
		return

	var sweep := ArenaLayoutScript.new()
	root.add_child(sweep)
	sweep.generate(BOUNDS, 20260831, 1)
	for descriptor in sweep.get_obstacle_descriptors():
		if not _assert_true(ArenaLayoutScript.CANDIDATE_CENTERS.has(Rect2(descriptor["rect"]).get_center()), "legacy generator moved a saved obstacle"):
			return
	for seed_value in range(128):
		sweep.generate(BOUNDS, seed_value)
		var descriptors := sweep.get_obstacle_descriptors()
		if not _assert_true(descriptors.size() >= 9 and descriptors.size() <= 13, "seed %d produced invalid obstacle density" % seed_value):
			return
		for i in range(descriptors.size()):
			var rect: Rect2 = descriptors[i]["rect"]
			if not _assert_true(BOUNDS.grow(-72.0).encloses(rect) and not rect.intersects(CENTER_SAFE_RECT), "seed %d violated arena/start margins" % seed_value):
				return
			for j in range(i):
				if not _assert_true(not Rect2(descriptors[j]["rect"]).grow(44.0).intersects(rect), "seed %d overlapped obstacle footprints" % seed_value):
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
