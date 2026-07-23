extends Control
class_name BossHealthBar

const BASE_WIDTH := 760.0
const BAR_HEIGHT := 28.0
const TOP_SAFE_OFFSET := 18.0
const MIN_WIDTH_RATIO := 0.60
const MAX_WIDTH_RATIO := 0.78
const BACKGROUND_COLOR := Color("061019e8")
const FILL_COLOR := Color("f559bf")
const MARKER_COLOR := Color("ff571f")
const BORDER_COLOR := Color("33fff2")

var name_label: Label
var phase_label: Label
var health_bar: ProgressBar
var thresholds: Array[float] = [0.70, 0.35]
var threshold_markers: Array[ColorRect] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	_build()
	apply_viewport_size(get_viewport().get_visible_rect().size)
	visible = false

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_make_background_style(), rect)

func _build() -> void:
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_bar.offset_left = 3.0
	health_bar.offset_top = 16.0
	health_bar.offset_right = -3.0
	health_bar.offset_bottom = -3.0
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_theme_stylebox_override("background", _make_bar_background_style())
	health_bar.add_theme_stylebox_override("fill", _make_fill_style())
	add_child(health_bar)
	for threshold in thresholds:
		var marker := ColorRect.new()
		marker.color = MARKER_COLOR
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.tooltip_text = "%d%% phase threshold" % int(threshold * 100.0)
		add_child(marker)
		threshold_markers.append(marker)

	name_label = _make_label("深渊监工 / OVERSEER", HORIZONTAL_ALIGNMENT_LEFT)
	name_label.name = "NameLabel"
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_left = 8.0
	name_label.offset_top = 0.0
	name_label.offset_right = -150.0
	name_label.offset_bottom = 16.0
	add_child(name_label)

	phase_label = _make_label("PHASE I", HORIZONTAL_ALIGNMENT_RIGHT)
	phase_label.name = "PhaseLabel"
	phase_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	phase_label.offset_left = -144.0
	phase_label.offset_top = 0.0
	phase_label.offset_right = -8.0
	phase_label.offset_bottom = 16.0
	add_child(phase_label)

func _make_label(text: String, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", BORDER_COLOR)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _make_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

func _make_bar_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b1c2a")
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1
	return style

func _make_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FILL_COLOR
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1
	return style

func apply_viewport_size(viewport_size: Vector2) -> void:
	var target_width := BASE_WIDTH * viewport_size.y / 720.0
	var minimum_width := viewport_size.x * MIN_WIDTH_RATIO
	var maximum_width := viewport_size.x * MAX_WIDTH_RATIO
	size = Vector2(clampf(target_width, minimum_width, maximum_width), BAR_HEIGHT)
	position = Vector2(-size.x * 0.5, TOP_SAFE_OFFSET)
	for marker_index in threshold_markers.size():
		var marker := threshold_markers[marker_index]
		marker.position = Vector2(size.x * thresholds[marker_index] - 1.0, 16.0)
		marker.size = Vector2(2.0, BAR_HEIGHT - 19.0)
	queue_redraw()

func show_boss(display_name: String, maximum_health: float) -> void:
	name_label.text = display_name
	health_bar.max_value = maxf(maximum_health, 1.0)
	health_bar.value = health_bar.max_value
	_set_phase(1)
	visible = true

func set_boss_health(current: float, maximum: float, phase: int) -> void:
	health_bar.max_value = maxf(maximum, 1.0)
	health_bar.value = clampf(current, 0.0, health_bar.max_value)
	_set_phase(phase)

func hide_boss() -> void:
	visible = false

func _set_phase(phase: int) -> void:
	phase_label.text = "PHASE %s" % ["I", "II", "III"][clampi(phase, 1, 3) - 1]
