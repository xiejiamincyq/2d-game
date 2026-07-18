extends Control
class_name PauseScreen

signal resume_requested
signal offer_selected(offer: Dictionary)

var panel: PanelContainer
var resume_button: Button
var coin_label: Label
var wave_label: Label
var offer_grid: GridContainer
var offer_buttons: Array[Button] = []
var current_state: Dictionary = {"wave": 0, "coins": 0, "offers": []}

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
	panel.custom_minimum_size = Vector2(900, 480)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "战术暂停 // 黑市补给"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 36)
	wave_label = Label.new()
	wave_label.text = "第 0 波报价"
	wave_label.add_theme_font_size_override("font_size", 18)
	coin_label = Label.new()
	coin_label.text = "金币 0"
	coin_label.add_theme_font_size_override("font_size", 18)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.18))
	status_row.add_child(wave_label)
	status_row.add_child(coin_label)
	box.add_child(status_row)

	var hint := Label.new()
	hint.text = "每波报价固定；购买不会结束暂停"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.65, 0.85, 0.9))
	box.add_child(hint)

	offer_grid = GridContainer.new()
	offer_grid.columns = 3
	offer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offer_grid.add_theme_constant_override("h_separation", 10)
	offer_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(offer_grid)
	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(230, 150)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_offer_pressed.bind(index))
		offer_grid.add_child(button)
		offer_buttons.append(button)

	resume_button = Button.new()
	resume_button.text = "继续清剿"
	resume_button.custom_minimum_size = Vector2(220, 46)
	resume_button.focus_mode = Control.FOCUS_ALL
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(resume_button)
	_refresh_shop()

func set_shop_state(state: Dictionary) -> void:
	current_state = state.duplicate(true)
	if coin_label != null:
		_refresh_shop()
		if visible:
			call_deferred("_focus_first_available")

func show_screen() -> void:
	visible = true
	_refresh_shop()
	_focus_first_available()

func hide_screen() -> void:
	visible = false

func apply_viewport_size(viewport_size: Vector2) -> void:
	var compact := viewport_size.x < 900.0
	offer_grid.columns = 1 if compact else 3
	panel.custom_minimum_size = Vector2(
		minf(900.0, viewport_size.x - 32.0),
		minf(480.0, viewport_size.y - 32.0)
	)
	for button in offer_buttons:
		button.custom_minimum_size = Vector2(0.0 if compact else 230.0, 86.0 if compact else 150.0)

func get_required_size() -> Vector2:
	return panel.get_combined_minimum_size() + Vector2(32, 32)

func _refresh_shop() -> void:
	var wave := int(current_state.get("wave", 0))
	var coins := int(current_state.get("coins", 0))
	wave_label.text = "第 %d 波报价" % wave
	coin_label.text = "金币 %d" % coins
	var offers_value: Variant = current_state.get("offers", [])
	var offers: Array = offers_value if offers_value is Array else []
	for index in range(offer_buttons.size()):
		var button := offer_buttons[index]
		if index >= offers.size():
			button.visible = false
			button.disabled = true
			button.text = ""
			continue
		var offer: Dictionary = offers[index]
		var sold := bool(offer.get("sold", false))
		var capped := bool(offer.get("capped", false))
		var affordable := bool(offer.get("affordable", false))
		var status := ""
		if sold:
			status = "\n[ 已购买 ]"
		elif capped:
			status = "\n[ 已达上限 ]"
		elif not affordable:
			status = "\n[ 金币不足 ]"
		button.visible = true
		button.disabled = sold or capped or not affordable
		button.text = "%d. %s\n%s · %s\n%s\n%d 金币%s" % [
			index + 1,
			String(offer.get("label", "未知模块")),
			_family_label(String(offer.get("family", ""))),
			_kind_label(String(offer.get("kind", ""))),
			String(offer.get("description", "")),
			int(offer.get("cost", 0)),
			status,
		]
		button.tooltip_text = button.text

func _focus_first_available() -> void:
	for button in offer_buttons:
		if button.visible and not button.disabled:
			button.grab_focus()
			return
	resume_button.grab_focus()

func _on_offer_pressed(index: int) -> void:
	var offers_value: Variant = current_state.get("offers", [])
	if not (offers_value is Array) or index < 0 or index >= offers_value.size():
		return
	if offer_buttons[index].disabled:
		return
	var offer: Dictionary = offers_value[index]
	offer_selected.emit(offer.duplicate(true))

func _family_label(family: String) -> String:
	match family:
		"projectile": return "弹幕"
		"drone_arc": return "无人机/电弧"
		"dash_spike": return "冲刺/地刺"
		"survival": return "生存"
		"mobility": return "机动"
		"economy": return "经济"
	return "通用"

func _kind_label(kind: String) -> String:
	return "核心" if kind == "core" else "支援"
