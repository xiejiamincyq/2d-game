extends Node2D
## Quiet nested paving follows real pillar rings. Four pads are dormant landmarks.
var bounds := Rect2()
var map_seed := 0
var rings: Array[Dictionary] = []
var gates: Array[Dictionary] = []
var echo_sites: Array[Vector2] = []
func configure(area: Rect2,seed_value: int,profiles: Array[Dictionary],openings: Array[Dictionary],sites: Array[Vector2]) -> void:
	bounds = area; map_seed = seed_value; rings = profiles.duplicate(true); gates = openings.duplicate(true); echo_sites = sites.duplicate(); queue_redraw()
func _ellipse(center: Vector2,radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(97): points.append(center+Vector2(cos(step*TAU/96)*radii.x,sin(step*TAU/96)*radii.y))
	return points
func _draw() -> void:
	if bounds.size==Vector2.ZERO: return
	draw_rect(bounds,Color("393542"))
	if not rings.is_empty(): draw_colored_polygon(_ellipse(rings[0].center,rings[0].radii*0.87),Color("45404e"))
	for ring in rings:
		draw_polyline(_ellipse(ring.center,ring.radii),Color("514959"),36)
		for distance in [-44.0,44.0]: draw_polyline(_ellipse(ring.center,ring.radii+Vector2.ONE*distance),Color("5f5666"),2)
	for gate in gates: draw_line(gate.inside,gate.outside,Color("5a5261"),14)
	for y in range(int(bounds.position.y+80),int(bounds.end.y)-40,128):
		for x in range(int(bounds.position.x+80),int(bounds.end.x)-40,192):
			var at := Vector2(x,y)
			draw_line(at,at+Vector2(28,0),Color("484251"),1)
			if posmod(x*7+y*13+map_seed,29)<2: draw_line(at+Vector2(7,3),at+Vector2(19,11),Color("514a59"),1)
	for site in echo_sites:
		draw_circle(site,18,Color("665967")); draw_arc(site,18,0,TAU,32,Color("8a796c"),2)
		draw_line(site+Vector2(-7,5),site+Vector2(7,5),Color("a89473"),2)
		draw_line(site+Vector2(-7,5),site+Vector2(-3,-5),Color("a89473"),2)
		draw_line(site+Vector2(7,5),site+Vector2(3,-5),Color("a89473"),2)
	var platform := Rect2(-208,-820,416,300)
	draw_rect(platform,Color("514754")); draw_rect(platform.grow(-14),Color("887967"),false,3)
	for side in [-1,1]: draw_line(Vector2(side*144,-780),Vector2(side*144,-568),Color("706271"),2)
	draw_rect(bounds,Color("26222f"),false,18)
