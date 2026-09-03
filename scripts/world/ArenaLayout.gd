extends Node2D
class_name ArenaLayout

const ArenaObstacleScript = preload("res://scripts/world/ArenaObstacle.gd")

const GRID_CELL := 64.0
const CENTER_SAFE_RECT := Rect2(-300.0, -220.0, 600.0, 440.0)
const EDGE_MARGIN := 72.0
const OBSTACLE_GAP := 44.0
const ROUTE_RADIUS := 26.0
const CANDIDATE_CENTERS := [
	Vector2(-1080.0, -570.0), Vector2(-720.0, -540.0), Vector2(-280.0, -590.0),
	Vector2(280.0, -590.0), Vector2(720.0, -540.0), Vector2(1080.0, -570.0),
	Vector2(-1120.0, -170.0), Vector2(-760.0, -130.0), Vector2(-470.0, -380.0),
	Vector2(470.0, 380.0), Vector2(760.0, 130.0), Vector2(1120.0, 170.0),
	Vector2(-1080.0, 570.0), Vector2(-720.0, 540.0), Vector2(-280.0, 590.0),
	Vector2(280.0, 590.0), Vector2(720.0, 540.0), Vector2(1080.0, 570.0),
	Vector2(-560.0, 250.0), Vector2(560.0, -250.0),
	Vector2(-850.0, 300.0), Vector2(850.0, -300.0),
]
const OBSTACLE_TYPES := [
	{"kind": &"planter", "size": Vector2(150.0, 110.0)},
	{"kind": &"greenhouse", "size": Vector2(210.0, 120.0)},
	{"kind": &"tank", "size": Vector2(120.0, 120.0)},
	{"kind": &"pipe", "size": Vector2(220.0, 76.0)},
]

var world_bounds := Rect2(-1400.0, -900.0, 2800.0, 1800.0)
var map_seed := 0
var obstacle_descriptors: Array[Dictionary] = []
var flow_fields: Dictionary = {}

func generate(bounds: Rect2, seed_value: int) -> void:
	_clear_obstacles()
	world_bounds = bounds
	map_seed = seed_value
	for attempt in range(24):
		obstacle_descriptors = _build_descriptors(seed_value + attempt * 104729)
		if _required_routes_are_connected():
			break
	if not _required_routes_are_connected():
		push_error("ArenaLayout could not generate a connected obstacle layout")
		obstacle_descriptors.clear()
	_spawn_obstacles()

func get_obstacle_descriptors() -> Array[Dictionary]:
	return obstacle_descriptors.duplicate(true)

func is_position_walkable(point: Vector2, radius: float = ROUTE_RADIUS) -> bool:
	if not world_bounds.grow(-radius).has_point(point):
		return false
	for descriptor in obstacle_descriptors:
		if Rect2(descriptor["rect"]).grow(radius).has_point(point):
			return false
	return true

func resolve_spawn_position(point: Vector2, radius: float = ROUTE_RADIUS) -> Vector2:
	var clamped := point.clamp(world_bounds.position + Vector2.ONE * radius, world_bounds.end - Vector2.ONE * radius)
	if is_position_walkable(clamped, radius):
		return clamped
	var start := _world_to_cell(clamped)
	var frontier: Array[Vector2i] = [start]
	var visited := {start: true}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var candidate := _cell_to_world(current)
		if is_position_walkable(candidate, radius):
			return candidate
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			if visited.has(next) or not world_bounds.has_point(_cell_to_world(next)):
				continue
			visited[next] = true
			frontier.append(next)
	return Vector2.ZERO

func get_navigation_direction(from: Vector2, target: Vector2, radius: float = ROUTE_RADIUS) -> Vector2:
	if from.distance_squared_to(target) <= 1.0:
		return Vector2.ZERO
	var radius_bucket := 32 if radius <= 30.0 else 56
	var resolved_target := resolve_spawn_position(target, float(radius_bucket))
	var goal := _world_to_cell(resolved_target)
	var cache: Dictionary = flow_fields.get(radius_bucket, {})
	if cache.get("goal", Vector2i(-99999, -99999)) != goal:
		cache = {"goal": goal, "distances": _build_flow_field(goal, float(radius_bucket))}
		flow_fields[radius_bucket] = cache
	var distances: Dictionary = cache["distances"]
	var current := _world_to_cell(from)
	if current == goal:
		return (resolved_target - from).normalized()
	var current_distance := int(distances.get(current, 1 << 28))
	if current_distance >= 1 << 28:
		return (resolved_target - from).normalized()
	var direct := (resolved_target - from).normalized()
	var best := current
	var best_distance := current_distance
	var best_alignment := -2.0
	for direction in [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]:
		var next: Vector2i = current + direction
		if not distances.has(next):
			continue
		if direction.x != 0 and direction.y != 0:
			if not _is_cell_walkable(current + Vector2i(direction.x, 0), float(radius_bucket)) or not _is_cell_walkable(current + Vector2i(0, direction.y), float(radius_bucket)):
				continue
		var next_distance := int(distances[next])
		var alignment := Vector2(direction).normalized().dot(direct)
		if next_distance < best_distance or (next_distance == best_distance and alignment > best_alignment):
			best = next
			best_distance = next_distance
			best_alignment = alignment
	if best == current:
		return Vector2.ZERO
	return (_cell_to_world(best) - from).normalized()

