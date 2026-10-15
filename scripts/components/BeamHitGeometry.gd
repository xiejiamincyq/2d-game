extends RefCounted
## Entry of a finite thick ray, measured in world pixels. Current gameplay
## receivers use circles or transformed rectangles; never use art pivots.
static func circle_entry(center: Vector2,radius: float,origin: Vector2,direction: Vector2,length: float) -> float:
	var relative:=center-origin
	if relative.length_squared()<=radius*radius: return 0
	var along:=relative.dot(direction)
	var perpendicular:=maxf(0,relative.length_squared()-along*along)
	if perpendicular>radius*radius: return INF
	var entry:=along-sqrt(maxf(0,radius*radius-perpendicular))
	return entry if entry>=0 and entry<=length else INF

static func receiver_entry(body: Node2D,origin: Vector2,direction: Vector2,length: float,width: float) -> float:
	var nearest:=INF
	for child in body.get_children():
		if not child is CollisionShape2D or child.disabled or child.shape==null: continue
		if child.shape is RectangleShape2D:
			nearest=minf(nearest,_rectangle_entry(child,origin,direction,length,width))
		elif child.shape is CircleShape2D:
			nearest=minf(nearest,circle_entry(child.global_position,child.shape.radius*child.global_transform.x.length()+width,origin,direction,length))
		else:
			# Unknown solid receiver geometry must not permit shooting through it.
			return 0
	return nearest

static func _rectangle_entry(collider: CollisionShape2D,origin: Vector2,direction: Vector2,length: float,width: float) -> float:
	var half: Vector2=collider.shape.size/2
	var corners:=PackedVector2Array()
	for at in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]:
		corners.append(collider.to_global(at))
	if Geometry2D.is_point_in_polygon(origin,corners): return 0
	var nearest:=INF
	var end:=origin+direction*length
	# Rectangle Minkowski sum: edge strips and corner disks. Unlike an expanded
	# AABB, this preserves rotated faces and rounded-corner near misses.
	for index in 4:
		var a:=corners[index]; var b:=corners[(index+1)%4]
		if origin.distance_to(Geometry2D.get_closest_point_to_segment(origin,a,b))<=width: return 0
		nearest=minf(nearest,circle_entry(a,width,origin,direction,length))
		var normal: Vector2=(b-a).orthogonal().normalized()*width
		for offset in [normal,-normal]:
			var point: Variant=Geometry2D.segment_intersects_segment(origin,end,a+offset,b+offset)
			if point!=null: nearest=minf(nearest,origin.distance_to(point))
	return nearest
