extends "res://scripts/components/VineSeedProjectile.gd"
## Reuses continuous circle flight/source exclusion, not seed art or stats.
func _init() -> void:
	super._init()
	radius = 6
	damage = 18
	lifetime = 1.4
	velocity = Vector2(350,0)
	tint = Color("f27a4b")
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,velocity.angle(),Vector2.ONE)
	var hull := PackedVector2Array([Vector2(-6,-3),Vector2(-1,-6),Vector2(8,-1),Vector2(7,3),Vector2(0,5),Vector2(-6,1)])
	var core := PackedVector2Array([Vector2(-4,-2),Vector2(0,-4),Vector2(6,0),Vector2(0,3),Vector2(-4,1)])
	draw_colored_polygon(hull,Color("172026"))
	draw_colored_polygon(core,tint)
	draw_line(Vector2(-2,-1),Vector2(3,0),Color("f3eddc"),1)