func get_avoidance_direction(from: Vector2, desired: Vector2, radius: float = ROUTE_RADIUS) -> Vector2:
	if desired == Vector2.ZERO:
		return Vector2.ZERO
	var forward := desired.normalized()
	var lookahead := radius + 72.0
	for angle in [0.0, PI * 0.25, -PI * 0.25, PI * 0.5, -PI * 0.5, PI]:
		var candidate := forward.rotated(angle)
		if _direction_is_clear(from, candidate, lookahead, radius):
			return candidate
	return Vector2.ZERO

func is_reachable(from: Vector2, target: Vector2, radius: float = ROUTE_RADIUS) -> bool:
	var start := _world_to_cell(from)
	var goal := _world_to_cell(target)
	if not _is_cell_walkable(start, radius) or not _is_cell_walkable(goal, radius):
		return false
	var frontier: Array[Vector2i] = [start]
	var visited := {start: true}
	var directions: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			return true
		for direction in directions:
			var next: Vector2i = current + direction
			if visited.has(next) or not _is_cell_walkable(next, radius):
				continue
			if direction.x != 0 and direction.y != 0:
				if not _is_cell_walkable(current + Vector2i(direction.x, 0), radius) or not _is_cell_walkable(current + Vector2i(0, direction.y), radius):
					continue
			visited[next] = true
			frontier.append(next)
	return false

func _build_descriptors(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var centers: Array = CANDIDATE_CENTERS.duplicate()
	_shuffle_with_rng(centers, rng)
	var desired_count := 9 + posmod(seed_value, 5)
	var descriptors: Array[Dictionary] = []
	for center in centers:
		var type_data: Dictionary = OBSTACLE_TYPES[rng.randi_range(0, OBSTACLE_TYPES.size() - 1)]
		var rect := Rect2(Vector2(center) - Vector2(type_data["size"]) * 0.5, Vector2(type_data["size"]))
		if not world_bounds.grow(-EDGE_MARGIN).encloses(rect) or rect.intersects(CENTER_SAFE_RECT):
			continue
		var overlaps := false
		for existing in descriptors:
			if Rect2(existing["rect"]).grow(OBSTACLE_GAP).intersects(rect):
				overlaps = true
				break
		if overlaps:
			continue
		descriptors.append({"rect": rect, "kind": type_data["kind"]})
		if descriptors.size() >= desired_count:
			break
	return descriptors

func _shuffle_with_rng(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, i)
		var value: Variant = values[i]
		values[i] = values[swap_index]
		values[swap_index] = value

func _required_routes_are_connected() -> bool:
	for target in [Vector2(-1120.0, 0.0), Vector2(1120.0, 0.0), Vector2(0.0, -680.0), Vector2(0.0, 680.0)]:
		if not is_reachable(Vector2.ZERO, target, ROUTE_RADIUS):
			return false
	return true

func _spawn_obstacles() -> void:
	for descriptor in obstacle_descriptors:
		var obstacle := ArenaObstacleScript.new()
		obstacle.setup(descriptor["rect"], descriptor["kind"])
		add_child(obstacle)

func _clear_obstacles() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	obstacle_descriptors.clear()
	flow_fields.clear()

func _build_flow_field(goal: Vector2i, radius: float) -> Dictionary:
	var distances: Dictionary = {}
	if not _is_cell_walkable(goal, radius):
		return distances
	var frontier: Array[Vector2i] = [goal]
	distances[goal] = 0
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var next_distance := int(distances[current]) + 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			if distances.has(next) or not _is_cell_walkable(next, radius):
				continue
			distances[next] = next_distance
			frontier.append(next)
	return distances

func _direction_is_clear(from: Vector2, direction: Vector2, distance: float, radius: float) -> bool:
	for fraction in [0.35, 0.7, 1.0]:
		if not is_position_walkable(from + direction * distance * fraction, radius):
			return false
	return true

func _world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(
		floori((point.x - world_bounds.position.x) / GRID_CELL),
		floori((point.y - world_bounds.position.y) / GRID_CELL)
	)

func _cell_to_world(cell: Vector2i) -> Vector2:
	return world_bounds.position + (Vector2(cell) + Vector2.ONE * 0.5) * GRID_CELL

func _is_cell_walkable(cell: Vector2i, radius: float) -> bool:
	var point := _cell_to_world(cell)
	return is_position_walkable(point, radius)
