extends "res://scripts/components/Projectile.gd"
class_name BossProjectile

func _draw() -> void:
	var outer := PackedVector2Array([
		Vector2(0.0, -radius * 1.65),
		Vector2(radius * 1.35, 0.0),
		Vector2(0.0, radius * 1.65),
		Vector2(-radius * 1.35, 0.0),
	])
	# A solid diamond remains distinct from the player's square shots without bloom.
	draw_colored_polygon(outer, tint)
	draw_polyline(outer + PackedVector2Array([outer[0]]), Color("123b3b"), 3.0, true)
	draw_circle(Vector2.ZERO, radius * 0.55, Color("f3eddc"))
