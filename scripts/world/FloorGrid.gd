extends Node2D

const FLOOR_Z_INDEX: int = -100
const FLOOR_EXTENT: int = 4096
const MAX_DRAW_COMMANDS: int = 900
const NATIVE_SURFACE := preload("res://assets/art/shaders/paper_arena_floor_v1.gdshader")

var last_draw_command_count: int = 0

func _ready() -> void:
	z_index = FLOOR_Z_INDEX
	var surface := ShaderMaterial.new()
	surface.shader = NATIVE_SURFACE
	material = surface
	queue_redraw()

func _draw() -> void:
	var extent := float(FLOOR_EXTENT)
	draw_rect(Rect2(-extent,-extent,extent*2.0,extent*2.0),Color.WHITE)
	last_draw_command_count = 1
