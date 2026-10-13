extends RefCounted
## Observer-only finite circle flight. Sole director supplies ages and Player segments.
const Terrain = preload("res://scripts/world/TerrainSweep.gd")
const MAX_STEP := 1.0/15.0
var _radius := 0.0
var _max_distance := 0.0
var _flight_seconds := 0.0
var _life_seconds := 0.0
var _damage_amount := 0.0
var _damage_source: StringName = &""
var actor: CharacterBody2D
var target: CharacterBody2D
var origin := Vector2.ZERO
var landing := Vector2.ZERO
var position := Vector2.ZERO
var age := 0.0
var armed := false
var attempt: Dictionary = {}
var resolving_damage := false
var query := PhysicsShapeQueryParameters2D.new()
func _get_radius() -> float: return 0.0
func _get_max_distance() -> float: return 0.0
func _get_flight_seconds() -> float: return 0.0
func _get_life_seconds() -> float: return 0.0
func _get_damage() -> float: return 0.0
func _get_damage_source() -> StringName: return &""
func _context_valid() -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion() or actor.get_tree().paused: return false
	if actor.death_resolved or not actor.entrance_resolved: return false
	var health = actor.get("health")
	if not is_instance_valid(health) or health.current_health<=0: return false
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion(): return false
	var target_health = target.get("health")
	return is_instance_valid(target_health) and target_health.current_health>0 and not target.is_stealthed()
func _terrain_clear() -> bool:
	if actor.world_bounds.size!=Vector2.ZERO:
		var safe: Rect2 = actor.world_bounds.grow(-_radius)
		if not safe.has_point(origin) or not safe.has_point(landing): return false
	var contacts := actor.get_world_2d().direct_space_state.intersect_shape(query,Terrain.MAX_CONTACTS)
	if contacts.size()>=Terrain.MAX_CONTACTS: return false
	for contact in contacts:
		var body = contact.get("collider")
		if not body is CollisionObject2D or body is StaticBody2D or (body.collision_layer&Terrain.QUERY_LAYER)!=0: return false
	return true
func arm(owner_actor: CharacterBody2D,player: CharacterBody2D,at: Vector2,end: Vector2,ledger: Dictionary) -> bool:
	if resolving_damage: return false
	cancel(); actor = owner_actor; target = player
	# Snapshot fixed action scalars once: no float32 vector profile or midflight change.
	_radius = _get_radius(); _max_distance = _get_max_distance(); _flight_seconds = _get_flight_seconds(); _life_seconds = _get_life_seconds()
	_damage_amount = _get_damage(); _damage_source = _get_damage_source()
	if not is_finite(_radius) or _radius<=0 or not is_finite(_max_distance) or _max_distance<=0 or not is_finite(_flight_seconds) or _flight_seconds<=0 or not is_finite(_life_seconds) or _life_seconds<_flight_seconds or not is_finite(_damage_amount) or _damage_amount<=0 or String(_damage_source).is_empty(): cancel(); return false
	if not at.is_finite() or not end.is_finite() or not ledger.get("attempted") is bool or not _context_valid(): cancel(); return false
	var distance := at.distance_to(end)
	if not is_finite(distance) or distance<=0.001 or distance>_max_distance: cancel(); return false
	origin = at; landing = end; position = at; age = 0; attempt = ledger
	var shape := CapsuleShape2D.new(); shape.radius = _radius; shape.height = distance+_radius*2
	query.shape = shape; query.transform = Transform2D(at.direction_to(end).angle()-PI/2,at.lerp(end,0.5))
	query.collision_mask = 1|Terrain.QUERY_LAYER; query.collide_with_areas = false; query.exclude = [actor.get_rid(),target.get_rid()]
	if not _terrain_clear(): cancel(); return false
	armed = true; return true
func _position_at(seconds: float) -> Vector2: return origin.lerp(landing,clampf(seconds/_flight_seconds,0,1))
func resolve_hit(before: float,after: float,from_player: Vector2,to_player: Vector2) -> void:
	if not armed or resolving_damage: return
	if not is_finite(before) or not is_finite(after) or before<0 or after<before or before<age-0.000001 or after-before>MAX_STEP+0.000001 or not from_player.is_finite() or not to_player.is_finite() or not _context_valid() or not _terrain_clear(): cancel(); return
	if after==before: return # A read-only sample cannot inflict previsible birth damage.
	if before>=_life_seconds-0.000001: cancel(); return
	var end := minf(after,_life_seconds)
	var fraction := clampf((end-before)/(after-before),0,1) if after>before else 0.0
	var target_end := from_player.lerp(to_player,fraction)
	var first := _position_at(before); position = _position_at(end); age = end
	if attempt.attempted: return
	var body_radius: float = target.get_body_radius()
	if not is_finite(body_radius) or body_radius<=0: cancel(); return
	var relative := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,first-from_player,position-target_end)
	var distance_squared := relative.length_squared()
	if before<_flight_seconds and end>_flight_seconds:
		# At the flight/hold boundary a single chord would invent a slower flight.
		# Interpolate Player at the same boundary using the original frame span.
		var target_corner := from_player.lerp(to_player,(_flight_seconds-before)/(after-before))
		var corner := landing-target_corner
		var outbound := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,first-from_player,corner)
		var held := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,corner,position-target_end)
		distance_squared = minf(outbound.length_squared(),held.length_squared())
	if distance_squared<=(_radius+body_radius)*(_radius+body_radius):
		attempt.attempted = true # Cast-wide even on rejection, before reentrant Health.
		resolving_damage = true; target.take_damage(_damage_amount,_damage_source); resolving_damage = false
func cancel() -> void:
	armed = false; actor = null; target = null; attempt = {}
