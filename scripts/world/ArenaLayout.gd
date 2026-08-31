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

func _world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(
		floori((point.x - world_bounds.position.x) / GRID_CELL),
		floori((point.y - world_bounds.position.y) / GRID_CELL)
	)

func _cell_to_world(cell: Vector2i) -> Vector2:
	return world_bounds.position + (Vector2(cell) + Vector2.ONE * 0.5) * GRID_CELL

func _is_cell_walkable(cell: Vector2i, radius: float) -> bool:
	var point := _cell_to_world(cell)
	if not world_bounds.grow(-radius).has_point(point):
		return false
	for descriptor in obstacle_descriptors:
		if Rect2(descriptor["rect"]).grow(radius).has_point(point):
			return false
	return true
