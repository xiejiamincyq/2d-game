extends Control
## Six original small ink glyphs, not portraits or borrowed reference art.

var chapter := 1:
	set(value):
		chapter = clampi(value, 1, 6)
		queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(44, 44)

func _draw() -> void:
	draw_set_transform(size * 0.5, 0, Vector2.ONE * minf(size.x, size.y) / 48.0)
	var ink := Color("142520")
	var accent: Color = [Color("607752"), Color("ad653a"), Color("648a8b"), Color("948760"), Color("727189"), Color("8c6f7d")][chapter - 1]
	draw_circle(Vector2.ZERO, 21, Color("e2dac2"))
	draw_arc(Vector2.ZERO, 21, 0, TAU, 32, ink, 2, true)
	match chapter:
		1:
			draw_line(Vector2(0, 13), Vector2(0, -10), ink, 3)
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(-13, -3), Vector2(-15, -13), Vector2(-4, -9)]), accent)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -3), Vector2(12, -9), Vector2(11, -16), Vector2(1, -11)]), accent)
		2:
			draw_colored_polygon(PackedVector2Array([Vector2(-13, 12), Vector2(-11, -1), Vector2(-3, -5), Vector2(1, -17), Vector2(12, -2), Vector2(13, 12)]), accent)
			draw_line(Vector2(-15, 13), Vector2(15, 13), ink, 3)
		3:
			for y in [-6, 2, 10]:
				draw_polyline(PackedVector2Array([Vector2(-15, y), Vector2(-7, y - 3), Vector2(1, y + 1), Vector2(9, y - 3), Vector2(15, y)]), accent, 3, true)
		4:
			draw_line(Vector2(0, 14), Vector2(0, -4), ink, 4)
			draw_colored_polygon(PackedVector2Array([Vector2(-16, -2), Vector2(-10, -12), Vector2(2, -16), Vector2(15, -3)]), accent)
			draw_circle(Vector2(-4, -9), 2, Color("f3eddc"))
		5:
			draw_colored_polygon(PackedVector2Array([Vector2(-12, 10), Vector2(-8, -12), Vector2(8, -12), Vector2(12, 10)]), accent)
			draw_line(Vector2(-15, 11), Vector2(15, 11), ink, 3)
			draw_circle(Vector2(0, 15), 2, ink)
		6:
			draw_arc(Vector2.ZERO, 13, -2.2, 0.4, 20, accent, 4, true)
			draw_arc(Vector2.ZERO, 13, 1, 3.5, 20, accent, 4, true)
			draw_polyline(PackedVector2Array([Vector2(3, -16), Vector2(-3, -2), Vector2(4, 2), Vector2(-4, 17)]), ink, 3, true)
