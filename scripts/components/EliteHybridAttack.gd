extends RefCounted
const TerrainAttack=preload("res://scripts/components/TerrainAttackDamage.gd")
const TerrainQuery=preload("res://scripts/components/TerrainDamageQuery.gd")
## Ordinary hybrid attack. Animation reads this clock; never emits gameplay.
enum Stage { IDLE, WARNING, ACTIVE, RECOVERY }
enum Mode { SWEEP, SHARDS }
const RECOVERY := 0.20
const SWEEP_REACH := 38.0
const AttackTiming = preload("res://scripts/components/EnemyAttackTiming.gd")
var stage := Stage.IDLE
var mode := Mode.SWEEP
var elapsed := 0.0
var cooldown := 0.8
var direction := Vector2.RIGHT
var origin := Vector2.ZERO
var target_position := Vector2.ZERO
var target_radius := 14.0
var did_hit := false
var released := false
var terrain_hit_ids: Dictionary={}
func is_active() -> bool: return stage!=Stage.IDLE
func get_warning_duration() -> float: return AttackTiming.RANGED_WARNING
func get_active_duration() -> float: return 0.12 if mode==Mode.SWEEP else 0.10
func consider(actor: Node2D,target: Node2D,delta: float) -> void:
	if not is_finite(delta) or delta<0: return
	cooldown = maxf(0,cooldown-delta)
	if cooldown>0 or is_active() or not is_instance_valid(target): return
	if actor.has_method("get_camera_safe_rect") and not actor.get_camera_safe_rect().has_point(actor.global_position): return
	var distance := actor.global_position.distance_to(target.global_position)
	if distance>260: return
	mode = Mode.SWEEP if distance<=52 else Mode.SHARDS
	origin = actor.global_position
	target_position = target.global_position
	direction = origin.direction_to(target_position)
	if direction==Vector2.ZERO: direction = Vector2.RIGHT
	var collision := target.get_node_or_null("PlayerCollision") as CollisionShape2D
	target_radius = (collision.shape as CircleShape2D).radius if collision!=null and collision.shape is CircleShape2D else 14.0
	elapsed = 0
	did_hit = false
	released = false
	terrain_hit_ids.clear()
	stage = Stage.WARNING
func advance(delta: float) -> void:
	if not is_active() or not is_finite(delta) or delta<0: return
	elapsed += delta
	var warning := get_warning_duration()
	var active := get_active_duration()
	if elapsed>=warning+active+RECOVERY: cancel()
	elif elapsed>=warning+active: stage = Stage.RECOVERY
	elif elapsed>=warning: stage = Stage.ACTIVE
func cancel() -> void:
	stage = Stage.IDLE
	cooldown = 2.6
	did_hit = false
	released = false
func take_release() -> bool:
	if stage!=Stage.ACTIVE or mode!=Mode.SHARDS or released: return false
	released = true
	return true
func resolve_hit(actor: CharacterBody2D,target: Node2D) -> void:
	_resolve_player_hit(actor,target)
	if stage!=Stage.ACTIVE or mode!=Mode.SWEEP or not TerrainAttack.live(actor): return
	var points:=PackedVector2Array([origin])
	for index in 17: points.append(origin+direction.rotated(lerpf(-0.70,0.70,index/16.0))*SWEEP_REACH)
	TerrainAttack.apply(actor,TerrainQuery.collect_in_polygon(actor,points),origin,actor.contact_damage,&"enemy",terrain_hit_ids,func(): return stage==Stage.ACTIVE and mode==Mode.SWEEP)
func _resolve_player_hit(actor: CharacterBody2D,target: Node2D) -> void:
	if stage!=Stage.ACTIVE or mode!=Mode.SWEEP or did_hit or not is_instance_valid(target): return
	if target.is_queued_for_deletion() or not target.has_method("take_damage"): return
	if target.has_method("is_stealthed") and target.is_stealthed(): return
	var offset := target.global_position-origin
	if offset.length()>SWEEP_REACH+target_radius: return
	if offset.length()>0.001 and offset.normalized().dot(direction)<cos(0.70): return
	var ray := PhysicsRayQueryParameters2D.create(origin,target.global_position,actor.collision_mask,[actor.get_rid()])
	var wall := actor.get_world_2d().direct_space_state.intersect_ray(ray)
	if not wall.is_empty() and wall.collider!=target: return
	did_hit = true
	target.take_damage(actor.contact_damage)
func draw_strikes(canvas: Node2D,actor: Node2D) -> void:
	if stage!=Stage.ACTIVE or mode!=Mode.SWEEP: return
	var base := actor.to_local(origin)
	var side := direction.orthogonal()
	for sign_value in [-1,1]:
		var start: Vector2 = base+direction*12+side*sign_value*12
		var finish: Vector2 = base+direction*38-side*sign_value*7
		canvas.draw_line(start,finish,Color("1c2926"),3,true)
		canvas.draw_line(start,finish,Color("b5acc0"),1.5,true)
