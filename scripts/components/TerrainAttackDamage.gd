extends RefCounted
## Physical damage candidates are independent from auto-aim and kill registries.
const Query=preload("res://scripts/components/TerrainDamageQuery.gd")

static func live(owner: Node2D) -> bool:
	if not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion(): return false
	var health=owner.get("health")
	return health==null or health.current_health>0

static func segment(owner: Node2D,start: Vector2,end: Vector2,width: float) -> Array[Node2D]:
	if start.is_equal_approx(end): return Query.collect_in_circle(owner,start,width)
	var targets: Array[Node2D]=[]
	for target in Query.collect_in_beam(owner,start,start.direction_to(end),start.distance_to(end),width):
		if target.is_in_group(&"destructible_terrain") and target.has_method("take_damage"): targets.append(target)
	return targets

static func visible(owner: Node2D,targets: Array[Node2D],origin: Vector2) -> Array[Node2D]:
	var result: Array[Node2D]=[]
	if not live(owner): return result
	# Freeze obstruction before damage callbacks can remove a wall. One strike
	# cannot destroy its cover and then hit another receiver behind it.
	for target in targets:
		if not is_instance_valid(target) or target.is_queued_for_deletion(): continue
		var point:=Query.closest_point(target,origin)
		if not point.is_finite(): continue
		var ray:=PhysicsRayQueryParameters2D.create(origin,point,1)
		if owner is CollisionObject2D: ray.exclude=[owner.get_rid()]
		ray.hit_from_inside=true
		var blocker:=owner.get_world_2d().direct_space_state.intersect_ray(ray)
		if blocker.is_empty() or blocker.collider==target: result.append(target)
	return result

static func apply(owner: Node2D,targets: Array[Node2D],origin: Vector2,amount: float,source: StringName,hit_ids: Dictionary,authorized: Callable=Callable()) -> void:
	if not live(owner) or not is_finite(amount) or amount<=0: return
	for target in visible(owner,targets,origin):
		if not live(owner): return
		if authorized.is_valid() and not authorized.call(): return
		if not is_instance_valid(target) or target.is_queued_for_deletion() or hit_ids.has(target.get_instance_id()): continue
		hit_ids[target.get_instance_id()]=true
		target.take_damage(amount,source,origin.direction_to(target.global_position))
