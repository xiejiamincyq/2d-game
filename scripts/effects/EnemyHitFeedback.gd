extends Node2D

# AB: a compact comic core with sparse, directional slash ticks. One live
# impact per actor; sustained damage cannot pile up nodes or opaque bursts.
const Palette = preload("res://scripts/effects/FriendlyEffectPalette.gd")
const OUTLINE := Color("123b3b")
const MIN_INTERVAL := 0.065
var life := 0.0
var duration := 0.10
var cooldown := 0.0
var anchor := Vector2.ZERO
var direction := Vector2.RIGHT
var radius := 7.0

func _ready() -> void:
	z_index = 1
	set_process(false)

func request_hit(incoming: Vector2, body_radius: float, damage: float) -> void:
	if cooldown > 0.0 or damage <= 0.0:
		return
	direction = incoming.normalized()
	anchor = -direction * clampf(body_radius, 8.0, 64.0)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	radius = 11.0 if damage >= 40.0 else 7.0
	duration = 0.14 if damage >= 40.0 else 0.10
	life = duration
	cooldown = MIN_INTERVAL
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	# Boss entrance uses ALWAYS processing; hit decoration still freezes in menus.
	if get_tree().paused:
		return
	life = maxf(0.0, life - maxf(0.0, delta))
	cooldown = maxf(0.0, cooldown - maxf(0.0, delta))
	queue_redraw()
	if is_zero_approx(life):
		set_process(false)

func _draw() -> void:
	if life <= 0.0:
		return
	var alpha := clampf(life / duration * 2.0, 0.0, 1.0)
	var axis := -direction
	var side := axis.orthogonal()
	var points := PackedVector2Array([
		anchor + axis * radius, anchor + (axis + side) * radius * 0.26,
		anchor + side * radius * 0.70, anchor + (-axis + side) * radius * 0.24,
		anchor - axis * radius * 0.60, anchor - (axis + side) * radius * 0.24,
		anchor - side * radius * 0.70, anchor + (axis - side) * radius * 0.26,
	])
	draw_colored_polygon(points, Color(Palette.CREAM, alpha))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(OUTLINE, alpha), 2.0, true)
	for sign_value in [-1.0, 1.0]:
		var tick: Vector2 = (axis + side * float(sign_value) * 0.85).normalized()
		draw_line(anchor + tick * radius * 1.15, anchor + tick * radius * 1.55, Color(OUTLINE, alpha), 3.0, true)
		draw_line(anchor + tick * radius * 1.15, anchor + tick * radius * 1.55, Color(Palette.CREAM, alpha), 1.0, true)
