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
var damage_multiplier_provider: Callable
var overdrive_visual: bool = false

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
	if overdrive_visual:
		_add_overdrive_particles()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	if world_bounds.size != Vector2.ZERO and not world_bounds.has_point(global_position):
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	if overdrive_visual:
		draw_circle(Vector2.ZERO, radius * 3.0, Color(0.71, 0.36, 1.0, 0.14))
		draw_circle(Vector2.ZERO, radius * 1.75, Color(0.78, 0.42, 1.0, 0.32))
	draw_rect(Rect2(Vector2(-radius, -radius), Vector2(radius * 2.0, radius * 2.0)), tint)
	draw_rect(Rect2(Vector2(-radius * 0.5, -radius * 0.5), Vector2(radius, radius)), Color.WHITE)

func _add_overdrive_particles() -> void:
	var particles := GPUParticles2D.new()
	particles.name = "OverdriveParticles"
	particles.amount = 18
	particles.lifetime = 0.24
	particles.local_coords = false
	particles.texture = _make_overdrive_particle_texture()
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = radius * 0.55
	var trail_direction := -velocity.normalized()
	material.direction = Vector3(trail_direction.x, trail_direction.y, 0.0)
	material.spread = 24.0
	material.initial_velocity_min = 68.0
	material.initial_velocity_max = 118.0
	material.scale_min = 0.45
	material.scale_max = 0.9
	material.color = Color("b45cff")
	particles.process_material = material
	add_child(particles)

func _make_overdrive_particle_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.96, 0.82, 1.0, 1.0),
		Color(0.71, 0.36, 1.0, 0.75),
		Color(0.71, 0.36, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 16
	texture.height = 16
	texture.fill = GradientTexture2D.FILL_RADIAL
	return texture

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
