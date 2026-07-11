extends Area2D
class_name Projectile

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")

var velocity: Vector2 = Vector2.ZERO
var damage: float = 1.0
var pierce: int = 0
var lifetime: float = 6.0
var target_group: StringName = &"enemies"
var hit_bodies: Array[Node] = []
var tint: Color = Color.CYAN
var radius: float = 4.0
var world_bounds: Rect2 = Rect2()
var damage_source: StringName = DamageTypes.PROJECTILE

func _ready() -> void:
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	if world_bounds.size != Vector2.ZERO and not world_bounds.has_point(global_position):
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	draw_rect(Rect2(Vector2(-radius, -radius), Vector2(radius * 2.0, radius * 2.0)), tint)
	draw_rect(Rect2(Vector2(-radius * 0.5, -radius * 0.5), Vector2(radius, radius)), Color.WHITE)

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)

func _try_hit(node: Node) -> void:
	if not node.is_in_group(target_group) or hit_bodies.has(node):
		return
	hit_bodies.append(node)
	if node.has_method("take_damage"):
		node.take_damage(damage, damage_source)
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1
