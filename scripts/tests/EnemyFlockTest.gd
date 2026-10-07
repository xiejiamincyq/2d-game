extends SceneTree

# Behavioral regression: neighbor motion must matter independently of contact,
# and a slow large body must not become an impassable moving wall.
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const ArenaScript = preload("res://scripts/world/ArenaLayout.gd")
const STEP := 1.0 / 60.0
const BOUNDS := Rect2(-1400.0, -900.0, 2800.0, 1800.0)

var assertions := 0
var failures := 0
var observations: Dictionary = {}

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAIL: EnemyFlockTest: " + message)

func _enemy(kind: int, position_value: Vector2, target: Node2D, parent: Node2D) -> Node:
	var enemy := EnemyScript.new()
	enemy.setup(kind, 0, parent, target)
	enemy.position = position_value
	enemy.world_bounds = BOUNDS
	parent.add_child(enemy)
	# Disable after entering the tree: script callback registration on entry
	# otherwise re-enables physics and would double-drive the test subject.
	enemy.set_physics_process(false)
	return enemy

func _fixture() -> Dictionary:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var arena := ArenaScript.new()
	fixture.add_child(arena)
	arena.generate(BOUNDS, 426363786)
	var target := Node2D.new()
	target.position = Vector2(680.0, 28.0)
	fixture.add_child(target)
	return {"fixture": fixture, "arena": arena, "target": target}

func _shape_radius(enemy: Node) -> float:
	for child in enemy.get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			return child.shape.radius
	return -1.0

func _sample_neighbor_motion(neighbor_velocity: Vector2) -> Vector2:
	var context := _fixture()
	var fixture: Node2D = context["fixture"]
	var arena: Node = context["arena"]
	var target: Node2D = context["target"]
	var subject := _enemy(EnemyScript.EnemyKind.SCRAPPER, Vector2(-152.0, 28.0), target, fixture)
	# Fixed, symmetric positions; every pair is farther apart than their real
	# radii. Only the observed neighbor velocity differs across fixtures.
	var neighbors: Array[Node] = [subject]
	for offset in [Vector2(42.0, -48.0), Vector2(42.0, 48.0), Vector2(78.0, 0.0)]:
		var neighbor := _enemy(EnemyScript.EnemyKind.SCRAPPER, subject.position + offset, target, fixture)
		neighbor.velocity = neighbor_velocity
		neighbors.append(neighbor)
	subject.set_neighbor_provider(func() -> Array[Node]: return neighbors)
	subject.set_arena_navigation(arena)
	await physics_frame
	_check(arena.get_obstacle_descriptors().size() >= 9, "neighbor test did not use actual generated arena")
	_check(arena.is_position_walkable(subject.position, subject.body_radius), "neighbor subject started in terrain")
	subject._physics_process(STEP)
	var measured: Vector2 = subject.velocity
	_check(subject.get_slide_collision_count() == 0, "neighbor steering sample was contaminated by body/terrain collision")
	_check(is_equal_approx(subject.speed, 211.5) and is_equal_approx(subject.health.max_health, 36.0) and is_equal_approx(_shape_radius(subject), 14.0), "flock changed Scrapper type speed, health, or collider")
	fixture.queue_free()
	await process_frame
	await process_frame
	return measured

