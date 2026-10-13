extends Node2D
## Original paper-cut headstones and suspended bronze bells; never baked text.
const INK := Color("292435")
const STONE := Color("aaa1ad")
const PAPER := Color("d0c5b6")
const BRONZE := Color("a08a68")
var footprint := Vector2.ZERO
var kind: StringName
func configure(size: Vector2,value: StringName) -> void: footprint = size; kind = value; queue_redraw()
func _draw() -> void:
	var w := footprint.x; var h := footprint.y
	if kind==&"bell_column":
		for side in [-1,1]:
			var pillar := Rect2(side*(w/2-14)-7,-h-38,14,h+30)
			draw_rect(pillar,STONE); draw_rect(pillar,INK,false,3)
		var cap := Rect2(-w/2,-h-52,w,16)
		draw_rect(cap,PAPER); draw_rect(cap,INK,false,3)
		draw_line(Vector2(0,-h-35),Vector2(0,-h-19),INK,5)
		var bell := PackedVector2Array([Vector2(-10,-h-18),Vector2(10,-h-18),Vector2(15,-h+6),Vector2(23,-h+14),Vector2(-23,-h+14),Vector2(-15,-h+6)])
		draw_colored_polygon(bell,BRONZE); bell.append(bell[0]); draw_polyline(bell,INK,3)
		draw_line(Vector2(-15,-h+9),Vector2(15,-h+9),PAPER,2)
		draw_circle(Vector2(0,-h+19),4,INK)
	else:
		var stone := PackedVector2Array([Vector2(-w/2+8,-10),Vector2(-w/2+8,-h-22),Vector2(-w/4,-h-44),Vector2(0,-h-52),Vector2(w/4,-h-44),Vector2(w/2-8,-h-22),Vector2(w/2-8,-10)])
		draw_colored_polygon(stone,STONE); stone.append(stone[0]); draw_polyline(stone,INK,3)
		draw_line(Vector2(-w/4,-h-28),Vector2(w/4,-h-28),PAPER,3)
		# Neutral carved arcs, not the hostile action's warning color or timing.
		for row in 2: draw_arc(Vector2(0,-h+row*14),12,0.22,PI-0.22,12,Color("6f637c"),3)
		draw_line(Vector2(-w/4,-18),Vector2(w/4,-18),INK,2)
