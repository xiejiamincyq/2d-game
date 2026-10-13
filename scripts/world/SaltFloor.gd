extends Node2D
## Quiet salt-paper ground. Painted causeways are actual dry collider gaps.
var bounds := Rect2()
var map_seed := 0
var descriptors: Array[Dictionary] = []
var causeways: Array[Rect2] = []
func configure(area: Rect2,seed_value: int,solids: Array[Dictionary],passages: Array[Rect2]) -> void:
	bounds = area
	map_seed = seed_value
	descriptors = solids.duplicate(true)
	causeways = passages.duplicate()
	queue_redraw()
func _draw() -> void:
	if bounds.size==Vector2.ZERO: return
	draw_rect(bounds,Color("596665"))
	draw_rect(Rect2(-235,bounds.position.y+18,470,bounds.size.y-36),Color("69736c"))
	draw_rect(Rect2(bounds.position.x+18,-140,bounds.size.x-36,280),Color("69736c"))
	for passage in causeways:
		draw_rect(passage,Color("7c8273"))
		var vertical := passage.size.x<passage.size.y
		var span := passage.size.y if vertical else passage.size.x
		for offset in range(22,int(span)-18,56):
			var a := passage.position+Vector2(12,offset) if vertical else passage.position+Vector2(offset,12)
			var b := a+Vector2(passage.size.x-24,0) if vertical else a+Vector2(0,passage.size.y-24)
			draw_line(a,b,Color("929482"),2)
	for y in range(-920,960,160):
		for x in range(-1540,1560,176):
			var index := posmod(x*11+y*17+map_seed,19)
			var point := Vector2(x+index,y-index)
			var clear := true
			for entry in descriptors:
				if Rect2(entry.rect).grow(30).has_point(point): clear = false; break
			if clear and index<6:
				draw_line(point,point+Vector2(21,-4),Color("737b70"),2)
	# Broken pale dais is a static landmark, never a damaging warning circle.
	var dais := Rect2(-200,-810,400,276)
	draw_rect(dais,Color("74806f"))
	draw_rect(dais.grow(-14),Color("969c82"),false,3)
	for x in [-110,0,110]:
		draw_line(Vector2(x,-776),Vector2(x+25,-750),Color("5d6f69"),3)
	draw_rect(bounds,Color("283b40"),false,18)
