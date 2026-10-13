extends Node2D
## Original matte cut-paper foundry. Static furnace glow is not an active hazard.
const INK := Color("171f25")
var footprint := Vector2.ZERO
var kind: StringName
func configure(size: Vector2,role: StringName) -> void:
	footprint = size
	kind = role
	queue_redraw()
func _polygon(points: PackedVector2Array,color: Color) -> void:
	draw_colored_polygon(points,color)
	points.append(points[0])
	draw_polyline(points,INK,3,true)
func _draw() -> void:
	var w := footprint.x
	var h := footprint.y
	match kind:
		&"pipe_bank":
			for row in 2:
				var y := -h*0.73+row*h*0.43
				draw_rect(Rect2(-w/2+9,y-13,w-18,26),Color("797565"))
				draw_rect(Rect2(-w/2+9,y-13,w-18,26),INK,false,3)
				draw_line(Vector2(-w/2+11,y-7),Vector2(w/2-11,y-7),Color("b2a17a"),3)
				for x in [-w*0.35,0,w*0.35]:
					draw_rect(Rect2(x-7,y-15,14,30),Color("4d5856"))
					draw_rect(Rect2(x-7,y-15,14,30),INK,false,2)
			var at := Vector2(0,-h*0.52)
			draw_circle(at,12,INK)
			draw_circle(at,8,Color("a38762"))
			draw_line(at-Vector2(12,0),at+Vector2(12,0),INK,3)
		&"furnace":
			draw_rect(Rect2(-w*0.27,-h-30,w*0.25,42),Color("73766b"))
			draw_rect(Rect2(-w*0.27,-h-30,w*0.25,42),INK,false,3)
			draw_rect(Rect2(-w*0.30,-h-34,w*0.31,10),Color("9b987d"))
			draw_rect(Rect2(-w*0.30,-h-34,w*0.31,10),INK,false,3)
			_polygon(PackedVector2Array([Vector2(-w*0.42,-8),Vector2(-w*0.46,-h*0.76),Vector2(-w*0.32,-h+2),Vector2(w*0.32,-h+2),Vector2(w*0.46,-h*0.76),Vector2(w*0.42,-8)]),Color("72796d"))
			draw_rect(Rect2(-w*0.25,-h*0.77,w*0.5,h*0.55),INK)
			draw_rect(Rect2(-w*0.21,-h*0.72,w*0.42,h*0.45),Color("6f513c"))
			draw_rect(Rect2(-w*0.14,-h*0.65,w*0.28,h*0.26),Color("aa784f"))
			for column in 4:
				var x := -w*0.20+column*w*0.133
				draw_line(Vector2(x,-h*0.74),Vector2(x,-h*0.26),INK,4)
			for side in [-1,1]:
				draw_circle(Vector2(side*w*0.32,-h*0.43),6,Color("b5a681"))
				draw_circle(Vector2(side*w*0.32,-h*0.43),2,INK)
			draw_line(Vector2(-w*0.30,-h*0.14),Vector2(w*0.30,-h*0.14),INK,4)
		&"slag_stack":
			_polygon(PackedVector2Array([Vector2(-w*0.44,-6),Vector2(-w*0.46,-h*0.61),Vector2(-w*0.30,-h*0.85),Vector2(w*0.34,-h*0.85),Vector2(w*0.45,-h*0.60),Vector2(w*0.42,-6)]),Color("82705c"))
			for index in 3:
				var x := -w*0.24+index*w*0.24
				_polygon(PackedVector2Array([Vector2(x-18,-h*0.78),Vector2(x-22,-h-12),Vector2(x-5,-h-28),Vector2(x+17,-h-8),Vector2(x+18,-h*0.77)]),Color("6c7771"))
			for y in [-h*0.6,-h*0.25]:
				draw_line(Vector2(-w*0.44,y),Vector2(w*0.43,y),INK,4)
			for x in [-w*0.30,w*0.30]:
				draw_line(Vector2(x,-h*0.84),Vector2(x,-8),Color("ac956b"),5)
