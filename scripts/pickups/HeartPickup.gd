extends Area2D
class_name HeartPickup

signal collected(value: float)

@export var value: float = 20.0
var collected_once := false

func _ready() -> void:
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return
	var health: Variant = body.get("health")
	if health == null or float(health.current_health) >= float(health.max_health):
		return
	_try_collect()

func _try_collect() -> bool:
	if collected_once:
		return false
	collected_once = true
	set_deferred("monitoring", false)
	collected.emit(value)
	queue_free()
	return true

func _draw() -> void:
	var glow := Color("f559bf")
	draw_circle(Vector2(-4.0, -2.0), 5.5, Color(glow, 0.88))
	draw_circle(Vector2(4.0, -2.0), 5.5, Color(glow, 0.88))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9.0, 0.0), Vector2(0.0, 11.0), Vector2(9.0, 0.0), Vector2.ZERO,
	]), glow)
	draw_line(Vector2(-3.0, 0.0), Vector2(3.0, 0.0), Color.WHITE, 1.5)
	draw_line(Vector2.ZERO, Vector2(0.0, 6.0), Color.WHITE, 1.5)
