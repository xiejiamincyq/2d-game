extends RefCounted
const TerrainAttack=preload("res://scripts/components/TerrainAttackDamage.gd")
## Locked world-space line; skeletal animation never owns damage or physics.
enum Stage { IDLE, WARNING, ACTIVE, RECOVERY }
const RECOVERY := 0.24
const REACH := 170.0
const HALF_WIDTH := 1.5
const AttackTiming = preload("res://scripts/components/EnemyAttackTiming.gd")
var stage := Stage.IDLE
var elapsed := 0.0
var cooldown := 1.0
var origin := Vector2.ZERO
var direction := Vector2.RIGHT
var line_end := Vector2.ZERO
var target_radius := 14.0
var did_hit := false
var line_resolved := false
var terrain_hit_ids: Dictionary={}
func is_active() -> bool: return stage!=Stage.IDLE
func get_warning_duration() -> float: return AttackTiming.RANGED_WARNING
func get_active_duration() -> float: return 0.14
func consider(actor: Node2D,target: Node2D,delta: float) -> void:
	if not is_finite(delta) or delta<0: return
	cooldown = maxf(0,cooldown-delta)
	if cooldown>0 or is_active() or not is_instance_valid(target) or target.is_queued_for_deletion(): return
	if target.has_method("is_stealthed") and target.is_stealthed(): return
	if actor.has_method("get_camera_safe_rect") and not actor.get_camera_safe_rect().has_point(actor.global_position): return
	if actor.global_position.distance_to(target.global_position)>230: return
	origin = actor.global_position
	direction = origin.direction_to(target.global_position)
	if direction==Vector2.ZERO: direction = Vector2.RIGHT
	line_end = origin+direction*REACH
	var collision := target.get_node_or_null("PlayerCollision") as CollisionShape2D
	target_radius = (collision.shape as CircleShape2D).radius if collision!=null and collision.shape is CircleShape2D else 14.0
	did_hit = false
	line_resolved = false
	terrain_hit_ids.clear()
	elapsed = 0
	stage = Stage.WARNING
func advance(delta: float) -> void:
	if not is_active() or not is_finite(delta) or delta<0: return
	elapsed += delta
	if elapsed>=get_warning_duration()+get_active_duration()+RECOVERY: cancel()
	elif elapsed>=get_warning_duration()+get_active_duration(): stage = Stage.RECOVERY
	elif elapsed>=get_warning_duration(): stage = Stage.ACTIVE
func cancel() -> void:
	stage = Stage.IDLE
	cooldown = 2.6
	did_hit = false
	line_resolved = false
func resolve_hit(actor: CharacterBody2D,target: Node2D) -> void:
	_resolve_player_hit(actor,target)
	if stage!=Stage.ACTIVE or not line_resolved or origin.distance_to(line_end)<=10 or not TerrainAttack.live(actor): return
	var targets:=TerrainAttack.segment(actor,origin+direction*10,line_end,HALF_WIDTH)
	TerrainAttack.apply(actor,targets,origin,actor.contact_damage,&"enemy",terrain_hit_ids,func(): return stage==Stage.ACTIVE and line_resolved)
func _resolve_player_hit(actor: CharacterBody2D,target: Node2D) -> void:
	if stage!=Stage.ACTIVE or not is_instance_valid(target) or target.is_queued_for_deletion(): return
	if target.has_method("is_stealthed") and target.is_stealthed(): return
	var space := actor.get_world_2d().direct_space_state
	if not line_resolved:
		var query := PhysicsRayQueryParameters2D.create(origin,origin+direction*REACH,actor.collision_mask,[actor.get_rid()])
		if target is CollisionObject2D: query.exclude = [actor.get_rid(),target.get_rid()]
		var obstruction := space.intersect_ray(query)
		line_end = obstruction.position if not obstruction.is_empty() else origin+direction*REACH
		line_resolved = true
	if did_hit or not target.has_method("take_damage"): return
	var span := origin.distance_to(line_end)
	if span<=10: return
	var projection := clampf((target.global_position-origin).dot(direction),10,span)
	var closest := origin+direction*projection
	if target.global_position.distance_to(closest)>target_radius+HALF_WIDTH: return
	var ray := PhysicsRayQueryParameters2D.create(origin,target.global_position,actor.collision_mask,[actor.get_rid()])
	var wall := space.intersect_ray(ray)
	if not wall.is_empty() and wall.collider!=target: return
	did_hit = true
	target.take_damage(actor.contact_damage)
func draw_line_cut(canvas: Node2D,actor: Node2D) -> void:
	if stage!=Stage.ACTIVE or not line_resolved or origin.distance_to(line_end)<=10: return
	var start := actor.to_local(origin+direction*10)
	var finish := actor.to_local(line_end)
	canvas.draw_line(start,finish,Color("1c2926"),5,true)
	canvas.draw_line(start,finish,Color("c6b7a0"),3,true)
	var mid := start.lerp(finish,0.5)
	canvas.draw_line(mid-direction.orthogonal()*3,mid+direction.orthogonal()*3,Color("dfd5bf"),1,true)
