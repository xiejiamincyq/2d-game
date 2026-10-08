extends Area2D
class_name Projectile

const Palette = preload("res://scripts/effects/FriendlyEffectPalette.gd")
const HostilePalette = preload("res://scripts/effects/HostileEffectPalette.gd")

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
var damage_multiplier_provider: Callable
var overdrive_visual: bool = false
var overdrive_trail: Node2D

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
	if overdrive_visual and target_group != &"player":
		overdrive_trail = Node2D.new()
		overdrive_trail.name = "OverdriveTrail"
		overdrive_trail.z_as_relative = false
		overdrive_trail.z_index = -1
		overdrive_trail.draw.connect(_draw_overdrive_trail)
		add_child(overdrive_trail)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	if world_bounds.size != Vector2.ZERO and not world_bounds.has_point(global_position):
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	if target_group == &"player":
		# Visual padding only: the physics circle remains the configured radius.
		_draw_hostile_trail()
		draw_circle(Vector2.ZERO, radius + 1.5, HostilePalette.OUTLINE)
		draw_circle(Vector2.ZERO, radius, tint)
		draw_circle(Vector2(-radius * 0.2, -radius * 0.2), radius * 0.4, HostilePalette.CREAM)
		return
	draw_rect(Rect2(Vector2(-radius, -radius), Vector2(radius * 2.0, radius * 2.0)), tint)
	draw_rect(Rect2(Vector2(-radius * 0.5, -radius * 0.5), Vector2(radius, radius)), Color.WHITE)

func get_hostile_trail_points() -> PackedVector2Array:
	if target_group != &"player" or velocity.length_squared() < 0.001:
		return PackedVector2Array()
	var direction := velocity.normalized()
	var side := direction.orthogonal()
	return PackedVector2Array([-direction * radius * 4.2, -direction * radius * 0.7 + side * radius * 0.65, -direction * radius * 0.7 - side * radius * 0.65])

func _draw_hostile_trail() -> void:
	var points := get_hostile_trail_points()
	if points.is_empty():
		return
	draw_colored_polygon(points, Color(tint, 0.35))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(HostilePalette.OUTLINE, 0.80), 1.5, true)

func _draw_overdrive_trail() -> void:
	if overdrive_visual and target_group != &"player":
		var direction := velocity.normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		var side := direction.orthogonal()
		var trail := PackedVector2Array([
			-direction * radius * 7.0,
			-direction * radius * 1.2 + side * radius * 1.1,
			direction * radius * 0.5,
			-direction * radius * 1.2 - side * radius * 1.1,
		])
		overdrive_trail.draw_colored_polygon(trail, Color(Palette.TEAL, 0.26))
		overdrive_trail.draw_line(-direction * radius * 6.0, direction * radius * 0.5, Color(Palette.CREAM, 0.68), 1.5)
		overdrive_trail.draw_circle(Vector2.ZERO, radius * 3.0, Color(Palette.MINT, 0.14))
		overdrive_trail.draw_circle(Vector2.ZERO, radius * 1.75, Color(Palette.MINT, 0.32))

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)

func _try_hit(node: Node) -> void:
	if not node.is_in_group(target_group) or hit_bodies.has(node):
		return
	hit_bodies.append(node)
	if node.has_method("take_damage"):
		var resolved_damage := get_resolved_damage()
		if node.is_in_group(&"enemies"):
			node.take_damage(resolved_damage, damage_source, velocity.normalized())
		else:
			node.take_damage(resolved_damage, damage_source)
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1

func get_resolved_damage() -> float:
	var multiplier := 1.0
	if damage_multiplier_provider.is_valid():
		multiplier = maxf(0.0, float(damage_multiplier_provider.call()))
	return damage * multiplier
