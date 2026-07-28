extends Area2D
class_name GrenadeProjectile

signal exploded(world_position: Vector2, radius: float)

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const PROXIMITY_RADIUS := 44.0
const EXPLOSION_RADIUS := 82.0

var velocity := Vector2.ZERO
var damage := 30.0
var lifetime := 6.0
var world_bounds := Rect2()
var enemy_provider: Callable
var damage_multiplier_provider: Callable
var exploded_once := false
var tint := Color("ff571f")

func _ready() -> void:
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(func(body: Node) -> void:
		if body.is_in_group(&"enemies"):
			_explode()
	)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	if _has_nearby_enemy():
		_explode()
		return
	if world_bounds.size != Vector2.ZERO and not world_bounds.has_point(global_position):
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()

func _has_nearby_enemy() -> bool:
	for enemy in _get_enemies():
		var node := enemy as Node2D
		if node != null and is_instance_valid(node) and global_position.distance_to(node.global_position) <= PROXIMITY_RADIUS:
			return true
	return false

func _explode() -> void:
	if exploded_once:
		return
	exploded_once = true
	var resolved_damage := get_resolved_damage()
	for enemy in _get_enemies():
		var node := enemy as Node2D
		if node == null or not is_instance_valid(node) or not node.has_method("take_damage"):
			continue
		var target_radius := float(node.get("body_radius")) if node.get("body_radius") != null else 0.0
		if global_position.distance_to(node.global_position) > EXPLOSION_RADIUS + target_radius:
			continue
		var direction := (node.global_position - global_position).normalized()
		node.take_damage(resolved_damage, DamageTypes.PROJECTILE, direction)
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

func get_resolved_damage() -> float:
	var multiplier := 1.0
	if damage_multiplier_provider.is_valid():
		multiplier = maxf(0.0, float(damage_multiplier_provider.call()))
	return damage * multiplier

func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color(tint, 0.18))
	draw_circle(Vector2.ZERO, 7.0, Color("321327"))
	draw_arc(Vector2.ZERO, 7.0, -PI * 0.3, PI * 1.4, 18, tint, 2.5)
	draw_circle(Vector2(2.0, -2.0), 2.0, Color.WHITE)
