extends "res://scripts/components/VineSeedProjectile.gd"
## Straight, opaque paper leaf. Reuse canonical swept-circle collision only.
const HIT_RADIUS := 10.0
var source_actor: WeakRef
func _init() -> void:
	super._init()
	radius = HIT_RADIUS; damage = 24; lifetime = 1.35
	velocity = Vector2(420,0); damage_source = &"archive_page"
	tint = Color("d6c8a4")
## Called after add_child/ready, before the first physics step.
func ignore_source(actor: CollisionObject2D) -> void:
	super.ignore_source(actor)
	source_actor = weakref(actor)
	if not actor.tree_exiting.is_connected(cancel): actor.tree_exiting.connect(cancel,CONNECT_ONE_SHOT)
func cancel() -> void:
	hide(); queue_free()
func _physics_process(delta: float) -> void:
	if is_queued_for_deletion() or not is_finite(delta) or delta<=0: return
	if source_actor!=null:
		var actor = source_actor.get_ref()
		if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion(): cancel(); return
	# Clamp flight BEFORE the sweep: no hit beyond lifetime or world footprint.
	var seconds := minf(delta,lifetime)
	if world_bounds.size!=Vector2.ZERO:
		var safe := world_bounds.grow(-radius)
		if safe.size.x<=0 or safe.size.y<=0 or not safe.has_point(global_position): cancel(); return
		for axis in 2:
			if velocity[axis]>0: seconds = minf(seconds,(safe.end[axis]-global_position[axis])/velocity[axis])
			elif velocity[axis]<0: seconds = minf(seconds,(safe.position[axis]-global_position[axis])/velocity[axis])
	if seconds<=0.000001: cancel(); return
	super._physics_process(seconds)
	if seconds<delta or lifetime<=0.000001: cancel()
func _try_hit(node: Node) -> void:
	if is_queued_for_deletion(): return
	if node.is_in_group(&"player") and node.has_method("is_stealthed") and node.is_stealthed(): cancel(); return
	super._try_hit(node)
func _exit_tree() -> void:
	if source_actor==null: return
	var actor = source_actor.get_ref()
	if is_instance_valid(actor) and actor.tree_exiting.is_connected(cancel): actor.tree_exiting.disconnect(cancel)
func get_visual_hull() -> PackedVector2Array:
	var hull := PackedVector2Array()
	for angle in [PI,-2*PI/3,-PI/3,0,PI/3,2*PI/3]:
		hull.append(Vector2.from_angle(angle)*radius)
	return hull
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,velocity.angle(),Vector2.ONE)
	var hull := get_visual_hull()
	var core := hull.duplicate()
	for point in core.size(): core[point] *= 0.65
	draw_colored_polygon(hull,Color("1c2926")); draw_colored_polygon(core,tint)
	draw_line(Vector2(-radius*0.3,-0.5),Vector2(radius*0.3,0),Color("f27a4b"),1.5)
