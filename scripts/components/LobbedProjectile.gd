extends Node2D
class_name LobbedProjectile

var target_player: Node2D
var target_position := Vector2.ZERO
var damage := 14.0
var splash_radius := 72.0
var flight_duration := 0.85
var elapsed := 0.0
var start_position := Vector2.ZERO
var tint := Color("f559bf")

func configure(origin: Vector2, destination: Vector2, target: Node2D) -> void:
	global_position = origin
	start_position = origin
	target_position = destination
	target_player = target

func _ready() -> void:
	start_position = global_position
	queue_redraw()

func _physics_process(delta: float) -> void:
	elapsed += maxf(0.0, delta)
	var progress := clampf(elapsed / maxf(0.01, flight_duration), 0.0, 1.0)
	global_position = start_position.lerp(target_position, progress)
	queue_redraw()
	if progress >= 1.0:
		_explode()

func _explode() -> void:
	if is_instance_valid(target_player) and target_player.global_position.distance_to(target_position) <= splash_radius:
		if target_player.has_method("take_damage"):
			target_player.take_damage(damage)
	queue_free()

func _draw() -> void:
	var arc_height := sin(clampf(elapsed / maxf(0.01, flight_duration), 0.0, 1.0) * PI) * 18.0
	draw_circle(Vector2(0.0, -arc_height), 7.0, tint)
	draw_circle(Vector2(0.0, -arc_height), 3.0, Color.WHITE)
	var landing_local := to_local(target_position)
	draw_circle(landing_local, splash_radius, Color(tint, 0.08))
	draw_arc(landing_local, splash_radius, 0.0, TAU, 40, Color(tint, 0.78), 2.0)
