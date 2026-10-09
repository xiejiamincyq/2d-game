extends Node2D
## Quiet original ground layer; visual paths do not authorize collisions.

var bounds := Rect2()
var map_seed := 0
var descriptors: Array[Dictionary] = []

func configure(area: Rect2, seed_value: int, obstacles: Array[Dictionary]) -> void:
	bounds = area
	map_seed = seed_value
	descriptors = obstacles.duplicate(true)
	queue_redraw()

func _draw() -> void:
	if bounds.size == Vector2.ZERO:
		return
	draw_rect(bounds, Color("3e4d3b"))
	# Broad clear cross-routes match the real safe gaps, not painted false doors.
	for end in [Vector2(-1240, 0), Vector2(1240, 0), Vector2(0, 730), Vector2(0, -720)]:
		draw_line(Vector2.ZERO, end, Color("545b43"), 170)
	for y in range(-780, 800, 96):
		for x in range(-1240, 1280, 118):
			var index := posmod(x * 17 + y * 23 + map_seed, 19)
			var point := Vector2(x + index - 9, y - index + 9)
			var clear := true
			for descriptor in descriptors:
				if Rect2(descriptor.rect).grow(18).has_point(point):
					clear = false
					break
			if not clear:
				continue
			if index < 7:
				draw_line(point, point + Vector2(17, -2), Color("46553e"), 2)
			elif index < 10:
				draw_line(point, point + Vector2(7, -5), Color("667052"), 2)
				draw_line(point + Vector2(3, 0), point + Vector2(1, -8), Color("667052"), 2)
	for descriptor in descriptors:
		var rect: Rect2 = descriptor.rect
		draw_rect(rect.grow(8), Color("2d3b2e"))
	# A quiet clear pocket, not a damage zone or a Boss success indicator.
	draw_circle(Vector2(0, -500), 148, Color("535f45"))
	for x in [-96, -48, 0, 48, 96]:
		draw_line(Vector2(x, -528), Vector2(x + 22, -528), Color("697052"), 2)
	draw_rect(bounds, Color("1c3026"), false, 18)
