extends RefCounted
## Damage candidates, not aim/clearance candidates. Query the caller's World2D
## and actual collision shapes, including Areas, rather than visual pivots.
static func collect_in_circle(owner: Node2D,center: Vector2,radius: float) -> Array[Node2D]:
	var targets: Array[Node2D]=[]
	if not is_instance_valid(owner) or not owner.is_inside_tree() or not center.is_finite() or not is_finite(radius) or radius<=0: return targets
	var shape:=CircleShape2D.new(); shape.radius=radius
	var query:=PhysicsShapeQueryParameters2D.new(); query.shape=shape
	query.transform=Transform2D(0,center); query.collision_mask=1
	query.collide_with_bodies=true; query.collide_with_areas=true
	return _collect(owner,query,false)

static func collect_in_annulus(owner: Node2D,center: Vector2,inner: float,outer: float) -> Array[Dictionary]:
	var hits: Array[Dictionary]=[]
	for target in collect_in_circle(owner,center,outer):
		var bounds:=_radial_bounds(target,center)
		if bounds.x<=outer and bounds.y>=inner:
			hits.append({"node":target,"distance":maxf(inner,bounds.x)})
	return hits

static func collect_in_polygon(owner: Node2D,points: PackedVector2Array) -> Array[Node2D]:
	if not is_instance_valid(owner) or not owner.is_inside_tree() or points.size()<3: return []
	var shape:=ConvexPolygonShape2D.new(); shape.points=Geometry2D.convex_hull(points)
	var query:=PhysicsShapeQueryParameters2D.new(); query.shape=shape
	query.collision_mask=1; query.collide_with_bodies=true; query.collide_with_areas=true
	return _collect(owner,query,false)

static func closest_point(target: Node2D,origin: Vector2) -> Vector2:
	var nearest:=Vector2(INF,INF); var distance:=INF
	for child in target.get_children():
		if not child is CollisionShape2D or child.disabled or child.shape==null: continue
		var point:=Vector2(INF,INF)
		if child.shape is CircleShape2D:
			var radius: float=child.shape.radius*child.global_transform.x.length()
			point=child.global_position+(origin-child.global_position).limit_length(radius)
		elif child.shape is RectangleShape2D:
			var half: Vector2=child.shape.size/2; var corners:=PackedVector2Array()
			for at in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]: corners.append(child.to_global(at))
			if Geometry2D.is_point_in_polygon(origin,corners): return origin
			for index in 4:
				var candidate:=Geometry2D.get_closest_point_to_segment(origin,corners[index],corners[(index+1)%4])
				if origin.distance_squared_to(candidate)<origin.distance_squared_to(point): point=candidate
		if origin.distance_squared_to(point)<distance:
			distance=origin.distance_squared_to(point); nearest=point
	return nearest

static func _radial_bounds(target: Node2D,center: Vector2) -> Vector2:
	var nearest:=INF; var farthest:=-INF
	for child in target.get_children():
		if not child is CollisionShape2D or child.disabled or child.shape==null: continue
		if child.shape is CircleShape2D:
			var radius: float=child.shape.radius*child.global_transform.x.length()
			var distance:=center.distance_to(child.global_position)
			nearest=minf(nearest,maxf(0,distance-radius)); farthest=maxf(farthest,distance+radius)
		elif child.shape is RectangleShape2D:
			var half: Vector2=child.shape.size/2
			var corners:=PackedVector2Array()
			for at in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]:
				corners.append(child.to_global(at))
			if Geometry2D.is_point_in_polygon(center,corners): nearest=0
			for index in 4:
				nearest=minf(nearest,center.distance_to(Geometry2D.get_closest_point_to_segment(center,corners[index],corners[(index+1)%4])))
				farthest=maxf(farthest,center.distance_to(corners[index]))
	return Vector2(nearest,farthest)

static func collect_in_beam(owner: Node2D,origin: Vector2,direction: Vector2,length: float,width: float) -> Array[Node2D]:
	if not is_instance_valid(owner) or not owner.is_inside_tree() or length<=0: return []
	var shape:=CapsuleShape2D.new(); shape.radius=maxf(0.01,width); shape.height=length+shape.radius*2
	var query:=PhysicsShapeQueryParameters2D.new(); query.shape=shape
	query.transform=Transform2D(direction.angle()-PI/2,origin+direction*length/2)
	query.collision_mask=1; query.collide_with_bodies=true; query.collide_with_areas=true
	if owner is CollisionObject2D: query.exclude=[owner.get_rid()]
	return _collect(owner,query,true)

static func _collect(owner: Node2D,query: PhysicsShapeQueryParameters2D,include_solids: bool) -> Array[Node2D]:
	var targets: Array[Node2D]=[]
	var excluded: Array[RID]=query.exclude.duplicate()
	var seen: Dictionary={}
	var space:=owner.get_world_2d().direct_space_state
	# Each page excludes every returned RID. No silent32/64 target cap; finite
	# live physics bodies bound this loop, with no damage callbacks during query.
	while true:
		query.exclude=excluded
		var contacts:=space.intersect_shape(query,64)
		var progressed:=false
		for contact in contacts:
			if not excluded.has(contact.rid): excluded.append(contact.rid); progressed=true
			var node: Node=contact.collider
			if not is_instance_valid(node) or node.is_queued_for_deletion() or not node is Node2D or seen.has(node.get_instance_id()): continue
			seen[node.get_instance_id()]=true
			if (node.is_in_group(&"destructible_terrain") and node.has_method("take_damage")) or (include_solids and node is StaticBody2D): targets.append(node)
		if contacts.size()<64 or not progressed: break
	return targets
