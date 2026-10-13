extends Node2D
## Original matte-paper planter, closed greenhouse, tank and heavy pipe.
## Decorative only; collision and a permanently solid footprint stay in owner.
const INK := Color("142520")
var footprint := Vector2.ZERO
var kind: StringName
func configure(size: Vector2, role: StringName) -> void:
	footprint = size
	kind = role
	queue_redraw()
func get_visual_rect() -> Rect2:
	return Rect2(-footprint.x*0.5,-footprint.y-32,footprint.x,footprint.y+32).grow(3)
func _shape(points: Array[Vector2], color: Color) -> void:
	var vertices := PackedVector2Array(points)
	draw_colored_polygon(vertices,color)
	vertices.append(vertices[0])
	draw_polyline(vertices,INK,3,true)
func _draw() -> void:
	var w := footprint.x
	var h := footprint.y
	match kind:
		&"planter":
			_shape([Vector2(-w*.47,-h+8),Vector2(w*.47,-h+8),Vector2(w*.45,-8),Vector2(-w*.45,-8)],Color("907c57"))
			draw_rect(Rect2(-w*.42,-h+15,w*.84,h*.60),Color("464b36"))
			for index in 3:
				var p := Vector2((index-1)*w*.26,-h*.65)
				draw_line(p+Vector2(0,10),p-Vector2(0,14),INK,3,true)
				# Keep the inner tip inside a narrow leaf; normal map art retains 3px.
				_shape([p,p+Vector2(-w*.10,-7),p+Vector2(-w*.10,-24),p+Vector2(-minf(3,w*.04),-16)],Color("70835b"))
				_shape([p-Vector2(0,6),p+Vector2(w*.09,-16),p+Vector2(w*.07,-29),p+Vector2(3,-20)],Color("93a577"))
			draw_rect(Rect2(-w*.45,-h*.25,w*.90,h*.20),Color("a4936b"))
			draw_line(Vector2(-w*.44,-h*.25),Vector2(w*.44,-h*.25),INK,3,true)
		&"greenhouse":
			_shape([Vector2(-w*.46,-8),Vector2(-w*.46,-h+12),Vector2(0,-h-26),Vector2(w*.46,-h+12),Vector2(w*.46,-8)],Color("789180"))
			_shape([Vector2(-w*.48,-h+12),Vector2(-w*.44,-h-2),Vector2(0,-h-30),Vector2(w*.44,-h-2),Vector2(w*.48,-h+12),Vector2(0,-h-13)],Color("b2b89a"))
			var door_w := minf(44,w*.24)
			draw_rect(Rect2(-door_w*.5,-h*.55,door_w,h*.55-8),Color("ac9b73"))
			draw_rect(Rect2(-door_w*.5,-h*.55,door_w,h*.55-8),INK,false,3)
			draw_line(Vector2(0,-h*.55),Vector2(0,-8),INK,3)
			draw_circle(Vector2(door_w*.22,-h*.24),2.5,INK)
			for side in [-1,1]:
				var at := Vector2(side*w*.29,-h*.63)
				draw_rect(Rect2(at-Vector2(w*.085,0),Vector2(w*.17,h*.37)),Color("536e60"))
				draw_rect(Rect2(at-Vector2(w*.085,0),Vector2(w*.17,h*.37)),INK,false,3)
				draw_line(at,at+Vector2(0,h*.37),Color("b6c3a7"),2)
		&"tank":
			_shape([Vector2(-w*.39,-8),Vector2(-w*.43,-h*.76),Vector2(-w*.29,-h-22),Vector2(w*.29,-h-22),Vector2(w*.43,-h*.76),Vector2(w*.39,-8)],Color("749184"))
			_shape([Vector2(-w*.41,-h*.78),Vector2(-w*.29,-h-24),Vector2(w*.29,-h-24),Vector2(w*.41,-h*.78)],Color("a5b6a2"))
			draw_line(Vector2(-w*.36,-h*.27),Vector2(w*.36,-h*.27),INK,3)
			var dial := Vector2(0,-h*.59)
			var r := minf(w*.13,17)
			draw_circle(dial,r+2,INK)
			draw_circle(dial,r,Color("dad4b8"))
			draw_line(dial,dial+Vector2(-r*.5,-r*.5),INK,2)
			draw_rect(Rect2(-w*.13,-h*.2,w*.26,h*.13),Color("a4936b"))
		&"pipe":
			_shape([Vector2(-w*.46,-h*.35),Vector2(-w*.46,-h*.85),Vector2(-w*.36,-h-18),Vector2(w*.36,-h-18),Vector2(w*.46,-h*.85),Vector2(w*.46,-h*.35)],Color("7b978b"))
			draw_line(Vector2(-w*.34,-h*.84),Vector2(w*.34,-h*.84),Color("b2c0a7"),4)
			for side in [-1,1]:
				var x: float = side*w*.28
				_shape([Vector2(x-w*.045,-h-21),Vector2(x+w*.045,-h-21),Vector2(x+w*.045,-6),Vector2(x-w*.045,-6)],Color("a89971"))
			draw_rect(Rect2(-w*.07,-h*.92,w*.14,h*.43),INK)
			draw_line(Vector2(0,-h*.87),Vector2(0,-h*.54),Color("dad4b8"),3)
