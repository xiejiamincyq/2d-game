extends "res://scripts/components/Projectile.gd"
class_name GrenadeProjectile

signal exploded(world_position: Vector2, radius: float)

const TerrainDamage = preload("res://scripts/components/TerrainDamageQuery.gd")
const PROXIMITY_RADIUS := 44.0
const EXPLOSION_RADIUS := 82.0

var enemy_provider: Callable
var exploded_once := false

func _init() -> void:
	radius=7.0; damage=30.0; tint=Color("ff571f")

func _physics_process(delta: float) -> void:
	if not _live() or not is_finite(delta) or delta<=0: return
	if world_bounds.size!=Vector2.ZERO and not world_bounds.has_point(global_position):
		queue_free(); return
	var seconds:=_legal_flight_seconds(delta)
	if seconds<=0:
		if lifetime<=0: _explode()
		else: queue_free()
		return
	# Reuse the already-tested Circle/first-wall sweep, but contact spends only
	# the explosion, never an extra ordinary-projectile direct damage hit.
	if _stop_at_terrain(velocity*seconds): return
	global_position+=velocity*seconds
	lifetime-=seconds
	if _has_nearby_enemy():
		_explode()
		return
	if not _live(): return
	if world_bounds.size != Vector2.ZERO and not world_bounds.has_point(global_position):
		queue_free()
		return
	if lifetime <= 0.0:
		_explode()

func _live() -> bool: return is_inside_tree() and not is_queued_for_deletion()

func _try_hit(node: Node) -> void:
	if _live() and _is_eligible_target(node): _explode()

func _has_nearby_enemy() -> bool:
	for enemy in _get_enemies():
		var node := enemy as Node2D
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion() and not node.is_in_group(&"destructible_terrain") and global_position.distance_to(node.global_position) <= PROXIMITY_RADIUS:
			return true
	return false

func _explode() -> void:
	if exploded_once or not _live():
		return
	exploded_once = true
	var resolved_damage := get_resolved_damage()
	if not _live(): queue_free(); return
	var candidates:=_get_enemies()
	if not _live(): queue_free(); return
	var targets: Array[Node2D]=[]
	var seen: Dictionary={}
	for enemy in candidates:
		var node := enemy as Node2D
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion() or node.is_in_group(&"destructible_terrain") or not node.has_method("take_damage"):
			continue
		var target_radius := float(node.get("body_radius")) if node.get("body_radius") != null else 0.0
		if global_position.distance_to(node.global_position) > EXPLOSION_RADIUS + target_radius:
			continue
		targets.append(node)
	targets.append_array(TerrainDamage.collect_in_circle(self,global_position,EXPLOSION_RADIUS))
	for node in targets:
		if not is_instance_valid(node) or node.is_queued_for_deletion() or seen.has(node.get_instance_id()): continue
		seen[node.get_instance_id()]=true
		var direction: Vector2=(node.global_position-global_position).normalized()
		node.take_damage(resolved_damage,DamageTypes.PROJECTILE,direction)
		if not _live(): queue_free(); return
	exploded.emit(global_position, EXPLOSION_RADIUS)
	queue_free()

func _get_enemies() -> Array:
	if enemy_provider.is_valid():
		var provided: Variant = enemy_provider.call()
		if provided is Array:
			return provided
	if is_inside_tree():
		return get_tree().get_nodes_in_group(&"enemies")
	return []

func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color(tint, 0.18))
	draw_circle(Vector2.ZERO, 7.0, Color("321327"))
	draw_arc(Vector2.ZERO, 7.0, -PI * 0.3, PI * 1.4, 18, tint, 2.5)
	draw_circle(Vector2(2.0, -2.0), 2.0, Color.WHITE)
