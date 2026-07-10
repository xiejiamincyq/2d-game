extends Node2D
class_name LaserBeam

var end_local: Vector2 = Vector2.ZERO
var tint: Color = Color(0.25, 1.0, 1.0)
var lifetime: float = 0.09
var width: float = 3.0
var persistent: bool = false

func setup(from_position: Vector2, to_position: Vector2, color: Color, beam_width: float = 3.0) -> void:
	global_position = from_position
	end_local = to_position - from_position
	tint = color
	width = beam_width

func _process(delta: float) -> void:
	if not persistent:
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2.ZERO, end_local, Color.WHITE, width + 2.0)
	draw_line(Vector2.ZERO, end_local, tint, width)
	draw_circle(Vector2.ZERO, width + 2.0, tint)
	draw_circle(end_local, width + 3.0, tint.lightened(0.25))
