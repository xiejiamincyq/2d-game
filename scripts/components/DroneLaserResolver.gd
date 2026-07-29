extends RefCounted
class_name DroneLaserResolver

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")

const BURN_STACK_INTERVAL := 0.20
const BURN_SECONDS := 4.0
const IGNITION_SECONDS := 0.60
const PIERCING_IGNITION_SECONDS := 0.30

var burn_tracks: Array[Dictionary] = []

func sync_track_count(count: int) -> void:
	while burn_tracks.size() < count:
		burn_tracks.append({})
	while burn_tracks.size() > count:
		burn_tracks.pop_back()

func clear_burn_tracks() -> void:
	for index in range(burn_tracks.size()):
		burn_tracks[index] = {}

func get_ray_length(origin: Vector2, world_bounds: Rect2, viewport_size: Vector2) -> float:
	if world_bounds.size != Vector2.ZERO:
		var corners := [
			world_bounds.position,
			Vector2(world_bounds.end.x, world_bounds.position.y),
			world_bounds.end,
			Vector2(world_bounds.position.x, world_bounds.end.y),
		]
		var farthest := 0.0
		for corner in corners:
			farthest = maxf(farthest, origin.distance_to(corner))
		return farthest + 64.0
	return maxf(10000.0, viewport_size.length() * 8.0)

func resolve_ray(
	owner_body: CollisionObject2D,
	world: World2D,
	origin: Vector2,
	direction: Vector2,
	width: float,
	enemies: Array,
	piercing: bool,
	world_bounds: Rect2,
	viewport_size: Vector2
) -> Dictionary:
	var beam_length := get_ray_length(origin, world_bounds, viewport_size)
	var hits := collect_ray_hits(origin, direction, beam_length, width, enemies)
	if piercing:
		return {"end": origin + direction * beam_length, "targets": nodes_from_ray_hits(hits)}
	var blocker_distance := beam_length
	var blocker_position := origin + direction * beam_length
	if world != null:
		var query := PhysicsRayQueryParameters2D.create(origin, blocker_position)
		query.exclude = [owner_body.get_rid()]
		query.collide_with_areas = false
		var obstruction := world.direct_space_state.intersect_ray(query)
		if not obstruction.is_empty():
			blocker_position = obstruction["position"]
			blocker_distance = origin.distance_to(blocker_position)
	for hit in hits:
		var enemy: Node2D = hit["node"]
		var radius := get_target_radius(enemy)
		if float(hit["distance"]) <= blocker_distance + radius + width:
			var enemy_surface_distance := maxf(0.0, float(hit["distance"]) - radius)
			var visible_distance := minf(blocker_distance, enemy_surface_distance)
			return {"end": origin + direction * visible_distance, "targets": [enemy]}
	return {"end": blocker_position, "targets": []}

func collect_ray_hits(
	origin: Vector2,
	direction: Vector2,
	length: float,
	width: float,
	candidates: Array
) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for enemy in candidates:
		var node := enemy as Node2D
		if node == null or not is_instance_valid(node) or not enemy.has_method("take_damage"):
			continue
		var relative := node.global_position - origin
		var along := relative.dot(direction)
		if along < 0.0 or along > length:
			continue
		if is_target_on_ray(node, origin, direction, length, width):
			hits.append({"node": node, "distance": along})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
	return hits

func is_target_on_ray(
	target: Node2D,
	origin: Vector2,
	direction: Vector2,
	length: float,
	width: float
) -> bool:
	var relative := target.global_position - origin
	var along := relative.dot(direction)
	if along < 0.0 or along > length:
		return false
	return (origin + direction * along).distance_to(target.global_position) <= width + get_target_radius(target)

func nodes_from_ray_hits(hits: Array[Dictionary]) -> Array:
	var targets: Array = []
	for hit in hits:
		targets.append(hit["node"])
	return targets

func get_target_radius(target: Node2D) -> float:
	var radius_value: Variant = target.get("body_radius")
	return float(radius_value) if radius_value != null else 0.0

func update_burn_tracks(
	index: int,
	hit_targets: Array,
	delta: float,
	piercing: bool,
	burn_base_attack: float
) -> void:
	sync_track_count(index + 1)
	var previous: Dictionary = burn_tracks[index]
	var updated: Dictionary = {}
	var ignition := PIERCING_IGNITION_SECONDS if piercing else IGNITION_SECONDS
	for target in hit_targets:
		if not is_instance_valid(target):
			continue
		var target_id: int = target.get_instance_id()
		var track: Dictionary = previous.get(target_id, {"elapsed": 0.0, "next_stack": ignition, "ignited": false})
		track["elapsed"] = float(track["elapsed"]) + maxf(0.0, delta)
		if not bool(track.get("ignited", false)):
			track["next_stack"] = minf(float(track["next_stack"]), ignition)
		while float(track["elapsed"]) + 0.00001 >= float(track["next_stack"]):
			if target.has_method("apply_burn_stack"):
				target.apply_burn_stack(burn_base_attack, BURN_SECONDS, 0.0, DamageTypes.SILENT_BURN)
			track["ignited"] = true
			track["next_stack"] = float(track["next_stack"]) + BURN_STACK_INTERVAL
		updated[target_id] = track
	burn_tracks[index] = updated
