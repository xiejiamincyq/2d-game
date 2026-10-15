extends "res://scripts/components/ScrapperAttack.gd"
## Locked short dash / close hook, ordinary enemy. No teleport or invisibility.
const DASH_SPEED := 500.0
const DASH_TIME := 0.24
const HOOK_REACH := 37.0 # 12px center offset + 25px visible crescent.
func get_warning_duration() -> float: return 0.40 if move==Move.POUNCE else 0.45
func get_active_duration() -> float: return DASH_TIME if move==Move.POUNCE else 0.10
func get_released_delay() -> float: return 0.15
func cancel() -> void:
	stage = Stage.IDLE
	cooldown = 2.2
	did_hit = false
func consider(actor: Node2D,target: Node2D,delta: float) -> void:
	if not is_finite(delta) or delta<0: return
	cooldown = maxf(0,cooldown-delta)
	if cooldown>0 or is_active() or not is_instance_valid(target): return
	if actor.has_method("get_camera_safe_rect") and not actor.get_camera_safe_rect().has_point(actor.global_position): return
	var distance := actor.global_position.distance_to(target.global_position)
	if distance<=48: begin(actor,target,Move.CLAW)
	elif distance>=80 and distance<=140: begin(actor,target,Move.POUNCE)
func get_velocity() -> Vector2:
	return direction*DASH_SPEED if stage==Stage.ACTIVE and move==Move.POUNCE else Vector2.ZERO
func finish_motion() -> void:
	if stage==Stage.ACTIVE and move==Move.POUNCE:
		stage = Stage.RECOVERY
		elapsed = get_warning_duration()+DASH_TIME
func resolve_hit(actor: CharacterBody2D,target: Node2D) -> void:
	_resolve_player_hit(actor,target)
	_resolve_terrain(actor)
func _resolve_terrain(actor: CharacterBody2D) -> void:
	if stage!=Stage.ACTIVE or not TerrainAttack.live(actor): return
	if move==Move.POUNCE:
		TerrainAttack.apply(actor,TerrainQuery.collect_in_circle(actor,actor.global_position,actor.body_radius+actor.safe_margin+0.5),actor.global_position,actor.contact_damage,&"enemy",terrain_hit_ids,func(): return stage==Stage.ACTIVE)
		return
	var points:=PackedVector2Array([origin])
	for index in 17: points.append(origin+direction.rotated(lerpf(-0.8,0.8,index/16.0))*HOOK_REACH)
	TerrainAttack.apply(actor,TerrainQuery.collect_in_polygon(actor,points),origin,actor.contact_damage,&"enemy",terrain_hit_ids,func(): return stage==Stage.ACTIVE)
func _resolve_player_hit(actor: CharacterBody2D,target: Node2D) -> void:
	if stage!=Stage.ACTIVE or did_hit or not is_instance_valid(target): return
	if target.is_queued_for_deletion() or not target.has_method("take_damage"): return
	if target.has_method("is_stealthed") and target.is_stealthed(): return
	var offset := target.global_position-origin
	var ray_origin := origin
	if move==Move.CLAW:
		if offset.length()>HOOK_REACH+target_radius: return
		if offset.length()>0.001 and direction.dot(offset.normalized())<cos(0.8): return
	else:
		var reach := get_contact_reach(actor)
		if actor.global_position.distance_to(target.global_position)>reach: return
		if absf(offset.dot(direction.orthogonal()))>reach or offset.dot(direction)<-reach or offset.dot(direction)>DASH_SPEED*DASH_TIME+reach: return
		ray_origin = actor.global_position
	var ray := PhysicsRayQueryParameters2D.create(ray_origin,target.global_position,actor.collision_mask,[actor.get_rid()])
	var blocker := actor.get_world_2d().direct_space_state.intersect_ray(ray)
	if not blocker.is_empty() and blocker.collider!=target: return
	did_hit = true
	target.take_damage(actor.contact_damage)
func get_attack_strokes(_actor: Node2D) -> Array[PackedVector2Array]: return []
func draw_warning(canvas: Node2D,actor: Node2D) -> void:
	if stage!=Stage.ACTIVE: return
	if move==Move.CLAW:
		var center := actor.to_local(origin)+direction*12
		var phase := clampf((elapsed-get_warning_duration())/0.10,0,1)
		var angle := direction.angle()
		canvas.draw_arc(center,25,angle-0.75+phase*0.25,angle+0.35+phase*0.25,12,Color("1c2926"),3,true)
		canvas.draw_arc(center,25,angle-0.75+phase*0.25,angle+0.35+phase*0.25,12,Color("b5a9bd"),1.5,true)
	else:
		var tip: Vector2 = -direction*actor.body_radius
		canvas.draw_line(tip-direction*12,tip,Color("1c2926"),3,true)
		canvas.draw_line(tip-direction*12,tip,Color("b5a9bd"),1.5,true)
