extends RefCounted
## Finite, locked ground marks. Only the Archivist director advances combat time.
const RADIUS := 24.0
const DAMAGE := 18.0
const OFFSET := 36.0
var centers: Array[Vector2] = []
var actor: CharacterBody2D
var target: Node2D
var hit_delivered := false
func _context_valid() -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion() or actor.death_resolved: return false
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion(): return false
	var health = target.get("health")
	return is_instance_valid(health) and health.current_health>0 and not (target.has_method("is_stealthed") and target.is_stealthed())
func _line_clear(from: Vector2,to: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(from,to,actor.collision_mask,[actor.get_rid(),target.get_rid()])
	ray.hit_from_inside = true
	return actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
func _footprint_clear(at: Vector2) -> bool:
	if actor.world_bounds.size!=Vector2.ZERO and not actor.world_bounds.grow(-RADIUS).has_point(at): return false
	var shape := CircleShape2D.new(); shape.radius = RADIUS
	var query := PhysicsShapeQueryParameters2D.new(); query.shape = shape
	query.transform = Transform2D(0,at); query.collision_mask = actor.collision_mask
	query.exclude = [actor.get_rid(),target.get_rid()]
	return actor.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
func arm(owner_actor: CharacterBody2D,player: Node2D,direction: Vector2) -> bool:
	cancel(); actor = owner_actor; target = player
	if not _context_valid(): cancel(); return false
	var side := direction.orthogonal()*OFFSET
	var proposed: Array[Vector2] = [target.global_position+side,target.global_position-side]
	var origin: Vector2 = actor.get_safe_seal_origin()
	for at in proposed:
		if not _footprint_clear(at) or not _line_clear(origin,at): cancel(); return false
	centers = proposed
	return true
func resolve_hit(from: Vector2,to: Vector2) -> void:
	if hit_delivered or centers.is_empty() or not _context_valid(): return
	var reach: float = RADIUS+target.get_body_radius()
	for at in centers:
		var closest := Geometry2D.get_closest_point_to_segment(at,from,to)
		if at.distance_squared_to(closest)<=reach*reach and _line_clear(at,closest):
			# Consume before callbacks: two overlapping marks are one attack, even if immune.
			hit_delivered = true
			target.take_damage(DAMAGE,&"archive_seal")
			return
func cancel() -> void:
	centers.clear(); hit_delivered = false; actor = null; target = null
func draw_visual(canvas: Node2D,active: bool,warning_fraction: float = 0) -> void:
	for world in centers:
		var at := canvas.to_local(world)
		if not active:
			canvas.draw_circle(at,RADIUS,Color(Color("f27a4b"),0.08))
			canvas.draw_arc(at,RADIUS,0,TAU,32,Color("172026"),5,true)
			canvas.draw_arc(at,RADIUS,0,TAU,32,Color("f27a4b"),3,true)
			canvas.draw_arc(at,RADIUS*(1-clampf(warning_fraction,0,1)),0,TAU,32,Color("f3eddc"),2,true)
			continue
		for quadrant in range(4):
			var angle: float = quadrant*PI/2
			canvas.draw_arc(at,RADIUS,angle+0.16,angle+1.26,10,Color("22252f"),4)
			canvas.draw_arc(at,RADIUS,angle+0.16,angle+1.26,10,Color("ed8877") if active else Color("eadbb4"),2)
			if active: canvas.draw_circle(at+Vector2.from_angle(angle)*13,2,Color("ed8877"))
