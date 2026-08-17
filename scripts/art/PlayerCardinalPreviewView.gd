extends Node2D
class_name PlayerCardinalPreviewView

const BOARD_SIZE := Vector2i(1280, 720)
const DIRECTIONS := ["FRONT", "RIGHT SIDE", "REAR"]
const OPTION_IDS := ["A", "B", "C"]
const FRAME_SIZE := Vector2(64, 64)
const LAYER_ORDER := ["weapon_behind", "body", "weapon_front"]
const LAYER_PATHS := {
	"weapon_behind": "res://assets/art/actors/player/direction_previews/player_b_cardinal_layered_preview_weapon_behind.png",
	"body": "res://assets/art/actors/player/direction_previews/player_b_cardinal_layered_preview_body.png",
	"weapon_front": "res://assets/art/actors/player/direction_previews/player_b_cardinal_layered_preview_weapon_front.png",
}

var textures: Dictionary = {}

static func frame_rect(index: int) -> Rect2:
	return Rect2(Vector2(posmod(index, DIRECTIONS.size()) * 64, 0), FRAME_SIZE)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for layer in LAYER_ORDER:
		textures[layer] = ResourceLoader.load(LAYER_PATHS[layer], "Texture2D") as Texture2D
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)), Color("061019"))
	_draw_grid()
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(48, 44), "PLAYER B / TRUE-YAW LAYERED DIRECTION PREVIEWS", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("33fff2"))
	draw_string(font, Vector2(48, 70), "45 DEG CAMERA LOCK / BODY + WEAPON BEHIND + WEAPON FRONT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d7e4e8"))
	draw_string(font, Vector2(48, 430), "SEPARATED LAYERS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f559bf"))
	draw_string(font, Vector2(48, 625), "64PX GAMEPLAY SCALE + 13PX COLLISION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ff571f"))
	for index in range(DIRECTIONS.size()):
		var center_x := 235.0 + index * 405.0
		var option_label := "%s / %s" % [OPTION_IDS[index], DIRECTIONS[index]]
		draw_string(font, Vector2(center_x - 90, 106), option_label, HORIZONTAL_ALIGNMENT_CENTER, 180, 17, Color("d7e4e8"))
		_draw_composite(index, Vector2(center_x, 245), 3.2, false)
		_draw_layer(index, "weapon_behind", Vector2(center_x - 88, 492), 1.25)
		_draw_layer(index, "body", Vector2(center_x, 492), 1.25)
		_draw_layer(index, "weapon_front", Vector2(center_x + 88, 492), 1.25)
		_draw_composite(index, Vector2(center_x, 632), 1.0, true)
		draw_string(font, Vector2(center_x - 124, 550), "BEHIND", HORIZONTAL_ALIGNMENT_CENTER, 72, 11, Color("ff571f"))
		draw_string(font, Vector2(center_x - 36, 550), "BODY", HORIZONTAL_ALIGNMENT_CENTER, 72, 11, Color("33fff2"))
		draw_string(font, Vector2(center_x + 52, 550), "FRONT", HORIZONTAL_ALIGNMENT_CENTER, 72, 11, Color("f559bf"))

func _draw_grid() -> void:
	for x in range(0, BOARD_SIZE.x + 1, 32):
		draw_line(Vector2(x, 0), Vector2(x, BOARD_SIZE.y), Color(0.2, 1.0, 0.95, 0.035), 1)
	for y in range(0, BOARD_SIZE.y + 1, 32):
		draw_line(Vector2(0, y), Vector2(BOARD_SIZE.x, y), Color(0.2, 1.0, 0.95, 0.035), 1)
	for x in [437.0, 842.0]:
		draw_line(Vector2(x, 92), Vector2(x, 700), Color(0.2, 1.0, 0.95, 0.18), 1)

func _draw_composite(index: int, center: Vector2, scale_factor: float, collision: bool) -> void:
	if collision:
		draw_circle(center, 13.0, Color(0.2, 1.0, 0.95, 0.08))
		draw_arc(center, 13.0, 0, TAU, 32, Color(0.2, 1.0, 0.95, 0.65), 1)
	for layer in LAYER_ORDER:
		_draw_layer(index, layer, center, scale_factor)
	if collision:
		draw_line(center - Vector2(5, 0), center + Vector2(5, 0), Color.WHITE, 1)
		draw_line(center - Vector2(0, 5), center + Vector2(0, 5), Color.WHITE, 1)

func _draw_layer(index: int, layer: String, center: Vector2, scale_factor: float) -> void:
	var texture := textures.get(layer) as Texture2D
	if texture == null:
		return
	var size := FRAME_SIZE * scale_factor
	draw_texture_rect_region(texture, Rect2(center - size * 0.5, size), frame_rect(index))
