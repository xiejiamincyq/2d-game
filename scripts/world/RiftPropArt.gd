extends Node2D
## Original ink-paper instruments: crank scope benches and split-ring relays.
const INK := Color("202633")
const SLATE := Color("65778c")
const DARK := Color("3a465b")
const PAPER := Color("c5beb0")
const GLASS := Color("9bb2bc")
var footprint := Vector2.ZERO
var kind: StringName
func configure(size: Vector2,value: StringName) -> void:
	footprint = size; kind = value; queue_redraw()
func get_visual_bounds() -> Rect2:
	return Rect2(Vector2(-footprint.x/2-5,-footprint.y-68),Vector2(footprint.x+10,footprint.y+76))
func polygon(points: PackedVector2Array,color: Color) -> void:
	draw_colored_polygon(points,color)
	var outline := points.duplicate(); outline.append(outline[0]); draw_polyline(outline,INK,3)
func _draw() -> void:
	var w := footprint.x; var h := footprint.y
	# Low solid plinth attaches every elevated instrument to its real footprint.
	var body := Rect2(-w/2+3,-h+3,w-6,h-9)
	draw_rect(body,DARK); draw_rect(body,INK,false,3)
	draw_line(Vector2(-w/2+12,-10),Vector2(w/2-12,-10),SLATE,3)
	if kind==&"scope_bench":
		polygon(PackedVector2Array([Vector2(-w/2,-h-27),Vector2(w/2-8,-h-35),Vector2(w/2,-36),Vector2(-w/2+8,-27)]),SLATE)
		var panel := Rect2(-w/2+17,-59,w-34,23)
		draw_rect(panel,PAPER); draw_rect(panel,INK,false,3)
		for index in 3:
			draw_circle(Vector2(-w/2+32+index*20,-47),3,DARK)
		var pivot := Vector2(-14,-h/2-32)
		draw_line(pivot+Vector2(0,23),pivot,INK,10)
		draw_line(pivot+Vector2(0,23),pivot,SLATE,5)
		polygon(PackedVector2Array([pivot+Vector2(-18,-6),pivot+Vector2(35,-26),pivot+Vector2(43,-10),pivot+Vector2(-10,10)]),PAPER)
		draw_circle(pivot+Vector2(39,-18),12,INK)
		draw_circle(pivot+Vector2(39,-18),8,GLASS)
		draw_line(pivot+Vector2(-18,3),pivot+Vector2(-31,7),INK,5)
		draw_circle(pivot+Vector2(-34,8),6,SLATE)
	else:
		var center := Vector2(0,-h-27)
		polygon(PackedVector2Array([Vector2(-31,-19),Vector2(-25,-h-19),Vector2(0,-h-38),Vector2(25,-h-19),Vector2(31,-19)]),SLATE)
		# Split arcs with a real central glass plate; no warning-red decoration.
		draw_circle(center,22,INK); draw_circle(center,17,GLASS)
		draw_arc(center,30,0.24,PI-0.24,18,PAPER,9)
		draw_arc(center,30,PI+0.24,TAU-0.24,18,PAPER,9)
		draw_line(center+Vector2(-11,0),center+Vector2(11,0),DARK,3)
		draw_line(center+Vector2(0,-11),center+Vector2(0,11),DARK,3)
		for side in [-1,1]:
			draw_line(Vector2(side*13,-h/2),Vector2(side*39,-18),INK,9)
			draw_line(Vector2(side*13,-h/2),Vector2(side*39,-18),PAPER,4)
