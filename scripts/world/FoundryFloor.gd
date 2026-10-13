extends Node2D
## Quiet native foundry ground; heat hazard indicators are separate live actors.
var bounds := Rect2()
var map_seed := 0
var descriptors: Array[Dictionary] = []
func configure(area: Rect2,seed_value: int,obstacles: Array[Dictionary]) -> void:
	bounds = area
	map_seed = seed_value
	descriptors = obstacles.duplicate(true)
	queue_redraw()
func _draw() -> void:
	if bounds.size==Vector2.ZERO: return
	draw_rect(bounds,Color("3e4443"))
	draw_rect(Rect2(-160,bounds.position.y+20,320,bounds.size.y-40),Color("4d5049"))
	# Broad unpainted service lane, always clear in the geometry profile.
	for y in range(-880,940,140):
		for x in range(-1460,1520,172):
			var index := posmod(x*17+y*23+map_seed,23)
			var point := Vector2(x+index-11,y-index+11)
			var clear := true
			for descriptor in descriptors:
				if Rect2(descriptor.rect).grow(22).has_point(point):
					clear = false
					break
			if clear and index<8:
				draw_line(point,point+Vector2(30,0),Color("505653"),2)
				draw_circle(point+Vector2(3,8),2,Color("65695d"))
	for descriptor in descriptors: draw_rect(Rect2(descriptor.rect).grow(9),Color("2b3535"))
	# Clear forge dais is a landmark, not a danger circle or success display.
	var dais := Rect2(-200,-820,400,300)
	draw_rect(dais,Color("50544b"))
	draw_rect(dais.grow(-16),Color("626350"),false,3)
	for x in [-140,-70,0,70,140]: draw_line(Vector2(x,-780),Vector2(x+28,-780),Color("80765a"),3)
	draw_rect(bounds,Color("1d2b2c"),false,18)
