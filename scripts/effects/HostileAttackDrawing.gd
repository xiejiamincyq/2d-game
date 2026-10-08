extends RefCounted

const CORAL := Color("f27a4b")
const OUTLINE := Color("123b3b")

static func claw_strokes(origin: Vector2, direction: Vector2, progress: float, radius: float, half_angle: float) -> Array[PackedVector2Array]:
	var strokes: Array[PackedVector2Array] = []
	var margin := minf(0.10, half_angle * 0.25)
	var head := lerpf(-half_angle + margin, half_angle - margin, clampf(progress, 0.0, 1.0))
	for scale_factor in [0.56, 0.72, 0.86]:
		var points := PackedVector2Array()
		var start := maxf(-half_angle + margin, head - 0.34)
		for index in range(9):
			points.append(origin + direction.rotated(lerpf(start, head, index / 8.0)) * radius * float(scale_factor))
		strokes.append(points)
	return strokes

static func draw_strokes(canvas: Node2D, strokes: Array[PackedVector2Array], alpha: float = 1.0) -> void:
	for points in strokes:
		if points.size() < 2 or points[0].is_equal_approx(points[points.size() - 1]):
			continue
		canvas.draw_polyline(points, Color(OUTLINE, alpha), 5.0, true)
		canvas.draw_polyline(points, Color(CORAL, alpha), 2.5, true)
