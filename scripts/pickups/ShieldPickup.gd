extends Area2D
class_name ShieldPickup

signal collected(value: float)

@export var value: float = 9.0
var drift_speed: float = 420.0
var magnetized: bool = false
var collected_once: bool = false

func _ready() -> void:
	set_deferred("monitoring", true)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	if distance <= player.pickup_radius:
		magnetized = true
	if magnetized:
		global_position = global_position.move_toward(player.global_position, drift_speed * delta)
	if distance <= 18.0:
		_try_collect()
	queue_redraw()

func _draw() -> void:
	draw_polygon(PackedVector2Array([
		Vector2(0, -12),
		Vector2(10, -7),
		Vector2(8, 5),
		Vector2(0, 13),
		Vector2(-8, 5),
		Vector2(-10, -7)
	]), PackedColorArray([Color(0.25, 1.0, 0.35, 0.92)]))
	draw_polyline(PackedVector2Array([
		Vector2(0, -8),
		Vector2(6, -4),
		Vector2(5, 4),
		Vector2(0, 9),
		Vector2(-5, 4),
		Vector2(-6, -4),
		Vector2(0, -8)
	]), Color(0.85, 1.0, 0.82), 2.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_try_collect()

func _try_collect() -> bool:
	if collected_once:
		return false
	collected_once = true
	set_deferred("monitoring", false)
	collected.emit(value)
	queue_free()
	return true
