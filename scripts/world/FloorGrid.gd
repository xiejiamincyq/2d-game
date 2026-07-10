extends Node2D

func _draw() -> void:
	var tile := 64
	var extent := 4096
	for x in range(-extent, extent + tile, tile):
		for y in range(-extent, extent + tile, tile):
			var base := Color(0.055, 0.065, 0.075)
			if int((x + y) / tile) % 2 == 0:
				base = Color(0.047, 0.057, 0.066)
			draw_rect(Rect2(x, y, tile, tile), base)
			draw_rect(Rect2(x, y, tile, 2), Color(0.08, 0.12, 0.14, 0.55))
			draw_rect(Rect2(x, y, 2, tile), Color(0.08, 0.12, 0.14, 0.55))
	for lane in range(-extent, extent + 1, 512):
		draw_rect(Rect2(-extent, lane - 12, extent * 2, 6), Color(0.95, 0.34, 0.08, 0.35))
		draw_rect(Rect2(lane - 12, -extent, 6, extent * 2), Color(0.16, 0.9, 1.0, 0.22))
	for block in range(-extent, extent + 1, 768):
		draw_rect(Rect2(block + 110, block - 180, 220, 110), Color(0.025, 0.032, 0.04, 0.9))
		draw_rect(Rect2(block + 110, block - 180, 220, 6), Color(0.2, 1.0, 0.95, 0.65))
		draw_rect(Rect2(block - 260, -block + 130, 160, 90), Color(0.07, 0.04, 0.08, 0.85))
		draw_rect(Rect2(block - 260, -block + 130, 6, 90), Color(1.0, 0.24, 0.62, 0.5))
	for i in range(120):
		var px := int((i * 137 + 811) % 7000) - 3500
		var py := int((i * 263 + 421) % 7000) - 3500
		draw_rect(Rect2(px, py, 18, 4), Color(0.85, 0.24, 0.12, 0.28))

func _ready() -> void:
	queue_redraw()
