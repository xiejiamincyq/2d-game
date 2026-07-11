extends Control
class_name PauseScreen

signal resume_requested

var panel: PanelContainer
var resume_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 200)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := Label.new()
	title.text = "系统暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	resume_button = Button.new()
	resume_button.text = "继续"
	resume_button.focus_mode = Control.FOCUS_ALL
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(resume_button)

func show_screen() -> void:
	visible = true
	resume_button.grab_focus()

func hide_screen() -> void:
	visible = false

func apply_viewport_size(viewport_size: Vector2) -> void:
	panel.custom_minimum_size = Vector2(minf(360.0, viewport_size.x - 40.0), minf(200.0, viewport_size.y - 40.0))
