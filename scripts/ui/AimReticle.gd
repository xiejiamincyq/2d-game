extends Control
class_name AimReticle

const RETICLE_SIZE := Vector2(56.0, 56.0)
const CYAN := Color(0.18, 1.0, 0.95, 0.96)
const MAGENTA := Color(1.0, 0.18, 0.72, 0.98)
const SHADOW := Color(0.0, 0.02, 0.04, 0.92)

var pulse_phase: float = 0.0

func _ready() -> void:
	custom_minimum_size = RETICLE_SIZE
	size = RETICLE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_active(false)

func _process(delta: float) -> void:
	pulse_phase = fmod(pulse_phase + delta * 4.5, TAU)
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
	var pulse_radius := 23.0 + sin(pulse_phase) * 2.0
	draw_arc(center, pulse_radius, 0.0, TAU, 64, SHADOW, 6.0, true)
	draw_arc(center, pulse_radius, 0.0, TAU, 64, CYAN, 2.5, true)
	draw_arc(center, 10.0, 0.0, TAU, 40, SHADOW, 5.0, true)
	draw_arc(center, 10.0, 0.0, TAU, 40, MAGENTA, 2.5, true)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var inner: Vector2 = center + direction * 13.0
		var outer: Vector2 = center + direction * 25.0
		draw_line(inner, outer, SHADOW, 6.0, true)
		draw_line(inner, outer, CYAN, 2.5, true)
	draw_circle(center, 4.0, SHADOW)
	draw_circle(center, 2.2, Color.WHITE)
