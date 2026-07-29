extends Node2D
class_name DroneLockReticle

const RETICLE_COLOR := Color("ff3b30")
const INNER_COLOR := Color("ff9a3d")
const RADIUS := 13.0

func _ready() -> void:
	z_index = 24
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 28, Color(RETICLE_COLOR, 0.82), 1.5, true)
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		draw_line(direction * (RADIUS - 3.0), direction * (RADIUS + 4.0), RETICLE_COLOR, 2.0, true)
	draw_circle(Vector2.ZERO, 2.0, INNER_COLOR)
