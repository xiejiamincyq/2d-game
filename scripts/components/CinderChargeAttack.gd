extends RefCounted
const TerrainAttack=preload("res://scripts/components/TerrainAttackDamage.gd")
## Ordinary ram-runner only. Motion uses each phase's actual subinterval;
## visual clips cannot deal damage, steer, teleport, or advance this clock.
enum Stage { IDLE, WARNING, ACTIVE, RECOVERY }
const WARNING := 0.40
const ACTIVE := 0.36
const RECOVERY := 0.24
const SPEED := 440.0
const COOLDOWN := 3.6
var stage := Stage.IDLE
var elapsed := 0.0
var cooldown := 1.2
var direction := Vector2.RIGHT
var origin := Vector2.ZERO
var did_hit := false
var target_radius := 13.0
var blocked := false
var terrain_hit_ids: Dictionary={}

func is_active() -> bool:
	return stage != Stage.IDLE

func cancel() -> void:
	stage = Stage.IDLE
	elapsed = 0
	cooldown = COOLDOWN
	did_hit = false

func tick(actor: CharacterBody2D, target: Node2D, delta: float) -> bool:
	if not is_finite(delta) or delta <= 0:
		return is_active()
	if not is_instance_valid(target):
		if is_active():
			cancel()
		actor.velocity = Vector2.ZERO
		return false
	var remaining := delta
	if stage == Stage.IDLE:
		remaining = maxf(0,delta-cooldown)
		cooldown = maxf(0,cooldown-delta)
		var distance := actor.global_position.distance_to(target.global_position)
		if cooldown > 0 or actor.is_attacking or distance < 72 or distance > 176:
			return false
		origin = actor.global_position
		direction = origin.direction_to(target.global_position)
		target_radius = 13
		var shape := target.get_node_or_null("PlayerCollision") as CollisionShape2D
		if shape != null and shape.shape is CircleShape2D:
			target_radius = shape.shape.radius
		stage = Stage.WARNING
		elapsed = 0
		did_hit = false
		blocked = false
		terrain_hit_ids.clear()
	actor.velocity = Vector2.ZERO
	while remaining > 0.000001 and is_active():
		var duration: float = WARNING if stage == Stage.WARNING else ACTIVE if stage == Stage.ACTIVE else RECOVERY
		var step := minf(remaining,duration-elapsed)
		if stage == Stage.ACTIVE and step > 0:
			var start := actor.global_position
			actor.velocity = direction * SPEED
			var collision := actor.move_and_collide(actor.velocity * step)
			var unclamped := actor.global_position
			actor._clamp_to_world_bounds()
			_resolve_hit(actor,target,start,actor.global_position)
			if collision != null or not actor.global_position.is_equal_approx(unclamped):
				blocked = true
				stage = Stage.RECOVERY
				elapsed = 0
				actor.velocity = Vector2.ZERO
				return true
		elapsed += step
		remaining -= step
		if elapsed >= duration-0.000001:
			elapsed = 0
			match stage:
				Stage.WARNING:
					stage = Stage.ACTIVE
				Stage.ACTIVE:
					stage = Stage.RECOVERY
					actor.velocity = Vector2.ZERO
				Stage.RECOVERY:
					stage = Stage.IDLE
					cooldown = maxf(0,COOLDOWN-remaining)
					actor.velocity = Vector2.ZERO
	return true

func _resolve_hit(actor: CharacterBody2D, target: Node2D, start: Vector2, end: Vector2) -> void:
	_resolve_player_hit(actor,target,start,end)
	if stage!=Stage.ACTIVE or not TerrainAttack.live(actor): return
	var targets:=TerrainAttack.segment(actor,start,end,actor.body_radius+actor.safe_margin+0.5)
	TerrainAttack.apply(actor,targets,start,actor.contact_damage,&"enemy",terrain_hit_ids,func(): return stage==Stage.ACTIVE)

func _resolve_player_hit(actor: CharacterBody2D, target: Node2D, start: Vector2, end: Vector2) -> void:
	if did_hit or not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	var closest := Geometry2D.get_closest_point_to_segment(target.global_position,start,end)
	var reach: float = actor.body_radius + target_radius + actor.safe_margin + 0.5
	if closest.distance_to(target.global_position) > reach:
		return
	var ray := PhysicsRayQueryParameters2D.create(closest,target.global_position,actor.collision_mask,[actor.get_rid()])
	var blocker := actor.get_world_2d().direct_space_state.intersect_ray(ray)
	if not blocker.is_empty() and blocker.collider != target:
		return
	did_hit = true
	target.take_damage(actor.contact_damage)

func get_attack_strokes(actor: Node2D) -> Array[PackedVector2Array]:
	if stage != Stage.ACTIVE:
		return []
	var traveled := maxf(0,(actor.global_position-origin).dot(direction)-14)
	if traveled <= 0:
		return []
	var end := -direction * 14
	return [PackedVector2Array([end-direction*minf(22,traveled),end])]
