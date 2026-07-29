extends Node2D
class_name ArcPulseVisual

const BASE_EXPANSION_SPEED: float = 340.0
const START_RADIUS: float = 18.0
const HIT_HALF_WIDTH: float = 6.0
const MINIMUM_DAMAGE_MULTIPLIER: float = 0.25

var max_radius: float = 160.0
var lifetime: float = 0.42
var age: float = 0.0
var tint: Color = Color(0.18, 1.0, 0.95)
var damage: float = 0.0
var damage_source: StringName = &"arc"
var enemy_provider: Callable
var expansion_speed_scale: float = 1.0
var hit_enemy_ids: Dictionary = {}

func setup(
	radius: float,
	pulse_damage: float = 0.0,
	provider: Callable = Callable(),
	speed_scale: float = 1.0
) -> void:
	max_radius = radius
	damage = maxf(0.0, pulse_damage)
	enemy_provider = provider
	expansion_speed_scale = maxf(0.01, speed_scale)
	lifetime = maxf(0.01, (max_radius - START_RADIUS) / get_expansion_speed())

func _process(delta: float) -> void:
	var previous_radius := get_current_radius()
	age += delta
	var current_radius := get_current_radius()
	_damage_crossed_enemies(previous_radius, current_radius)
	if age >= lifetime:
		queue_free()
	queue_redraw()

func get_current_radius() -> float:
	return minf(max_radius, START_RADIUS + age * get_expansion_speed())

func get_expansion_speed() -> float:
	return BASE_EXPANSION_SPEED * expansion_speed_scale

func _damage_crossed_enemies(previous_radius: float, current_radius: float) -> void:
	if damage <= 0.0 or not enemy_provider.is_valid():
		return
	var provided: Variant = enemy_provider.call()
	if not provided is Array:
		return
	var inner_radius := maxf(0.0, minf(previous_radius, current_radius) - HIT_HALF_WIDTH)
	var outer_radius := maxf(previous_radius, current_radius) + HIT_HALF_WIDTH
	for enemy_value in provided:
		var enemy := enemy_value as Node2D
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var enemy_id := enemy.get_instance_id()
		if hit_enemy_ids.has(enemy_id):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < inner_radius or distance > outer_radius:
			continue
		hit_enemy_ids[enemy_id] = true
		var hit_direction := (enemy.global_position - global_position).normalized()
		enemy.take_damage(damage * get_damage_multiplier_at_distance(distance), damage_source, hit_direction)

func get_damage_multiplier_at_distance(distance: float) -> float:
	var normalized_distance := clampf(distance / maxf(1.0, max_radius), 0.0, 1.0)
	return lerpf(1.0, MINIMUM_DAMAGE_MULTIPLIER, normalized_distance)

func _draw() -> void:
	var p := clampf(age / lifetime, 0.0, 1.0)
	var radius := get_current_radius()
	var alpha := 1.0 - p
	var points := PackedVector2Array()
	var segments := 96
	for i in range(segments + 1):
		var a := float(i) * TAU / float(segments)
		var wave := sin(a * 9.0 + p * TAU * 3.0) * 8.0 * alpha
		points.append(Vector2.RIGHT.rotated(a) * (radius + wave))
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color(tint.r, tint.g, tint.b, 0.75 * alpha), 4.0)
		draw_line(points[i], points[i + 1], Color.WHITE, 1.0)
