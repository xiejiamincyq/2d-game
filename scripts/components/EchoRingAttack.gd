extends "res://scripts/components/ScrapperAttack.gd"
## Swept hollow sound rim. Visual motion and crowd displacement cannot move origin.
var radius := 0.0
var previous_radius := 0.0
func get_warning_duration() -> float: return 0.18
func get_active_duration() -> float: return 0.5
func get_released_delay() -> float: return 0.15
func consider(actor: Node2D,target: Node2D,delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	if cooldown>0 or is_active() or not is_instance_valid(target): return
	if actor.has_method("get_camera_safe_rect") and not actor.get_camera_safe_rect().has_point(actor.global_position): return
	if actor.global_position.distance_to(target.global_position)<=220:
		begin(actor,target,Move.CLAW)
func advance(delta: float) -> void:
	if not is_finite(delta) or delta<0: return
	previous_radius = radius
	super.advance(delta)
	radius = 0 if stage==Stage.IDLE else 170*clampf((elapsed-0.18)/0.5,0,1)
func cancel() -> void:
	stage = Stage.IDLE
	cooldown = 2.4
	radius = 0
	previous_radius = 0
	did_hit = false
func resolve_hit(actor: CharacterBody2D,target: Node2D) -> void:
	if stage not in [Stage.ACTIVE,Stage.RECOVERY] or radius<=previous_radius or did_hit or not is_instance_valid(target): return
	if not target.has_method("take_damage") or target.is_queued_for_deletion(): return
	if target.has_method("is_stealthed") and target.is_stealthed(): return
	var distance := origin.distance_to(target.global_position)
	# Circle-body overlap with this step's swept rim, never the filled interior.
	if distance+target_radius+1.5<previous_radius or distance-target_radius-1.5>radius: return
	var ray := PhysicsRayQueryParameters2D.create(origin,target.global_position,actor.collision_mask,[actor.get_rid()])
	var blocker := actor.get_world_2d().direct_space_state.intersect_ray(ray)
	if not blocker.is_empty() and blocker.collider!=target: return
	did_hit = true
	target.take_damage(actor.contact_damage)
func draw_warning(canvas: Node2D,actor: Node2D) -> void:
	if not is_ring_visible(): return
	var center := actor.to_local(origin)
	canvas.draw_arc(center,radius,0,TAU,64,Color("1c2926"),3,true)
	canvas.draw_arc(center,radius,0,TAU,64,Color("b5a9bd"),1.5,true)
func is_ring_visible() -> bool:
	# The last sweep reaches max radius on the first recovery step. Keep that
	# damaging rim visible for that frame, never as a stationary recovery disk.
	return radius>0 and (stage==Stage.ACTIVE or (stage==Stage.RECOVERY and radius>previous_radius))
func get_attack_strokes(_actor: Node2D) -> Array[PackedVector2Array]: return []
