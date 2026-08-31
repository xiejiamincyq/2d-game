extends StaticBody2D
class_name ArenaObstacle

var obstacle_size := Vector2(160.0, 100.0)
var obstacle_kind: StringName = &"planter"

func setup(rect: Rect2, kind: StringName) -> void:
	name = "ArenaObstacle_%s" % kind
	position = rect.get_center()
	obstacle_size = rect.size
	obstacle_kind = kind
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"arena_obstacles")

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = obstacle_size
	collision.shape = shape
	add_child(collision)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-obstacle_size * 0.5, obstacle_size)
	draw_rect(Rect2(rect.position + Vector2(5.0, 7.0), rect.size), Color(0.02, 0.08, 0.08, 0.34), true)
	match obstacle_kind:
		&"greenhouse":
			_draw_greenhouse(rect)
		&"tank":
			_draw_tank(rect)
		&"pipe":
			_draw_pipe(rect)
		_:
			_draw_planter(rect)

func _draw_planter(rect: Rect2) -> void:
	draw_rect(rect, Color("315f52"), true)
	draw_rect(rect, Color("173f3b"), false, 5.0)
	var leaf_radius := minf(rect.size.x, rect.size.y) * 0.18
	for offset in [Vector2(-0.24, -0.08), Vector2(0.0, 0.12), Vector2(0.24, -0.06)]:
		draw_circle(offset * rect.size, leaf_radius, Color("6e9c57"))
		draw_circle(offset * rect.size, leaf_radius, Color("244b3c"), false, 3.0)

func _draw_greenhouse(rect: Rect2) -> void:
	draw_rect(rect, Color("b9d7c2"), true)
	draw_rect(rect, Color("24535a"), false, 6.0)
	for fraction in [0.25, 0.5, 0.75]:
		var x := lerpf(rect.position.x, rect.end.x, fraction)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color("4c8d83"), 3.0)
	draw_line(Vector2(rect.position.x, 0.0), Vector2(rect.end.x, 0.0), Color("4c8d83"), 3.0)

func _draw_tank(rect: Rect2) -> void:
	draw_rect(rect, Color("3f8580"), true)
	draw_rect(rect, Color("173f46"), false, 6.0)
	draw_circle(Vector2.ZERO, minf(rect.size.x, rect.size.y) * 0.26, Color("8bc3a5"))
	draw_circle(Vector2.ZERO, minf(rect.size.x, rect.size.y) * 0.26, Color("173f46"), false, 4.0)

func _draw_pipe(rect: Rect2) -> void:
	draw_rect(rect, Color("356f72"), true)
	draw_rect(rect, Color("163c45"), false, 6.0)
	var stripe_width := rect.size.x / 7.0
	for i in [1, 3, 5]:
		draw_rect(Rect2(rect.position.x + stripe_width * i, rect.position.y, stripe_width * 0.45, rect.size.y), Color("d18443"), true)
