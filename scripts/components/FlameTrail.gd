extends Area2D
class_name FlameTrail

const RADIUS := 22.0

var burn_damage_per_second := 10.0
var burn_duration := 4.0
var slow_fraction := 0.30
var lifetime := 4.0
var affected_ids: Dictionary = {}

func _ready() -> void:
	z_index = -1
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_apply_to_enemy)
	area_entered.connect(_apply_to_enemy)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _apply_to_enemy(enemy: Node) -> void:
	if not enemy.is_in_group(&"enemies") or affected_ids.has(enemy.get_instance_id()):
		return
	affected_ids[enemy.get_instance_id()] = true
	if enemy.has_method("apply_burn"):
		enemy.apply_burn(burn_damage_per_second, burn_duration, slow_fraction)

func _draw() -> void:
	var pulse := 0.82 + sin(Time.get_ticks_msec() * 0.012 + float(get_instance_id() % 13)) * 0.12
	draw_circle(Vector2.ZERO, RADIUS, Color(0.45, 0.12, 0.75, 0.13))
	for index in range(5):
		var angle := TAU * float(index) / 5.0
		var base := Vector2.RIGHT.rotated(angle) * 10.0
		var flame := PackedVector2Array([
			base + Vector2(-5.0, 8.0),
			base + Vector2(0.0, -15.0 * pulse - float(index % 2) * 4.0),
			base + Vector2(5.0, 8.0),
		])
		draw_colored_polygon(flame, Color("b45cff"))
	draw_circle(Vector2.ZERO, 6.0, Color("f559bf"))
