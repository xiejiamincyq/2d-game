extends Node2D
class_name WorldBoundary

var bounds: Rect2 = Rect2(-1400, -900, 2800, 1800)

func setup(world_bounds: Rect2) -> void:
	bounds = world_bounds
	queue_redraw()

func _draw() -> void:
	draw_rect(bounds, Color(0.0, 0.0, 0.0, 0.0), false, 5.0)
	draw_rect(bounds, Color(0.2, 1.0, 0.95, 0.85), false, 3.0)
	draw_rect(bounds.grow(-14.0), Color(1.0, 0.32, 0.12, 0.55), false, 2.0)
	var step := 96
	for x in range(int(bounds.position.x), int(bounds.end.x), step):
		draw_line(Vector2(x, bounds.position.y), Vector2(x + 42, bounds.position.y + 42), Color(1.0, 0.56, 0.18, 0.55), 3.0)
		draw_line(Vector2(x, bounds.end.y), Vector2(x + 42, bounds.end.y - 42), Color(1.0, 0.56, 0.18, 0.55), 3.0)
	for y in range(int(bounds.position.y), int(bounds.end.y), step):
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.position.x + 42, y + 42), Color(1.0, 0.56, 0.18, 0.55), 3.0)
		draw_line(Vector2(bounds.end.x, y), Vector2(bounds.end.x - 42, y + 42), Color(1.0, 0.56, 0.18, 0.55), 3.0)
