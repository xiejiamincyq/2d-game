extends Node2D
class_name ArcPulseVisual

var max_radius: float = 160.0
var lifetime: float = 0.42
var age: float = 0.0
var tint: Color = Color(0.18, 1.0, 0.95)

func setup(radius: float) -> void:
	max_radius = radius

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var p := clampf(age / lifetime, 0.0, 1.0)
	var radius := lerpf(18.0, max_radius, p)
	var alpha := 1.0 - p
	var points := PackedVector2Array()
	var segments := 96
	for i in range(segments + 1):
		var a := float(i) * TAU / float(segments)
		var wave := sin(a * 9.0 + p * TAU * 3.0) * 8.0 * alpha
		points.append(Vector2.RIGHT.rotated(a) * (radius + wave))
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color(tint.r, tint.g, tint.b, 0.75 * alpha), 4.0)
		draw_line(points[i], points[i + 1], Color.WHITE, 1.0)
