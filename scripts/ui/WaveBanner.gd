extends Control
class_name WaveBanner

signal finished(context: StringName)

var message_panel: PanelContainer
var message_label: Label
var banner_tween: Tween
var current_context: StringName = &""
var completion_pending: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center.offset_left = -360.0
	center.offset_top = 92.0
	center.offset_right = 360.0
	center.offset_bottom = 172.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	message_panel = PanelContainer.new()
	message_panel.custom_minimum_size = Vector2(620, 70)
	message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(message_panel)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 36)
	message_label.add_theme_color_override("font_color", Color(0.86, 1.0, 1.0))
	message_panel.add_child(message_label)

func show_message(text: String, context: StringName, duration: float = 1.1) -> void:
	_cancel_tween()
	current_context = context
	completion_pending = true
	message_label.text = text
	visible = true
	message_panel.modulate.a = 0.0
	message_panel.scale = Vector2(0.84, 0.84)
	banner_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	banner_tween.set_parallel(true)
	banner_tween.tween_property(message_panel, "modulate:a", 1.0, 0.16)
	banner_tween.tween_property(message_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.chain().tween_interval(maxf(0.05, duration - 0.34))
	banner_tween.chain().set_parallel(true)
	banner_tween.tween_property(message_panel, "modulate:a", 0.0, 0.18)
	banner_tween.tween_property(message_panel, "scale", Vector2(1.06, 1.06), 0.18)
	banner_tween.chain().tween_callback(finish_message)

func finish_message() -> void:
	if not completion_pending:
		return
	completion_pending = false
	_cancel_tween()
	visible = false
	message_panel.modulate.a = 1.0
	message_panel.scale = Vector2.ONE
	var resolved_context := current_context
	current_context = &""
	finished.emit(resolved_context)

func apply_viewport_size(viewport_size: Vector2) -> void:
	message_panel.custom_minimum_size.x = minf(620.0, viewport_size.x - 64.0)

func _cancel_tween() -> void:
	if banner_tween != null and banner_tween.is_valid():
		banner_tween.kill()
	banner_tween = null
