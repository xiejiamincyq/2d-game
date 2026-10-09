extends Node2D
## Original native matte-paper scenery. No texture, shader or old atlas.

const INK := Color("142520")
var footprint := Vector2.ZERO
var kind: StringName

func configure(size: Vector2, role: StringName) -> void:
	footprint = size
	kind = role
	queue_redraw()

func _shape(points: Array[Vector2], color: Color, width := 3.0) -> void:
	var vertices := PackedVector2Array(points)
	draw_colored_polygon(vertices, color)
	vertices.append(vertices[0])
	draw_polyline(vertices, INK, width, true)

func _draw() -> void:
	var w := footprint.x
	var h := footprint.y
	if kind == &"plant_bed":
		draw_rect(Rect2(-w * 0.5 + 8, -h + 8, w - 16, h - 16), Color("4c4c37"))
		for row in 2:
			for column in 4:
				var p := Vector2(-w * 0.34 + column * w * 0.225, -h * 0.72 + row * h * 0.44)
				draw_line(p + Vector2(0, 8), p - Vector2(0, 12), INK, 3)
				_shape([p, p + Vector2(-18, -6), p + Vector2(-17, -22), p + Vector2(-4, -16)], Color("61754f"))
				_shape([p - Vector2(0, 4), p + Vector2(15, -13), p + Vector2(15, -27), p + Vector2(3, -22)], Color("829062"))
	elif kind == &"root_wall":
		for index in 3:
			var x := -w * 0.3 + index * w * 0.3
			_shape([Vector2(x - 12, -6), Vector2(x - 20, -h * 0.38), Vector2(x - 6, -h * 0.6), Vector2(x - 16, -h + 8), Vector2(x + 9, -h - 22), Vector2(x + 18, -h * 0.55), Vector2(x + 10, -h * 0.22), Vector2(x + 22, -6)], Color("827654"), 4)
			draw_line(Vector2(x, -h * 0.75), Vector2(x + 7, -h * 0.3), Color("4c523c"), 3)
			var p := Vector2(x, -h * 0.65)
			_shape([p, p + Vector2(-22, -9), p + Vector2(-23, -29), p + Vector2(-5, -23)], Color("60764e"))
	else:
		_shape([Vector2(-w * 0.44, -8), Vector2(-w * 0.44, -h * 0.8), Vector2(0, -h - 22), Vector2(w * 0.44, -h * 0.8), Vector2(w * 0.44, -8)], Color("69735b"), 4)
		_shape([Vector2(-w * 0.5, -h * 0.75), Vector2(-w * 0.5 + 10, -h * 0.9), Vector2(0, -h - 28), Vector2(w * 0.5 - 10, -h * 0.9), Vector2(w * 0.5, -h * 0.75), Vector2(0, -h + 2)], Color("968760"), 4)
		draw_rect(Rect2(-22, -h * 0.56, 44, h * 0.56 - 8), INK)
		# Closed planks communicate a solid obstacle, not a passable dark doorway.
		draw_rect(Rect2(-18, -h * 0.56 + 4, 36, h * 0.56 - 16), Color("8a7d58"))
		draw_line(Vector2(0, -h * 0.56 + 4), Vector2(0, -12), INK, 3)
		draw_circle(Vector2(8, -h * 0.25), 3, INK)
		for x in [-w * 0.3, w * 0.3]:
			draw_rect(Rect2(x - 16, -h * 0.61, 32, h * 0.32), Color("34483a"))
			draw_rect(Rect2(x - 16, -h * 0.61, 32, h * 0.32), INK, false, 3)
			draw_line(Vector2(x, -h * 0.61), Vector2(x, -h * 0.29), Color("859173"), 2)
