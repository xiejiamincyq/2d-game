extends Node2D
## Original cut-paper shelves: raised book spines, closed plinth below.
const INK := Color("172d2c")
const BOOKS := [Color("b7ac87"),Color("8b967d"),Color("807366"),Color("b5ba9c")]
var footprint := Vector2.ZERO
func configure(size: Vector2) -> void: footprint = size; queue_redraw()
func _draw() -> void:
	var w := footprint.x; var h := footprint.y
	var crown := Rect2(-w/2+3,-h-24,w-6,h+16)
	draw_rect(crown,Color("798273")); draw_rect(crown,INK,false,3)
	draw_rect(Rect2(-w/2,-h-26,w,12),Color("adb096"))
	draw_rect(Rect2(-w/2,-h-26,w,12),INK,false,3)
	if w>=h:
		for x in range(10,int(w)-18,20):
			var index := x/20
			var book := Rect2(-w/2+x,-h-10,14,h-7)
			draw_rect(book,BOOKS[index%4]); draw_rect(book,INK,false,2)
			draw_line(book.position+Vector2(3,7),book.position+Vector2(11,7),Color("ddd2b1"),2)
		draw_line(Vector2(-w/2+4,-12),Vector2(w/2-4,-12),INK,4)
	else:
		for y in range(10,int(h)-14,26):
			var book := Rect2(-w/2+9,-h-15+y,w-18,18)
			draw_rect(book,BOOKS[(y/26)%4]); draw_rect(book,INK,false,2)
			draw_line(book.position+Vector2(5,5),book.position+Vector2(w-23,5),Color("ddd2b1"),2)
	# Muted static lichen: not an active hazard or a glowing pickup.
	var lichen := Vector2(w/2-12,-h-18)
	draw_circle(lichen,5,Color("7d9275")); draw_circle(lichen+Vector2(-7,3),3,Color("a5ad89"))
