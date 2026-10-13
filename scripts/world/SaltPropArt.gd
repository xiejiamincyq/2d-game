extends Node2D
## Original matte basin ripples and a weathered lock crown; no downloaded sprite.
const INK := Color("171f25")
var footprint := Vector2.ZERO
var kind: StringName
func configure(size: Vector2,role: StringName) -> void:
	footprint = size
	kind = role
	queue_redraw()
func _draw() -> void:
	var w := footprint.x
	var h := footprint.y
	if kind==&"reservoir":
		# All water decoration stays inside the actual blocked rectangle.
		for y in range(30,int(h)-20,64):
			for x in range(28,int(w)-24,90):
				var at := Vector2(-w/2+x,-h+y)
				var span := minf(30,w-12-x)
				draw_polyline(PackedVector2Array([at,at+Vector2(span*0.3,-2),at+Vector2(span*0.7,0),at+Vector2(span,-2)]),Color("647d80"),2,true)
		for x in range(18,int(w)-12,86):
			draw_line(Vector2(-w/2+x,-h+8),Vector2(-w/2+minf(x+20,w-12),-h+8),Color("a1aa96"),3)
		return
	# Low wall crown extends above its permanent opaque collision plinth.
	var face := Rect2(-w/2+4,-h-22,w-8,h+18)
	draw_rect(face,Color("8b9482"))
	draw_rect(face,INK,false,3)
	draw_rect(Rect2(-w/2,-h-26,w,13),Color("abb39b"))
	draw_rect(Rect2(-w/2,-h-26,w,13),INK,false,3)
	for y in [-h*0.7,-h*0.35]:
		draw_line(Vector2(-w/2+5,y),Vector2(w/2-5,y),Color("53696a"),3)
	var wheel := Vector2(0,-h*0.55)
	draw_circle(wheel,14,INK)
	draw_circle(wheel,10,Color("786e54"))
	draw_line(wheel-Vector2(16,0),wheel+Vector2(16,0),INK,4)
	draw_line(wheel-Vector2(0,16),wheel+Vector2(0,16),INK,4)
	draw_line(Vector2(w*0.2,-h-7),Vector2(-w*0.1,-h*0.76),INK,2)
