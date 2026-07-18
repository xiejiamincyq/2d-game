extends Area2D
class_name SpikeTrap

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")

var damage: float = 12.0
var lifetime: float = 5.0
var max_lifetime: float = 5.0
var tick_interval: float = 0.35
var tick_timer: float = 0.0
var radius: float = 38.0
var damage_multiplier_provider: Callable

func _ready() -> void:
	max_lifetime = lifetime
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)

func _process(delta: float) -> void:
	lifetime -= delta
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		_damage_enemies()
	if lifetime <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var fade := clampf(lifetime / maxf(0.1, max_lifetime), 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(0.95, 0.18, 0.75, 0.08 * fade))
	for i in range(12):
		var angle := float(i) * TAU / 12.0
		var inner := Vector2.RIGHT.rotated(angle) * 8.0
		var outer := Vector2.RIGHT.rotated(angle) * radius
		draw_line(inner, outer, Color(1.0, 0.24, 0.82, 0.72 * fade), 3.0)
		draw_circle(outer, 3.0, Color(0.2, 1.0, 0.95, 0.85 * fade))

func _damage_enemies() -> void:
	var resolved_damage := get_resolved_damage()
	for body in get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			var hit_direction: Vector2 = (body.global_position - global_position).normalized()
			body.take_damage(resolved_damage, DamageTypes.SPIKE, hit_direction)

func get_resolved_damage() -> float:
	var multiplier := 1.0
	if damage_multiplier_provider.is_valid():
		multiplier = maxf(0.0, float(damage_multiplier_provider.call()))
	return damage * multiplier
