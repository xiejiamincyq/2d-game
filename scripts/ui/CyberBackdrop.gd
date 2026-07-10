extends Control
class_name CyberBackdrop

var accent: Color = Color(0.18, 0.95, 1.0, 0.24)
var hot: Color = Color(1.0, 0.35, 0.12, 0.2)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var rect := get_rect()
	var t := Time.get_ticks_msec() / 1000.0
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.015, 0.022, 0.032, 0.88))
	for y in range(0, int(rect.size.y) + 1, 32):
		var alpha := 0.05 + 0.025 * sin(t * 2.0 + y * 0.04)
		draw_line(Vector2(0, y), Vector2(rect.size.x, y), Color(accent.r, accent.g, accent.b, alpha), 1.0)
	for x in range(0, int(rect.size.x) + 1, 48):
		draw_line(Vector2(x, 0), Vector2(x + 120, rect.size.y), Color(0.2, 1.0, 0.95, 0.035), 1.0)
	for i in range(9):
		var y := fmod(t * 90.0 + i * 87.0, rect.size.y + 120.0) - 60.0
		draw_line(Vector2(0, y), Vector2(rect.size.x, y - 30.0), Color(1.0, 0.35, 0.12, 0.09), 2.0)
	draw_rect(Rect2(26, 28, rect.size.x - 52, rect.size.y - 56), Color(0, 0, 0, 0), false, 2.0)
