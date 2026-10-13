extends Node2D
## Unbroken walkable observatory floor, not floating tiles or painted hazards.
const BASE := Color("252b38")
const SEAM := Color("303849")
const WALKWAY := Color("2c3544")
var world_bounds := Rect2()
var island_profiles: Array[Dictionary] = []
var bypass_routes: Array[Dictionary] = []
func configure(bounds: Rect2,islands: Array[Dictionary],routes: Array[Dictionary]) -> void:
	world_bounds = bounds
	island_profiles = islands.duplicate(true); bypass_routes = routes.duplicate(true)
	queue_redraw()
func _draw() -> void:
	draw_rect(world_bounds,BASE)
	for route in bypass_routes: draw_rect(route.rect,WALKWAY)
	# Broad, low-contrast joints remain visually subordinate to enemies and cues.
	for x in range(int(world_bounds.position.x),int(world_bounds.end.x),208):
		draw_line(Vector2(x,world_bounds.position.y),Vector2(x,world_bounds.end.y),SEAM,2)
	for y in range(int(world_bounds.position.y),int(world_bounds.end.y),192):
		draw_line(Vector2(world_bounds.position.x,y),Vector2(world_bounds.end.x,y),SEAM,2)
	for island in island_profiles:
		var rect: Rect2 = island.rect.grow(16)
		draw_rect(rect,Color("1f2632"),false,4)
		for side in [-1,1]:
			var at := Vector2(rect.get_center().x,rect.get_center().y+side*(rect.size.y/2+43))
			draw_line(at-Vector2(42,0),at+Vector2(42,0),Color("465263"),3)
			for tick in [-1,0,1]: draw_line(at+Vector2(tick*28,-5),at+Vector2(tick*28,5),Color("465263"),2)
	draw_arc(Vector2.ZERO,96,0,TAU,48,Color("3b4555"),3)
	for at in [Vector2(-118,0),Vector2(118,0),Vector2(0,-118),Vector2(0,118)]:
		draw_line(at*0.88,at*1.08,Color("566174"),3)
