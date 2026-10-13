extends Node2D
## Finite 180px out/back clock; shared pair attempt, no moving-owner homing.
const RADIUS := 8.0
const DISTANCE := 180.0
const SPEED := 900.0
const LEG_SECONDS := DISTANCE/SPEED
const DAMAGE := 10.0*3.0
var origin := Vector2.ZERO
var direction := Vector2.RIGHT
var elapsed := 0.0
var returning := false
var world_bounds := Rect2()
var source_actor: WeakRef
var target_player: WeakRef
var hit_state: Dictionary
var previous_target := Vector2.ZERO
var query := PhysicsShapeQueryParameters2D.new()
func configure(actor: CharacterBody2D,target: Node2D,at: Vector2,heading: Vector2,attempt: Dictionary) -> void:
	source_actor = weakref(actor); target_player = weakref(target)
	origin = at; direction = heading.normalized(); hit_state = attempt; world_bounds = actor.world_bounds
	var shape := CircleShape2D.new(); shape.radius = RADIUS; query.shape = shape
	query.collision_mask = actor.collision_mask; query.collide_with_areas = false
	query.exclude = [actor.get_rid(),target.get_rid()]
func _owners_alive() -> bool:
	if source_actor==null or target_player==null: return false
	var actor = source_actor.get_ref(); var target = target_player.get_ref()
	return is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_queued_for_deletion() and not actor.death_resolved and is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and target.health.current_health>0 and not target.is_stealthed()
func _ready() -> void:
	if not _owners_alive() or not origin.is_finite() or not direction.is_finite() or direction.is_zero_approx(): cancel(); return
	global_position = origin; previous_target = target_player.get_ref().global_position
func cancel() -> void: hide(); queue_free()
func _move_piece(seconds: float,from_target: Vector2,to_target: Vector2) -> bool:
	var speed := direction*SPEED*(-1 if returning else 1); var allowed := seconds
	if world_bounds.size!=Vector2.ZERO:
		var safe := world_bounds.grow(-RADIUS)
		if safe.size.x<=0 or safe.size.y<=0 or not safe.has_point(global_position): cancel(); return false
		for axis in 2:
			if speed[axis]>0: allowed = minf(allowed,(safe.end[axis]-global_position[axis])/speed[axis])
			elif speed[axis]<0: allowed = minf(allowed,(safe.position[axis]-global_position[axis])/speed[axis])
	if allowed<=0.000001: cancel(); return false
	var start := global_position; var space := get_world_2d().direct_space_state
	query.transform = Transform2D(0,start); query.motion = Vector2.ZERO
	if not space.intersect_shape(query,1).is_empty(): cancel(); return false
	query.motion = speed*allowed
	var fractions := space.cast_motion(query); var fraction: float = fractions[0]
	global_position = start+query.motion*fraction; elapsed += allowed*fraction
	var target_end := from_target.lerp(to_target,allowed/seconds*fraction)
	var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,start-from_target,global_position-target_end)
	var target = target_player.get_ref()
	if not hit_state.attempted and closest.length()<=RADIUS+target.get_body_radius():
		hit_state.attempted = true # Shared across both paths and both legs, before callbacks.
		target.take_damage(DAMAGE,&"bell_priest_pendant")
	if is_queued_for_deletion(): return false
	if fraction<1 or allowed<seconds-0.000001 or not _owners_alive(): cancel(); return false
	return true
func _physics_process(delta: float) -> void:
	if is_queued_for_deletion() or not is_finite(delta) or delta<=0: return
	if not _owners_alive(): cancel(); return
	var target_now: Vector2 = target_player.get_ref().global_position
	var pending := minf(delta,LEG_SECONDS*2-elapsed); var consumed := 0.0
	# At most two linear pieces, even for a step spanning the whole return.
	for _leg in 2:
		if pending<=0.000001: break
		var piece := minf(pending,(LEG_SECONDS*2 if returning else LEG_SECONDS)-elapsed)
		var first := previous_target.lerp(target_now,consumed/delta)
		var last := previous_target.lerp(target_now,(consumed+piece)/delta)
		if not _move_piece(piece,first,last): return
		consumed += piece; pending -= piece; returning = elapsed>=LEG_SECONDS-0.000001
	previous_target = target_now; queue_redraw()
	if elapsed>=LEG_SECONDS*2-0.000001: global_position = origin; cancel()
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,direction.angle(),Vector2.ONE)
	var hull := PackedVector2Array([Vector2(-9,0),Vector2(-3,-8),Vector2(7,-5),Vector2(9,0),Vector2(7,5),Vector2(-3,8)])
	var core := PackedVector2Array([Vector2(-6,0),Vector2(-2,-5),Vector2(5,-3),Vector2(6,0),Vector2(5,3),Vector2(-2,5)])
	draw_colored_polygon(hull,Color("292435")); draw_colored_polygon(core,Color("d0c5b6") if returning else Color("b79361"))
	draw_line(Vector2(-4,0),Vector2(3,0),Color("ed8877"),2)
