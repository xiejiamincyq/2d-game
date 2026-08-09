extends Node2D
class_name PlayerBSampleView

const BOARD_SIZE := Vector2i(1280, 720)
const SAMPLE_DIRECTION_COUNT := 8
const SAMPLE_STEP_DEGREES := 45.0
const FRAME_SIZE := Vector2(64.0, 64.0)
const BODY_ATLAS_PATH := "res://assets/art/actors/player/samples/player_b_sample_body_8dir.png"
const WEAPON_ATLAS_PATH := "res://assets/art/actors/player/samples/player_b_sample_weapon_8dir.png"
const COMPOSITE_ATLAS_PATH := "res://assets/art/actors/player/samples/player_b_sample_composite_8dir.png"

var body_atlas: Texture2D
var weapon_atlas: Texture2D
var composite_atlas: Texture2D

static func sample_index(angle_radians: float) -> int:
	var raw_index := roundi(rad_to_deg(angle_radians) / SAMPLE_STEP_DEGREES)
	return posmod(raw_index, SAMPLE_DIRECTION_COUNT)

static func weapon_draws_behind(index: int) -> bool:
	return posmod(index, SAMPLE_DIRECTION_COUNT) >= 5

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	body_atlas = _load_texture(BODY_ATLAS_PATH)
	weapon_atlas = _load_texture(WEAPON_ATLAS_PATH)
	composite_atlas = _load_texture(COMPOSITE_ATLAS_PATH)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)), Color("061019"))
	_draw_grid()
	_draw_row_marker(100.0, Color("33fff2"))
	_draw_row_marker(250.0, Color("f559bf"))
	_draw_row_marker(400.0, Color("ff571f"))
	_draw_row_marker(570.0, Color("d7e4e8"))
	for index in range(SAMPLE_DIRECTION_COUNT):
		_draw_sample(composite_atlas, index, Vector2(290.0 + index * 100.0, 100.0), 1.0)
		_draw_sample(body_atlas, index, Vector2(178.0 + index * 132.0, 250.0), 1.5)
		_draw_sample(weapon_atlas, index, Vector2(178.0 + index * 132.0, 400.0), 1.5)
		_draw_layered_sample(index, Vector2(178.0 + index * 132.0, 570.0), 1.5)

func _draw_grid() -> void:
	for x in range(0, BOARD_SIZE.x + 1, 32):
		draw_line(Vector2(x, 0), Vector2(x, BOARD_SIZE.y), Color(0.2, 1.0, 0.95, 0.035), 1.0)
	for y in range(0, BOARD_SIZE.y + 1, 32):
		draw_line(Vector2(0, y), Vector2(BOARD_SIZE.x, y), Color(0.2, 1.0, 0.95, 0.035), 1.0)

func _draw_row_marker(center_y: float, color: Color) -> void:
	draw_rect(Rect2(54.0, center_y - 28.0, 8.0, 56.0), color)
	draw_line(Vector2(74.0, center_y), Vector2(116.0, center_y), color, 2.0)

func _draw_layered_sample(index: int, center: Vector2, scale_factor: float) -> void:
	var collision_radius := 13.0 * scale_factor
	draw_circle(center, collision_radius, Color(0.2, 1.0, 0.95, 0.08))
	draw_arc(center, collision_radius, 0.0, TAU, 32, Color(0.2, 1.0, 0.95, 0.4), 1.0)
	if weapon_draws_behind(index):
		_draw_sample(weapon_atlas, index, center, scale_factor)
		_draw_sample(body_atlas, index, center, scale_factor)
	else:
		_draw_sample(body_atlas, index, center, scale_factor)
		_draw_sample(weapon_atlas, index, center, scale_factor)
	draw_line(center - Vector2(5.0, 0.0), center + Vector2(5.0, 0.0), Color(1, 1, 1, 0.7), 1.0)
	draw_line(center - Vector2(0.0, 5.0), center + Vector2(0.0, 5.0), Color(1, 1, 1, 0.7), 1.0)

func _draw_sample(texture: Texture2D, index: int, center: Vector2, scale_factor: float) -> void:
	if texture == null:
		return
	var destination_size := FRAME_SIZE * scale_factor
	var destination := Rect2(center - destination_size * 0.5, destination_size)
	var source := Rect2(Vector2(posmod(index, SAMPLE_DIRECTION_COUNT) * 64, 0), FRAME_SIZE)
	draw_texture_rect_region(texture, destination, source)

func _load_texture(path: String) -> Texture2D:
	var resource := ResourceLoader.load(path, "Texture2D")
	if resource is Texture2D:
		return resource as Texture2D
	push_error("Player B sample texture could not be loaded: " + path)
	return ImageTexture.new()
