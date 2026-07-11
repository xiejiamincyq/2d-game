extends Control
class_name UpgradeScreen

signal choice_selected(choice: Dictionary)

var panel: PanelContainer
var choice_grid: GridContainer
var buttons: Array[Button] = []

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
	panel.custom_minimum_size = Vector2(900, 420)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := Label.new()
	title.text = "选择战斗模块"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	choice_grid = GridContainer.new()
	choice_grid.columns = 3
	choice_grid.add_theme_constant_override("h_separation", 12)
	choice_grid.add_theme_constant_override("v_separation", 10)
	choice_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(choice_grid)
	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 150)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_button_pressed.bind(button))
		choice_grid.add_child(button)
		buttons.append(button)

func _on_button_pressed(button: Button) -> void:
	choice_selected.emit(button.get_meta("choice") as Dictionary)

func show_choices(choices: Array[Dictionary]) -> void:
	visible = true
	for index in range(buttons.size()):
		var button := buttons[index]
		button.visible = index < choices.size()
		if button.visible:
			var choice := choices[index]
			button.text = "0%d  %s\n\n%s" % [index + 1, choice.get("label", ""), choice.get("description", "")]
			button.set_meta("choice", choice)
	if not buttons.is_empty() and buttons[0].visible:
		buttons[0].grab_focus()

func hide_screen() -> void:
	visible = false

func apply_viewport_size(viewport_size: Vector2) -> void:
	var compact := viewport_size.x < 1100.0
	choice_grid.columns = 1 if compact else 3
	panel.custom_minimum_size = Vector2(
		minf(viewport_size.x - 40.0, 900.0),
		minf(viewport_size.y - 40.0, 460.0 if compact else 420.0)
	)
	for button in buttons:
		button.custom_minimum_size = Vector2(0, 86 if compact else 150)

func get_required_size() -> Vector2:
	return panel.custom_minimum_size + Vector2(40, 40)
