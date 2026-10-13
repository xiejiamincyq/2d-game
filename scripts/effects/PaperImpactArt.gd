extends RefCounted
## Project-original compact paper spark; no raster inputs, smoke, bloom, nodes
## or gameplay events. Life/placement/budget belong to CombatVfx.
const Palette = preload("res://scripts/effects/FriendlyEffectPalette.gd")
static func points(center: Vector2, radius: float, angle: float) -> PackedVector2Array:
	var shape := PackedVector2Array()
	for index in 8:
		var reach := radius if index % 2 == 0 else radius * 0.27
		shape.append(center + Vector2.RIGHT.rotated(angle + PI * float(index)/4.0) * reach)
	return shape
static func draw_impact(canvas: Node2D, center: Vector2, radius: float, angle: float, alpha: float) -> void:
	var shape := points(center, radius, angle)
	canvas.draw_colored_polygon(shape, Color(Palette.CREAM, alpha * 0.85))
	shape.append(shape[0])
	canvas.draw_polyline(shape, Color(Palette.TEAL, alpha * 0.85), 1.5, true)
