extends Area2D
class_name FlameTrail

const Palette = preload("res://scripts/effects/FriendlyEffectPalette.gd")
const TerrainDamage = preload("res://scripts/components/TerrainDamageQuery.gd")
const TerrainBurn = preload("res://scripts/components/TerrainBurnReceiver.gd")

const RADIUS := 22.0
const STACK_INTERVAL := 0.20

var burn_base_attack := 10.0
var burn_duration := 4.0
var slow_fraction := 0.30
var lifetime := 4.0
var stack_timers: Dictionary = {}
var visual_age := 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = -1
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	visual_age += delta
	_update_burning_enemies(delta)
	if lifetime <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _update_burning_enemies(delta: float) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_finite(delta) or delta<=0: return
	var overlapping: Array[Node] = []
	overlapping.append_array(get_overlapping_bodies())
	overlapping.append_array(get_overlapping_areas())
	overlapping.append_array(TerrainDamage.collect_in_circle(self,global_position,RADIUS))
	var active_ids: Dictionary = {}
	for enemy in overlapping:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or (not enemy.is_in_group(&"enemies") and not enemy.is_in_group(&"destructible_terrain")):
			continue
		var enemy_id := enemy.get_instance_id()
		if active_ids.has(enemy_id): continue
		active_ids[enemy_id] = true
		var timer := float(stack_timers.get(enemy_id, 0.0)) + delta
		while timer >= STACK_INTERVAL:
			timer -= STACK_INTERVAL
			if enemy.is_in_group(&"destructible_terrain"):
				TerrainBurn.apply(enemy,burn_base_attack,burn_duration)
			elif enemy.has_method("apply_burn_stack"):
				enemy.apply_burn_stack(burn_base_attack, burn_duration, slow_fraction)
			if not is_inside_tree() or is_queued_for_deletion(): return
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): break
		stack_timers[enemy_id] = timer
	for enemy_id in stack_timers.keys():
		if not active_ids.has(enemy_id):
			stack_timers.erase(enemy_id)

func _draw() -> void:
	var pulse := 0.82 + sin(visual_age * 12.0 + float(get_instance_id() % 13)) * 0.12
	draw_circle(Vector2.ZERO, RADIUS, Color(Palette.TEAL, 0.13))
	for index in range(5):
		var angle := TAU * float(index) / 5.0
		var base := Vector2.RIGHT.rotated(angle) * 10.0
		var sway := sin(visual_age * 8.0 + float(index) * 1.7) * (4.0 + float(index % 2))
		var flame := PackedVector2Array([
			base + Vector2(-5.0, 8.0),
			base + Vector2(sway, -15.0 * pulse - float(index % 2) * 4.0),
			base + Vector2(5.0, 8.0),
		])
		draw_colored_polygon(flame, Palette.MINT)
	draw_circle(Vector2.ZERO, 6.0, Palette.CREAM)
