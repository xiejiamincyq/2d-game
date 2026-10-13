extends RefCounted
## Observer's locked narrow capsule; the Boss director alone chooses active time.
const Terrain = preload("res://scripts/world/TerrainSweep.gd")
const LENGTH := 360.0
const RADIUS := 8.0
const BASE_DAMAGE := 12.0
const DAMAGE := BASE_DAMAGE*3.0
var actor: CharacterBody2D
var target: CharacterBody2D
var origin := Vector2.ZERO
var tip := Vector2.ZERO
var armed := false
var attempted := false
var query := PhysicsShapeQueryParameters2D.new()
func _init() -> void:
	var shape := CapsuleShape2D.new(); shape.radius = RADIUS; shape.height = LENGTH+RADIUS*2
	query.shape = shape; query.collision_mask = 1|Terrain.QUERY_LAYER; query.collide_with_areas = false
func _context_valid() -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion() or actor.get_tree().paused: return false
	if actor.death_resolved or not actor.entrance_resolved: return false
	var owner_health = actor.get("health")
	if not is_instance_valid(owner_health) or owner_health.current_health<=0: return false
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion(): return false
	var health = target.get("health")
	return is_instance_valid(health) and health.current_health>0 and not target.is_stealthed()
func _terrain_clear() -> bool:
	if actor.world_bounds.size!=Vector2.ZERO:
		var safe: Rect2 = actor.world_bounds.grow(-RADIUS)
		if not safe.has_point(origin) or not safe.has_point(tip): return false
	var contacts := actor.get_world_2d().direct_space_state.intersect_shape(query,Terrain.MAX_CONTACTS)
	if contacts.size()>=Terrain.MAX_CONTACTS: return false
	for contact in contacts:
		var body = contact.get("collider")
		if not body is CollisionObject2D or body is StaticBody2D or (body.collision_layer&Terrain.QUERY_LAYER)!=0: return false
	return true
func arm(owner_actor: CharacterBody2D,player: CharacterBody2D,at: Vector2,direction: Vector2) -> bool:
	cancel(); actor = owner_actor; target = player
	if not at.is_finite() or not direction.is_finite() or direction.is_zero_approx() or not _context_valid(): cancel(); return false
	# Scale first: finite Vector2 lengths may overflow before normalized().
	var unit := (direction/maxf(absf(direction.x),absf(direction.y))).normalized()
	origin = at; tip = at+unit*LENGTH
	query.transform = Transform2D(unit.angle()-PI/2,origin+unit*LENGTH*0.5)
	query.exclude = [actor.get_rid(),target.get_rid()]
	if not _terrain_clear(): cancel(); return false
	armed = true; return true
func _path_overlaps(from: Vector2,to: Vector2,reach: float) -> bool:
	# Exact minimum segment separation in 2D: crossing or one of four endpoints.
	var axis := tip-origin; var movement := to-from; var offset := from-origin
	var denominator := axis.cross(movement)
	if absf(denominator)>0.000001:
		var along := offset.cross(movement)/denominator; var across := offset.cross(axis)/denominator
		if along>=0 and along<=1 and across>=0 and across<=1: return true
	for point in [from,to]:
		if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,origin,tip))<=reach*reach: return true
	for point in [origin,tip]:
		if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,from,to))<=reach*reach: return true
	return false
func resolve_hit(from: Vector2,to: Vector2) -> void:
	if not armed: return
	if not from.is_finite() or not to.is_finite() or not _context_valid(): cancel(); return
	if not _terrain_clear(): cancel(); return
	if attempted: return
	var body_radius: float = target.get_body_radius()
	if not is_finite(body_radius) or body_radius<=0: cancel(); return
	if _path_overlaps(from,to,RADIUS+body_radius):
		attempted = true # Before Health signals / death / reentrant live callbacks.
		target.take_damage(DAMAGE,&"rift_observer_beam")
func cancel() -> void:
	armed = false; attempted = false; actor = null; target = null
func draw_visual(canvas: Node2D,active: bool) -> void:
	if not armed: return
	var first := canvas.to_local(origin); var last := canvas.to_local(tip)
	var angle := (last-first).angle(); var side := (last-first).normalized().orthogonal()*RADIUS
	var ink := Color("292435"); var tint := Color("ed8877") if active else Color("f27a4b")
	if active:
		canvas.draw_line(first,last,ink,RADIUS*2+2); canvas.draw_circle(first,RADIUS+1,ink); canvas.draw_circle(last,RADIUS+1,ink)
		canvas.draw_line(first,last,tint,RADIUS*2); canvas.draw_circle(first,RADIUS,tint); canvas.draw_circle(last,RADIUS,tint)
	for sign in [-1,1]:
		canvas.draw_line(first+side*sign,last+side*sign,ink,3,true)
		canvas.draw_line(first+side*sign,last+side*sign,tint,1.5,true)
	canvas.draw_arc(first,RADIUS,angle+PI/2,angle+3*PI/2,12,tint,1.5,true)
	canvas.draw_arc(last,RADIUS,angle-PI/2,angle+PI/2,12,tint,1.5,true)
