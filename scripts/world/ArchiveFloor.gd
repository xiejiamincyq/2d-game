extends Node2D
## Quiet slate tiles and inset reading rooms. No fake walkable door painting.
var bounds := Rect2()
var map_seed := 0
var chambers: Array[Rect2] = []
var doorways: Array[Rect2] = []
func configure(area: Rect2,seed_value: int,rooms: Array[Rect2],doors: Array[Rect2]) -> void:
	bounds = area; map_seed = seed_value; chambers = rooms.duplicate(); doorways = doors.duplicate(); queue_redraw()
func _draw() -> void:
	if bounds.size==Vector2.ZERO: return
	draw_rect(bounds,Color("394a48"))
	for room in chambers:
		draw_rect(room.grow(-6),Color("4e5b52"))
		var inset := room.grow(-80)
		draw_rect(inset,Color("5e6658")); draw_rect(inset,Color("76816a"),false,2)
		for y in range(int(inset.position.y+24),int(inset.end.y)-16,72):
			draw_line(Vector2(inset.position.x+16,y),Vector2(inset.end.x-16,y),Color("626e5d"),1)
	for door in doorways:
		draw_rect(door.grow(3),Color("6b7463"))
		var at := door.get_center()
		if door.size.x<door.size.y: draw_line(at-Vector2(0,door.size.y/2-9),at+Vector2(0,door.size.y/2-9),Color("929a7a"),2)
		else: draw_line(at-Vector2(door.size.x/2-9,0),at+Vector2(door.size.x/2-9,0),Color("929a7a"),2)
	for y in range(-920,960,112):
		for x in range(-1540,1560,160):
			var at := Vector2(x,y)
			var interior := false
			for room in chambers:
				if room.grow(26).has_point(at): interior = true; break
			if not interior:
				draw_line(at,at+Vector2(32,0),Color("465753"),1)
				if posmod(x*13+y*17+map_seed,23)<3: draw_line(at+Vector2(3,4),at+Vector2(20,10),Color("53615a"),2)
	# Empty archivist platform is a static landmark, not a working Boss.
	var platform := Rect2(-208,-820,416,300)
	draw_rect(platform,Color("596554")); draw_rect(platform.grow(-14),Color("8a9478"),false,3)
	for side in [-1,1]:
		draw_line(Vector2(side*150,-780),Vector2(side*150,-562),Color("747f65"),3)
		draw_line(Vector2(side*150,-780),Vector2(side*82,-740),Color("747f65"),3)
	draw_rect(bounds,Color("203533"),false,18)
