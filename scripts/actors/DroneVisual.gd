extends Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color(0.06, 0.12, 0.14))
	draw_rect(Rect2(-5, -5, 10, 10), Color(0.18, 0.95, 1.0))
	draw_rect(Rect2(-10, -2, 20, 4), Color(0.95, 0.45, 0.14))
	draw_circle(Vector2.ZERO, 2.5, Color.WHITE)
