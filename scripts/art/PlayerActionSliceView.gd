extends Node2D
class_name PlayerActionSliceView

const BOARD_SIZE := Vector2i(1280, 720)
const ACTIONS := ["idle", "run", "fire", "dash", "hit"]
const FRAMES_PER_ACTION := 6
const FRAME_SIZE := Vector2i(64, 64)
const LAYER_ORDER := ["weapon_behind", "body", "weapon_front"]
const ACTION_FPS := {
	"idle": 6.0,
	"run": 10.0,
	"fire": 12.0,
	"dash": 12.0,
	"hit": 10.0,
}
const LAYER_PATHS := {
	"weapon_behind": "res://assets/art/actors/player/action_slices/player_b_action_slice_down_right_weapon_behind.png",
	"body": "res://assets/art/actors/player/action_slices/player_b_action_slice_down_right_body.png",
	"weapon_front": "res://assets/art/actors/player/action_slices/player_b_action_slice_down_right_weapon_front.png",
}
const SOCKETS_PATH := "res://assets/art/actors/player/action_slices/player_b_action_slice_down_right_sockets.json"

var layer_textures: Dictionary = {}
var sockets: Dictionary = {}
var elapsed := 0.0

static func frame_rect(action_index: int, frame_index: int) -> Rect2i:
	return Rect2i(
		Vector2i(posmod(frame_index, FRAMES_PER_ACTION), posmod(action_index, ACTIONS.size())) * FRAME_SIZE,
		FRAME_SIZE
	)

static func playback_frame(action: String, time_seconds: float) -> int:
	var fps: float = ACTION_FPS.get(action, 1.0)
	return posmod(floori(maxf(time_seconds, 0.0) * fps), FRAMES_PER_ACTION)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for layer in LAYER_ORDER:
		var texture := ResourceLoader.load(LAYER_PATHS[layer], "Texture2D") as Texture2D
		if texture == null:
			push_error("Player action slice layer could not be loaded: " + LAYER_PATHS[layer])
			texture = ImageTexture.new()
		layer_textures[layer] = texture
	sockets = _load_sockets()
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func socket_position(action: String, frame_index: int, socket_name: String) -> Vector2:
	var action_frames: Array = sockets.get("actions", {}).get(action, [])
	if action_frames.is_empty():
		return Vector2.ZERO
	var frame: Dictionary = action_frames[posmod(frame_index, action_frames.size())]
	var values: Array = frame.get(socket_name, [])
	if values.size() != 2:
		return Vector2.ZERO
	return Vector2(float(values[0]), float(values[1]))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(BOARD_SIZE)), Color("061019"))
	_draw_grid()
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(54.0, 44.0), "B ACTION SLICE / DOWN-RIGHT / 45 DEG", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("33fff2"))
	draw_string(font, Vector2(760.0, 44.0), "MAGENTA: GRIP   ORANGE: MUZZLE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("d7e4e8"))
	draw_string(font, Vector2(1140.0, 44.0), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("33fff2"))
	draw_line(Vector2(1104.0, 60.0), Vector2(1104.0, 700.0), Color(0.2, 1.0, 0.95, 0.18), 1.0)
	for action_index in range(ACTIONS.size()):
		var center_y := 112.0 + action_index * 122.0
		draw_string(font, Vector2(54.0, center_y + 5.0), ACTIONS[action_index].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 90.0, 16, Color("d7e4e8"))
		for frame_index in range(FRAMES_PER_ACTION):
			var center := Vector2(180.0 + frame_index * 154.0, center_y)
			_draw_layered_frame(action_index, frame_index, center, 1.5)
		var live_frame := playback_frame(ACTIONS[action_index], elapsed)
		_draw_layered_frame(action_index, live_frame, Vector2(1170.0, center_y), 1.8)

func _draw_grid() -> void:
	for x in range(0, BOARD_SIZE.x + 1, 32):
		draw_line(Vector2(x, 0), Vector2(x, BOARD_SIZE.y), Color(0.2, 1.0, 0.95, 0.03), 1.0)
	for y in range(0, BOARD_SIZE.y + 1, 32):
		draw_line(Vector2(0, y), Vector2(BOARD_SIZE.x, y), Color(0.2, 1.0, 0.95, 0.03), 1.0)

func _draw_layered_frame(action_index: int, frame_index: int, center: Vector2, scale_factor: float) -> void:
	var collision_radius := 13.0 * scale_factor
	draw_circle(center, collision_radius, Color(0.2, 1.0, 0.95, 0.07))
	draw_arc(center, collision_radius, 0.0, TAU, 32, Color(0.2, 1.0, 0.95, 0.35), 1.0)
	for layer in LAYER_ORDER:
		_draw_layer(layer_textures.get(layer), action_index, frame_index, center, scale_factor)
	var action: String = ACTIONS[action_index]
	var top_left := center - Vector2(FRAME_SIZE) * scale_factor * 0.5
	var grip := top_left + socket_position(action, frame_index, "grip") * scale_factor
	var muzzle := top_left + socket_position(action, frame_index, "muzzle") * scale_factor
	draw_line(grip, muzzle, Color(1.0, 0.34, 0.12, 0.45), 1.0)
	draw_circle(grip, 2.5, Color("f559bf"))
	draw_circle(muzzle, 2.5, Color("ff571f"))

func _draw_layer(texture: Texture2D, action_index: int, frame_index: int, center: Vector2, scale_factor: float) -> void:
	if texture == null:
		return
	var destination_size := Vector2(FRAME_SIZE) * scale_factor
	var destination := Rect2(center - destination_size * 0.5, destination_size)
	draw_texture_rect_region(texture, destination, Rect2(frame_rect(action_index, frame_index)))

func _load_sockets() -> Dictionary:
	var file := FileAccess.open(SOCKETS_PATH, FileAccess.READ)
	if file == null:
		push_error("Player action slice sockets could not be loaded: " + SOCKETS_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("Player action slice sockets are invalid JSON: " + SOCKETS_PATH)
	return {}
