extends RefCounted
class_name DroneLaserResolver

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const TerrainDamage = preload("res://scripts/components/TerrainDamageQuery.gd")
const BeamGeometry = preload("res://scripts/components/BeamHitGeometry.gd")

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
	viewport_size: Vector2,
	length_limit: float = INF
) -> Dictionary:
	if not origin.is_finite() or not direction.is_finite() or direction.is_zero_approx() or not is_finite(width) or width<0:
		return {"end":origin,"targets":[]}
	direction=direction.normalized()
	var beam_length := minf(get_ray_length(origin, world_bounds, viewport_size),maxf(0,length_limit))
	var hits := collect_ray_hits(origin, direction, beam_length, width, enemies)
	if world!=null and is_instance_valid(owner_body) and owner_body.is_inside_tree():
		if world!=owner_body.get_world_2d(): return {"end":origin,"targets":[]}
		for receiver in TerrainDamage.collect_in_beam(owner_body,origin,direction,beam_length,width):
			var entry:=BeamGeometry.receiver_entry(receiver,origin,direction,beam_length,width)
			if is_finite(entry): hits.append({"node":receiver,"entry":entry,"solid":receiver is StaticBody2D,"damageable":receiver.is_in_group(&"destructible_terrain") or enemies.has(receiver)})
	hits.sort_custom(func(a: Dictionary,b: Dictionary):
		if is_equal_approx(a.entry,b.entry): return a.get("solid",false) and not b.get("solid",false)
		return a.entry<b.entry
	)
	var targets: Array=[]
	var seen: Dictionary={}
	var end_distance:=beam_length
	for hit in hits:
		var receiver: Node2D=hit.node
		if not is_instance_valid(receiver) or receiver.is_queued_for_deletion() or seen.has(receiver.get_instance_id()): continue
		seen[receiver.get_instance_id()]=true
		if hit.get("damageable",true) and receiver.has_method("take_damage"): targets.append(receiver)
		if hit.get("solid",false) or not piercing:
			end_distance=hit.entry; break
	return {"end":origin+direction*end_distance,"targets":targets}

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
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion() or not enemy.has_method("take_damage"):
			continue
		var relative := node.global_position - origin
		var along := relative.dot(direction)
		var entry:=BeamGeometry.circle_entry(node.global_position,get_target_radius(node)+width,origin,direction,length)
		if is_finite(entry): hits.append({"node":node,"distance":along,"entry":entry,"solid":false})
	hits.sort_custom(func(a: Dictionary,b: Dictionary): return a.entry<b.entry)
	return hits

func is_target_on_ray(
	target: Node2D,
	origin: Vector2,
	direction: Vector2,
	length: float,
	width: float
) -> bool:
	return is_finite(BeamGeometry.circle_entry(target.global_position,get_target_radius(target)+width,origin,direction,length))

func nodes_from_ray_hits(hits: Array[Dictionary]) -> Array:
	var targets: Array = []
	for hit in hits:
		targets.append(hit["node"])
	return targets

func get_target_radius(target: Node2D) -> float:
	var radius_value: Variant = target.get("body_radius")
	if radius_value!=null: return float(radius_value)
	return target.get_body_radius() if target.has_method("get_body_radius") else 0.0

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
