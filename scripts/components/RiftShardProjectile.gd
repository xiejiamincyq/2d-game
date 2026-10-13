extends "res://scripts/components/Projectile.gd"
## New opaque faceted shard and restrained animated glint, not legacy orb art.
var visual_time := 0.0
var sweep_shape := CircleShape2D.new()
var sweep_query := PhysicsShapeQueryParameters2D.new()
func _init() -> void:
	velocity = Vector2(320,0)
	damage = 12
	radius = 4
	lifetime = 1.15
	target_group = &"player"
	tint = Color("b5acc0")
func _ready() -> void:
	super._ready()
	sweep_shape.radius = radius
	sweep_query.shape = sweep_shape
	sweep_query.exclude = [get_rid()]
func _physics_process(delta: float) -> void:
	if is_queued_for_deletion() or not is_finite(delta) or delta<0: return
	visual_time += delta
	var space := get_world_2d().direct_space_state
	var motion := velocity*delta
	sweep_query.collision_mask = collision_mask
	sweep_query.transform = Transform2D(0,global_position)
	sweep_query.margin = 0.01
	sweep_query.motion = motion
	# cast_motion ignores initial overlaps, so handle a blocked birth separately.
	var initial := space.intersect_shape(sweep_query,1)
	if not initial.is_empty():
		_on_body_entered(initial[0].collider)
		return
	var fractions := space.cast_motion(sweep_query)
	if fractions[0]<1:
		global_position += motion*fractions[1]
		sweep_query.motion = Vector2.ZERO
		sweep_query.transform = Transform2D(0,global_position)
		sweep_query.margin = 0.08
		var impact := space.get_rest_info(sweep_query)
		if not impact.is_empty():
			var body := instance_from_id(impact.collider_id) as Node
			if is_instance_valid(body): _on_body_entered(body)
		queue_free() # Never continue past a detected first collision.
		return
	super._physics_process(delta)
	queue_redraw()
func _on_body_entered(body: Node) -> void:
	if is_queued_for_deletion(): return
	if body.is_in_group(&"player"):
		if body.has_method("is_stealthed") and body.is_stealthed():
			queue_free()
			return
		super._on_body_entered(body)
	else:
		queue_free() # Physical terrain blocks hostile shards, not only muzzle birth.
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,velocity.angle(),Vector2.ONE)
	var hull := PackedVector2Array([Vector2(-6,0),Vector2(0,-4),Vector2(8,0),Vector2(0,4)])
	var core := PackedVector2Array([Vector2(-4,0),Vector2(0,-2.5),Vector2(6,0),Vector2(0,2.5)])
	draw_colored_polygon(hull,Color("1c2926"))
	draw_colored_polygon(core,tint)
	draw_line(Vector2(-2,0),Vector2(3+sin(visual_time*18),0),Color("dfd5bf"),1.2,true)
