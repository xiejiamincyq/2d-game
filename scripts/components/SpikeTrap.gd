extends Area2D
class_name SpikeTrap

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const MAX_SPIKES_PER_TARGET := 3
const ACTIVE_SPIKE_SOURCES_META: StringName = &"active_spike_damage_sources"

var damage: float = 12.0
var lifetime: float = 5.0
var max_lifetime: float = 5.0
var tick_interval: float = 0.35
var tick_timer: float = 0.0
var radius: float = 38.0
var damage_multiplier_provider: Callable
var damage_source: StringName = DamageTypes.SPIKE
var registered_bodies: Array[Node] = []

func _ready() -> void:
	z_index = -10
	max_lifetime = lifetime
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	body_exited.connect(_on_body_exited)

func _exit_tree() -> void:
	_release_all_bodies()

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
		if body.is_in_group("enemies") and body.has_method("take_damage") and _try_acquire_damage_slot(body):
			var hit_direction: Vector2 = (body.global_position - global_position).normalized()
			body.take_damage(resolved_damage, damage_source, hit_direction)

func _try_acquire_damage_slot(body: Node) -> bool:
	if registered_bodies.has(body):
		return true
	var active_sources: Dictionary = body.get_meta(ACTIVE_SPIKE_SOURCES_META, {})
	for source_id in active_sources.keys():
		var source_ref: WeakRef = active_sources[source_id]
		if source_ref == null or not is_instance_valid(source_ref.get_ref()):
			active_sources.erase(source_id)
	if active_sources.size() >= MAX_SPIKES_PER_TARGET:
		body.set_meta(ACTIVE_SPIKE_SOURCES_META, active_sources)
		return false
	active_sources[get_instance_id()] = weakref(self)
	body.set_meta(ACTIVE_SPIKE_SOURCES_META, active_sources)
	registered_bodies.append(body)
	return true

func _on_body_exited(body: Node) -> void:
	_release_body(body)

func _release_body(body: Node) -> void:
	registered_bodies.erase(body)
	if not is_instance_valid(body) or not body.has_meta(ACTIVE_SPIKE_SOURCES_META):
		return
	var active_sources: Dictionary = body.get_meta(ACTIVE_SPIKE_SOURCES_META)
	active_sources.erase(get_instance_id())
	if active_sources.is_empty():
		body.remove_meta(ACTIVE_SPIKE_SOURCES_META)
	else:
		body.set_meta(ACTIVE_SPIKE_SOURCES_META, active_sources)

func _release_all_bodies() -> void:
	for body in registered_bodies.duplicate():
		_release_body(body)
	registered_bodies.clear()

func get_resolved_damage() -> float:
	var multiplier := 1.0
	if damage_multiplier_provider.is_valid():
		multiplier = maxf(0.0, float(damage_multiplier_provider.call()))
	return damage * multiplier
