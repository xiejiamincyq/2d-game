extends Control
class_name ResultScreen

signal restart_requested

var panel: PanelContainer
var result_label: Label
var restart_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 340)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_label.add_theme_font_size_override("font_size", 22)
	box.add_child(result_label)
	restart_button = Button.new()
	restart_button.text = "重新开始"
	restart_button.focus_mode = Control.FOCUS_ALL
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(restart_button)

func show_result(victory: bool, wave_text: String, kills: int, elapsed_seconds: float, level: int) -> void:
	var title := "清剿完成" if victory else "系统失效"
	result_label.text = "%s\n%s\n击杀数量 %d\n作战用时 %02d:%02d\n最终等级 %d\n\n按 R 或按钮重新开始" % [
		title, wave_text, kills, int(elapsed_seconds) / 60, int(elapsed_seconds) % 60, level
	]
	visible = true
	restart_button.grab_focus()

func hide_screen() -> void:
	visible = false

func apply_viewport_size(viewport_size: Vector2) -> void:
	panel.custom_minimum_size = Vector2(minf(520.0, viewport_size.x - 40.0), minf(340.0, viewport_size.y - 40.0))
