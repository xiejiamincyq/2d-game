extends Control
class_name CyberHudChrome

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var rect := get_rect()
	var size := rect.size
	var t := Time.get_ticks_msec() / 1000.0
	for y in range(0, int(size.y), 6):
		var alpha := 0.018 + 0.012 * sin(t * 3.0 + y * 0.08)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 1.0, 0.95, alpha), 1.0)
	var corner := 52.0
	var inset := 12.0
	var cyan := Color(0.18, 0.95, 1.0, 0.55)
	var amber := Color(1.0, 0.56, 0.18, 0.38)
	_draw_corner(Vector2(inset, inset), Vector2.RIGHT, Vector2.DOWN, corner, cyan)
	_draw_corner(Vector2(size.x - inset, inset), Vector2.LEFT, Vector2.DOWN, corner, cyan)
	_draw_corner(Vector2(inset, size.y - inset), Vector2.RIGHT, Vector2.UP, corner, cyan)
	_draw_corner(Vector2(size.x - inset, size.y - inset), Vector2.LEFT, Vector2.UP, corner, cyan)
	for i in range(18):
		var x := 24.0 + i * 34.0
		var pulse := 0.25 + 0.22 * sin(t * 5.0 + i)
		draw_rect(Rect2(x, size.y - 18.0, 18.0, 3.0), Color(amber.r, amber.g, amber.b, pulse))
	draw_line(Vector2(20, 102), Vector2(size.x - 20, 102), Color(0.18, 0.95, 1.0, 0.16), 1.0)

func _draw_corner(origin: Vector2, horizontal: Vector2, vertical: Vector2, length: float, color: Color) -> void:
	draw_line(origin, origin + horizontal * length, color, 2.0)
	draw_line(origin, origin + vertical * length, color, 2.0)
	draw_line(origin + horizontal * 10.0 + vertical * 10.0, origin + horizontal * 34.0 + vertical * 10.0, color.darkened(0.15), 1.0)
	draw_line(origin + horizontal * 10.0 + vertical * 10.0, origin + horizontal * 10.0 + vertical * 34.0, color.darkened(0.15), 1.0)