func _blocked_large_body(blocker_speed: float) -> void:
	var context := _fixture()
	var fixture: Node2D = context["fixture"]
	var arena: Node = context["arena"]
	var target: Node2D = context["target"]
	var subject := _enemy(EnemyScript.EnemyKind.SCRAPPER, Vector2(-152.0, 28.0), target, fixture)
	var blocker := _enemy(EnemyScript.EnemyKind.BRUISER, Vector2(-24.0, 28.0), target, fixture)
	var neighbors: Array[Node] = [subject, blocker]
	subject.set_neighbor_provider(func() -> Array[Node]: return neighbors)
	subject.set_arena_navigation(arena)
	blocker.set_arena_navigation(arena)
	blocker.velocity = Vector2(blocker_speed, 0.0)
	await physics_frame
	_check(arena.is_position_walkable(target.position, 32.0), "blocked-route target was not walkable")
	_check(arena.is_reachable(subject.position, target.position, subject.body_radius), "blocked-route fixture had no real arena path")
	# Confirm the exact real CharacterBody collider blocks direct movement,
	# without deleting colliders or shrinking the Bruiser to make passage easy.
	var direct_collision: KinematicCollision2D = subject.move_and_collide(Vector2(128.0, 0.0), true)
	_check(direct_collision != null and direct_collision.get_collider() == blocker, "large enemy did not physically block the intended direct route")
	var initial: Vector2 = subject.position
	var early_offset := 0.0
	var early_separation := 0.0
	var minimum_clearance := INF
	var contact_frames := 0
	var terrain_violations := 0
	for frame in range(300):
		await physics_frame
		# A stationary/slow blocker is intentional and remains a real collider.
		# Its velocity is its actual simulated motion, not a desired-heading stub.
		if blocker_speed > 0.0:
			blocker.move_and_slide()
		subject._physics_process(STEP)
		var clearance: float = subject.position.distance_to(blocker.position) - subject.body_radius - blocker.body_radius
		minimum_clearance = minf(minimum_clearance, clearance)
		if subject.get_slide_collision_count() > 0:
			contact_frames += 1
		if not arena.is_position_walkable(subject.position, subject.body_radius):
			terrain_violations += 1
		if frame == 8:
			early_offset = absf(subject.position.y - initial.y)
			early_separation = clearance
	var row := {
		"blocker_motion_px_s": blocker_speed,
		"early_side_offset_px_at_0_15_s": early_offset,
		"early_surface_clearance_px": early_separation,
		"subject_final": [subject.position.x, subject.position.y],
		"blocker_final": [blocker.position.x, blocker.position.y],
		"minimum_surface_clearance_px": minimum_clearance,
		"contact_frames": contact_frames,
		"terrain_violations": terrain_violations,
		"subject_final_velocity": [subject.velocity.x, subject.velocity.y],
	}
	observations["blocker_%s" % blocker_speed] = row
	_check(early_offset >= 3.0 and early_separation >= 24.0, "small enemy did not select a side before reaching Bruiser contact: %s" % row)
	_check(subject.position.x > blocker.position.x + blocker.body_radius + subject.body_radius + 16.0, "small enemy did not overtake the large body within 5 seconds: %s" % row)
	_check(minimum_clearance >= -0.5 and terrain_violations == 0, "overtaking penetrated real body or generated terrain: %s" % row)
	_check(is_equal_approx(subject.speed, 211.5) and is_equal_approx(blocker.speed, 59.4) and is_equal_approx(subject.health.max_health, 36.0) and is_equal_approx(blocker.health.max_health, 300.0) and is_equal_approx(_shape_radius(blocker), 24.0), "overtaking changed type speed, health, or large hitbox")
	fixture.queue_free()
	await process_frame
	await process_frame

func _initialize() -> void:
	var up: Vector2 = await _sample_neighbor_motion(Vector2(120.0, -120.0))
	var down: Vector2 = await _sample_neighbor_motion(Vector2(120.0, 120.0))
	var slow: Vector2 = await _sample_neighbor_motion(Vector2(30.0, 0.0))
	var fast: Vector2 = await _sample_neighbor_motion(Vector2(200.0, 0.0))
	observations["velocity_samples"] = {"up": [up.x, up.y], "down": [down.x, down.y], "slow": [slow.x, slow.y], "fast": [fast.x, fast.y]}
	_check(down.y - up.y >= 8.0, "identical noncontact neighbor positions with opposite motion did not influence steering: %s" % observations["velocity_samples"])
	_check(fast.length() - slow.length() >= 4.0, "neighbor speed did not influence movement speed: %s" % observations["velocity_samples"])
	_check(slow.length() >= 211.5 * 0.65 and fast.length() <= 211.5 * 1.05, "neighbor speed destroyed bounded Scrapper pursuit capability")
	await _blocked_large_body(0.0)
	await _blocked_large_body(20.0)
	print("EnemyFlockTest observations: " + JSON.stringify(observations))
	if failures > 0:
		print("TEST FAILED: EnemyFlockTest %d assertions, %d failures" % [assertions, failures])
		quit(1)
	else:
		print("TEST PASS: EnemyFlockTest %d" % assertions)
		quit(0)
