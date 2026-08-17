extends Node2D

const FLOOR_Z_INDEX: int = -100
const GRID_TILE: int = 64
const MAJOR_GRID_TILE: int = 256
const FLOOR_EXTENT: int = 4096
const MAX_DRAW_COMMANDS: int = 900

var last_draw_command_count: int = 0

func _draw() -> void:
	last_draw_command_count = 0
	var world_rect := Rect2(-FLOOR_EXTENT, -FLOOR_EXTENT, FLOOR_EXTENT * 2, FLOOR_EXTENT * 2)
	_draw_rect_counted(world_rect, Color("0b1118"))
	for band in range(-FLOOR_EXTENT, FLOOR_EXTENT + 1, 512):
		_draw_rect_counted(Rect2(-FLOOR_EXTENT, band, FLOOR_EXTENT * 2, 64), Color(0.04, 0.065, 0.08, 0.34))
	for x in range(-FLOOR_EXTENT, FLOOR_EXTENT + GRID_TILE, GRID_TILE):
		var major := posmod(x, MAJOR_GRID_TILE) == 0
		var color := Color(0.10, 0.28, 0.32, 0.34) if major else Color(0.07, 0.16, 0.19, 0.24)
		_draw_line_counted(Vector2(x, -FLOOR_EXTENT), Vector2(x, FLOOR_EXTENT), color, 2.0 if major else 1.0)
	for y in range(-FLOOR_EXTENT, FLOOR_EXTENT + GRID_TILE, GRID_TILE):
		var major := posmod(y, MAJOR_GRID_TILE) == 0
		var color := Color(0.10, 0.28, 0.32, 0.34) if major else Color(0.07, 0.16, 0.19, 0.24)
		_draw_line_counted(Vector2(-FLOOR_EXTENT, y), Vector2(FLOOR_EXTENT, y), color, 2.0 if major else 1.0)
	for lane in range(-FLOOR_EXTENT, FLOOR_EXTENT + 1, 512):
		_draw_rect_counted(Rect2(-FLOOR_EXTENT, lane - 12, FLOOR_EXTENT * 2, 6), Color(0.95, 0.34, 0.08, 0.30))
		_draw_rect_counted(Rect2(lane - 12, -FLOOR_EXTENT, 6, FLOOR_EXTENT * 2), Color(0.16, 0.9, 1.0, 0.20))
	for block in range(-FLOOR_EXTENT, FLOOR_EXTENT + 1, 768):
		draw_rect(Rect2(block + 110, block - 180, 220, 110), Color(0.025, 0.032, 0.04, 0.9))
		last_draw_command_count += 1
		_draw_rect_counted(Rect2(block + 110, block - 180, 220, 110), Color(0.2, 1.0, 0.95, 0.52), false, 2.0)
		_draw_rect_counted(Rect2(block + 110, block - 180, 52, 5), Color(0.2, 1.0, 0.95, 0.72))
		_draw_rect_counted(Rect2(block - 260, -block + 130, 160, 90), Color(0.07, 0.04, 0.08, 0.85))
		_draw_rect_counted(Rect2(block - 260, -block + 130, 160, 90), Color(1.0, 0.24, 0.62, 0.42), false, 2.0)
		_draw_rect_counted(Rect2(block - 260, -block + 130, 5, 36), Color(1.0, 0.24, 0.62, 0.70))
	for i in range(120):
		var px := int((i * 137 + 811) % 7000) - 3500
		var py := int((i * 263 + 421) % 7000) - 3500
		var marker_color := Color(0.85, 0.24, 0.12, 0.28) if i % 3 != 0 else Color(0.20, 1.0, 0.95, 0.22)
		_draw_rect_counted(Rect2(px, py, 18, 3), marker_color)
	assert(last_draw_command_count <= MAX_DRAW_COMMANDS)

func _ready() -> void:
	z_index = FLOOR_Z_INDEX
	queue_redraw()

func _draw_rect_counted(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0) -> void:
	draw_rect(rect, color, filled, width)
	last_draw_command_count += 1

func _draw_line_counted(from: Vector2, to: Vector2, color: Color, width: float = -1.0) -> void:
	draw_line(from, to, color, width)
	last_draw_command_count += 1
