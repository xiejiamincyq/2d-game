extends Control
class_name BossEntranceOverlay

const CYAN := Color("33fff2")
const MAGENTA := Color("f559bf")
const ORANGE := Color("ff571f")

var title_label: Label
var elapsed := 0.0
var duration := 1.4
var layout_viewport_size := Vector2(1280.0, 720.0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_build()
	apply_viewport_size(get_viewport().get_visible_rect().size)
	visible = false

func _build() -> void:
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.88, 1.0, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(title_label)

func show_intro(display_name: String, intro_duration: float = 1.4) -> void:
	title_label.text = display_name + "\n接管战场"
	duration = maxf(intro_duration, 0.01)
	elapsed = 0.0
	visible = true
	queue_redraw()

func hide_intro() -> void:
	visible = false

func apply_viewport_size(viewport_size: Vector2) -> void:
	layout_viewport_size = viewport_size
	position = Vector2.ZERO
	size = viewport_size
	var center := get_intro_center()
	var label_width := minf(520.0, viewport_size.x - 40.0)
	title_label.position = center + Vector2(-label_width * 0.5, 98.0)
	title_label.size = Vector2(label_width, 76.0)
	queue_redraw()

func get_intro_center() -> Vector2:
	return layout_viewport_size * 0.5

func _process(delta: float) -> void:
	if not visible:
		return
	elapsed = minf(duration, elapsed + maxf(delta, 0.0))
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var center := get_intro_center()
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, progress)
	var pulse := 1.0 + sin(progress * PI * 5.0) * (1.0 - progress) * 0.08
	draw_rect(Rect2(Vector2.ZERO, layout_viewport_size), Color(0.0, 0.015, 0.03, 0.38 * sin(progress * PI)))
	for ring_index in range(3):
		var ring_phase := fposmod(progress + float(ring_index) / 3.0, 1.0)
		var radius := lerpf(42.0, 190.0, ring_phase)
		var alpha := (1.0 - ring_phase) * 0.62
		draw_arc(center, radius, 0.0, TAU, 72, Color(CYAN, alpha), 3.0)
	var visual_scale := (lerpf(0.2, 1.0, eased) + sin(progress * PI) * 0.12) * pulse
	draw_set_transform(center, lerpf(-0.35, 0.0, eased), Vector2.ONE * visual_scale)
	draw_circle(Vector2.ZERO, 70.0, Color("071b2fe8"))
	draw_circle(Vector2.ZERO, 48.0, Color(MAGENTA, 0.82))
	draw_circle(Vector2.ZERO, 27.0, Color("061019"))
	draw_circle(Vector2.ZERO, 13.0, ORANGE)
	var crown := PackedVector2Array([
		Vector2(-62.0, -36.0), Vector2(-33.0, -78.0), Vector2(-10.0, -49.0),
		Vector2(0.0, -88.0), Vector2(12.0, -49.0), Vector2(36.0, -78.0), Vector2(64.0, -34.0)
	])
	draw_polyline(crown, CYAN, 7.0, true)
	for arm_index in range(8):
		var angle := TAU * float(arm_index) / 8.0 + progress * 0.8
		var start := Vector2.RIGHT.rotated(angle) * 56.0
		var finish := Vector2.RIGHT.rotated(angle) * 88.0
		draw_line(start, finish, Color(CYAN, 0.82), 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
