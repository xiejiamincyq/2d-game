extends Control
class_name AimReticle

const RETICLE_SIZE := Vector2(24.0, 24.0)
const CREAM := Color("f3eddc")
const OUTLINE := Color("123b3b")

func _ready() -> void:
	custom_minimum_size = RETICLE_SIZE
	size = RETICLE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_active(false)

func _process(_delta: float) -> void:
	set_screen_position(get_viewport().get_mouse_position())
	queue_redraw()

func set_active(active: bool) -> void:
	visible = active
	set_process(active)
	if active:
		set_screen_position(get_viewport().get_mouse_position())
		queue_redraw()

func set_screen_position(screen_position: Vector2) -> void:
	position = screen_position - size * 0.5

func _draw() -> void:
	var center := size * 0.5
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var inner: Vector2 = center + direction * 5.0
		var outer: Vector2 = center + direction * 9.0
		draw_line(inner, outer, OUTLINE, 4.0, true)
		draw_line(inner, outer, CREAM, 2.0, true)
