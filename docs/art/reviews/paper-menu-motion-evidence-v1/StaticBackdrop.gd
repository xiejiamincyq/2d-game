extends Control
## Original native illustration; decorative only, never a map/collider.

const INK := Color("142520")
const MOSS := Color("53634c")
const PAPER := Color("dac9a6")

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _shape(points: Array[Vector2], color: Color, outline := 4.0) -> void:
	var vertices := PackedVector2Array(points)
	draw_colored_polygon(vertices, color)
	vertices.append(vertices[0])
	draw_polyline(vertices, INK, outline, true)

func _draw() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1280, 720))
	draw_rect(Rect2(0, 0, 1280, 720), Color("293d35"))
	draw_circle(Vector2(1000, 140), 84, Color("a7b399"))
	draw_circle(Vector2(1020, 121), 75, Color("293d35"))
	for i in 34:
		var at := Vector2(540 + fmod(i * 113.0, 710), 45 + fmod(i * 47.0, 250))
		draw_line(at, at + Vector2(3, 0), Color("677c69"), 2)
	_shape([Vector2(0, 378), Vector2(173, 330), Vector2(280, 358), Vector2(390, 309), Vector2(570, 371), Vector2(746, 314), Vector2(887, 336), Vector2(1041, 296), Vector2(1280, 359), Vector2(1280, 720), Vector2(0, 720)], Color("344c3c"), 0)
	# Quiet distant iron ribs, not silhouettes copied from an external asset.
	for x in [646, 725, 1168, 1233]:
		draw_line(Vector2(x, 384), Vector2(x + 8, 233), Color("233b32"), 8)
		draw_line(Vector2(x + 8, 233), Vector2(x + 32, 216), Color("233b32"), 7)
	_shape([Vector2(0, 476), Vector2(231, 423), Vector2(502, 469), Vector2(717, 416), Vector2(973, 441), Vector2(1280, 394), Vector2(1280, 720), Vector2(0, 720)], Color("405341"), 0)
	_shape([Vector2(766, 472), Vector2(889, 472), Vector2(985, 559), Vector2(1077, 614), Vector2(982, 720), Vector2(523, 720), Vector2(780, 600), Vector2(841, 561)], Color("8a8968"), 3)
	for i in 11:
		var p := Vector2(737 + fmod(i * 43.0, 218), 540 + i * 13.0)
		draw_line(p, p + Vector2(32, -7), Color("6c7257"), 3)
	# Broken seed-house: compact roof, warm empty doorway, strong paper outline.
	_shape([Vector2(762, 282), Vector2(906, 219), Vector2(1053, 282), Vector2(1053, 475), Vector2(762, 475)], Color("64705a"))
	_shape([Vector2(739, 287), Vector2(901, 197), Vector2(1077, 287), Vector2(1060, 304), Vector2(902, 222), Vector2(757, 307)], Color("9d906b"), 6)
	_shape([Vector2(875, 355), Vector2(918, 341), Vector2(961, 361), Vector2(961, 478), Vector2(875, 478)], Color("202f28"), 5)
	_shape([Vector2(883, 368), Vector2(919, 353), Vector2(949, 369), Vector2(949, 473), Vector2(883, 473)], Color("bd9560"), 3)
	draw_line(Vector2(904, 360), Vector2(904, 473), INK, 5)
	for rect in [Rect2(787, 325, 52, 72), Rect2(991, 327, 38, 69)]:
		draw_rect(rect, Color("34483b"))
		draw_rect(rect, INK, false, 4)
		draw_line(rect.get_center() - Vector2(0, 36), rect.get_center() + Vector2(0, 36), Color("819078"), 3)
		draw_line(rect.position + Vector2(0, 36), rect.position + Vector2(rect.size.x, 36), Color("819078"), 3)
	for i in 9:
		draw_line(Vector2(777, 420 + i * 6), Vector2(852, 408 + i * 6), Color("4c5f4c"), 2)
	# Ivy curves remain narrow; original leaf glyphs share the actor crest palette.
	for side in [0, 1]:
		var x: int = 760 + side * 275
		draw_polyline(PackedVector2Array([Vector2(x, 458), Vector2(x - 8, 395), Vector2(x + 17, 336), Vector2(x + 3, 284)]), INK, 10, true)
		for i in 7:
			var p := Vector2(x + sin(i * 1.7) * 16, 308 + i * 23)
			_shape([p, p + Vector2(-21, -10), p + Vector2(-27, -27), p + Vector2(-6, -22)], MOSS, 3)
	_shape([Vector2(718, 483), Vector2(802, 478), Vector2(799, 514), Vector2(733, 520)], Color("787759"))
	_shape([Vector2(1034, 482), Vector2(1109, 482), Vector2(1101, 521), Vector2(1043, 519)], Color("787759"))
	for x in [744, 770, 1058, 1085]:
		draw_line(Vector2(x, 484), Vector2(x - 4, 455), INK, 5)
		_shape([Vector2(x - 4, 464), Vector2(x - 20, 453), Vector2(x - 24, 437), Vector2(x - 7, 441)], MOSS, 3)
	# Ground crop, stones and mushrooms; wide stepping gaps, no gameplay promise.
	for i in 14:
		var p := Vector2(558 + fmod(i * 71.0, 682), 529 + fmod(i * 29.0, 142))
		_shape([p, p + Vector2(25, -6), p + Vector2(38, 5), p + Vector2(24, 17), p + Vector2(-4, 12)], Color("67705a"), 3)
	for p in [Vector2(1148, 625), Vector2(1114, 646), Vector2(619, 638)]:
		draw_line(p, p - Vector2(0, 25), PAPER, 9)
		_shape([p + Vector2(-27, -25), p + Vector2(-16, -42), p + Vector2(5, -49), p + Vector2(28, -26)], Color("b9946a"), 4)
	# Sparse horizontal mist, not glow; stays behind UI and opaque bodies.
	for i in 6:
		draw_line(Vector2(577 + i * 69, 398 + i * 18), Vector2(802 + i * 67, 395 + i * 18), Color(0.7, 0.76, 0.66, 0.11), 12, true)
	_shape([Vector2(0, 621), Vector2(187, 607), Vector2(348, 652), Vector2(568, 650), Vector2(714, 720), Vector2(0, 720)], INK, 0)
	_shape([Vector2(1098, 720), Vector2(1184, 659), Vector2(1237, 646), Vector2(1280, 577), Vector2(1280, 720)], INK, 0)
	# Left reading zone, ink rule and paper registration flecks.
	draw_rect(Rect2(0, 0, 520, 720), Color(0.04, 0.09, 0.07, 0.35))
	for i in 48:
		var p := Vector2(fmod(i * 137.0 + 41, 1280), fmod(i * 97.0 + 21, 720))
		draw_line(p, p + Vector2(6, 0), Color(0.8, 0.78, 0.63, 0.065), 1)
