extends Area2D
class_name CoinPickup

signal collected(value: int)

@export var value: int = 1
var drift_speed: float = 460.0
var magnetized: bool = false
var collected_once: bool = false

func _ready() -> void:
	set_deferred("monitoring", true)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
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

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.72, 0.08))
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 18, Color(1.0, 0.95, 0.45), 2.0)
	draw_line(Vector2(0.0, -4.0), Vector2(0.0, 4.0), Color(0.48, 0.22, 0.02), 2.0)

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
