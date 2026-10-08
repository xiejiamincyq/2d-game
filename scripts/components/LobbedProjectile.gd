extends Node2D
class_name LobbedProjectile

const WARNING_COLOR := Color("f27a4b")
const OUTLINE_COLOR := Color("123b3b")
const HIGHLIGHT_COLOR := Color("f3eddc")

# A brief broken rim marks the instantaneous impact, not a persistent hazard.
class ImpactVisual extends Node2D:
	const DURATION := 0.20
	var radius := 72.0
	var elapsed := 0.0
	func _ready() -> void:
		z_as_relative = false
		z_index = -1

	func _process(delta: float) -> void:
		elapsed += maxf(0.0, delta)
		queue_redraw()
		if elapsed >= DURATION:
			queue_free()

	func _draw() -> void:
		var alpha := clampf(1.0 - elapsed / DURATION, 0.0, 1.0)
		for index in range(6):
			var angle := TAU * index / 6.0
			draw_arc(Vector2.ZERO, radius, angle, angle + PI * 0.22, 8, Color(OUTLINE_COLOR, alpha), 5.0, true)
			draw_arc(Vector2.ZERO, radius, angle, angle + PI * 0.22, 8, Color(WARNING_COLOR, alpha), 3.0, true)
			var direction := Vector2.RIGHT.rotated(angle)
			draw_line(direction * radius * 0.78, direction * radius, Color(OUTLINE_COLOR, alpha), 4.0, true)
			draw_line(direction * radius * 0.78, direction * radius, Color(WARNING_COLOR, alpha), 2.0, true)
			draw_line(direction * radius * 0.80, direction * radius * 0.90, Color(HIGHLIGHT_COLOR, alpha), 1.0, true)

var target_player: Node2D
var target_position := Vector2.ZERO
var damage := 42.0
var splash_radius := 72.0
var flight_duration := 0.85
var elapsed := 0.0
var start_position := Vector2.ZERO
var tint := WARNING_COLOR
var landing_fill: Node2D

func configure(origin: Vector2, destination: Vector2, target: Node2D) -> void:
	global_position = origin
	start_position = origin
	target_position = destination
	target_player = target
	_update_landing_fill()

func _ready() -> void:
	start_position = global_position
	landing_fill = Node2D.new()
	landing_fill.name = "LandingFill"
	# Ground tint stays below actors regardless of the projectile parent's layer.
	landing_fill.z_as_relative = false
	landing_fill.z_index = -1
	landing_fill.draw.connect(_draw_landing_fill)
	add_child(landing_fill)
	_update_landing_fill()
	queue_redraw()

func _physics_process(delta: float) -> void:
	elapsed += maxf(0.0, delta)
	var progress := clampf(elapsed / maxf(0.01, flight_duration), 0.0, 1.0)
	global_position = start_position.lerp(target_position, progress)
	_update_landing_fill()
	queue_redraw()
	if progress >= 1.0:
		_explode()

func _explode() -> void:
	if get_parent() != null:
		var impact := ImpactVisual.new()
		impact.name = "LobImpact"
		impact.radius = splash_radius
		get_parent().add_child(impact)
		impact.global_position = target_position
	if is_instance_valid(target_player) and target_player.global_position.distance_to(target_position) <= splash_radius:
		if target_player.has_method("take_damage"):
			target_player.take_damage(damage)
	queue_free()

func _draw() -> void:
	var arc_height := sin(clampf(elapsed / maxf(0.01, flight_duration), 0.0, 1.0) * PI) * 18.0
	var center := Vector2(0.0, -arc_height)
	draw_circle(center, 9.0, OUTLINE_COLOR)
	draw_circle(center, 7.0, tint)
	draw_circle(center + Vector2(-2.0, -2.0), 2.5, HIGHLIGHT_COLOR)
	var progress := clampf(elapsed / maxf(0.01, flight_duration), 0.0, 1.0)
	var travel := (target_position - start_position).normalized()
	if progress > 0.0 and travel != Vector2.ZERO:
		draw_line(center - travel * 16.0, center - travel * 9.0, OUTLINE_COLOR, 4.0, true)
		draw_line(center - travel * 16.0, center - travel * 9.0, tint, 2.0, true)

func _update_landing_fill() -> void:
	if is_instance_valid(landing_fill):
		landing_fill.global_position = target_position
		landing_fill.queue_redraw()

func _draw_landing_fill() -> void:
	landing_fill.draw_circle(Vector2.ZERO, splash_radius, Color(tint, 0.08))
	landing_fill.draw_arc(Vector2.ZERO, splash_radius, 0.0, TAU, 48, OUTLINE_COLOR, 5.0, true)
	landing_fill.draw_arc(Vector2.ZERO, splash_radius, 0.0, TAU, 48, tint, 3.0, true)
