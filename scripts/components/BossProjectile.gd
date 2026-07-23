extends "res://scripts/components/Projectile.gd"
class_name BossProjectile

func _draw() -> void:
	var outer := PackedVector2Array([
		Vector2(0.0, -radius * 1.65),
		Vector2(radius * 1.35, 0.0),
		Vector2(0.0, radius * 1.65),
		Vector2(-radius * 1.35, 0.0),
	])
	draw_circle(Vector2.ZERO, radius * 2.15, Color(0.96, 0.35, 0.75, 0.12))
	draw_colored_polygon(outer, Color("240d31"))
	draw_polyline(outer + PackedVector2Array([outer[0]]), Color("f559bf"), 2.0)
	draw_circle(Vector2.ZERO, radius * 0.55, Color("ffffff"))
