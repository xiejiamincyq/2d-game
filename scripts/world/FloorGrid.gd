extends Node2D

const FLOOR_Z_INDEX: int = -100
const FLOOR_EXTENT: int = 4096
const MAX_DRAW_COMMANDS: int = 900
const FLOOR_TEXTURE = preload("res://assets/art/environment/mint_farm_floor_b_v1.png")
const TILE_WORLD_SIZE := 512.0

var last_draw_command_count: int = 0

func _ready() -> void:
	z_index = FLOOR_Z_INDEX
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://assets/art/environment/floor_surface.gdshader")
	material = surface
	queue_redraw()

func _draw() -> void:
	var texture_scale := TILE_WORLD_SIZE / float(FLOOR_TEXTURE.get_width())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * texture_scale)
	var extent := float(FLOOR_EXTENT) / texture_scale
	draw_texture_rect(FLOOR_TEXTURE, Rect2(-extent, -extent, extent * 2.0, extent * 2.0), true)
	draw_set_transform(Vector2.ZERO)
	last_draw_command_count = 1
