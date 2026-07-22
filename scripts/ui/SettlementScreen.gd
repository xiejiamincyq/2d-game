extends Control
class_name SettlementScreen

signal offer_selected(offer: Dictionary)
signal close_requested

const FAMILY_ORDER: Array[String] = ["ballistics", "mobility", "automation"]

var panel: PanelContainer
var title_label: Label
var wave_label: Label
var coin_label: Label
var hint_label: Label
var family_labels: Dictionary = {}
var offer_buttons: Array[Button] = []
var close_button: Button
var current_state: Dictionary = {}
var current_offers: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(928, 508)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	title_label = Label.new()
	title_label.text = "波次结算 // 构筑升级"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	box.add_child(title_label)

	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 36)
	wave_label = Label.new()
	wave_label.add_theme_font_size_override("font_size", 18)
	coin_label = Label.new()
	coin_label.add_theme_font_size_override("font_size", 18)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.18))
	status_row.add_child(wave_label)
	status_row.add_child(coin_label)
	box.add_child(status_row)

	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.9, 0.95))
	box.add_child(hint_label)

	var family_row := HBoxContainer.new()
	family_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	family_row.add_theme_constant_override("separation", 10)
	box.add_child(family_row)
	for family_id in FAMILY_ORDER:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 6)
		family_row.add_child(column)
		var family_label := Label.new()
		family_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		family_label.add_theme_font_size_override("font_size", 18)
		family_label.add_theme_color_override("font_color", _family_color(family_id))
		column.add_child(family_label)
		family_labels[family_id] = family_label
		for _slot in range(2):
			var button := Button.new()
			button.custom_minimum_size = Vector2(260, 122)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.focus_mode = Control.FOCUS_ALL
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.pressed.connect(_on_offer_pressed.bind(offer_buttons.size()))
			column.add_child(button)
			offer_buttons.append(button)

	close_button = Button.new()
	close_button.text = "关闭并开始下一波"
	close_button.custom_minimum_size = Vector2(240, 46)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.pressed.connect(func() -> void: close_requested.emit())
	box.add_child(close_button)
	_refresh()

func set_state(state: Dictionary) -> void:
	current_state = state.duplicate(true)
	if panel != null:
		_refresh()
		if visible:
			call_deferred("_focus_first_available")

func show_screen() -> void:
	visible = true
	_refresh()
	_focus_first_available()

func hide_screen() -> void:
	visible = false

func apply_viewport_size(viewport_size: Vector2) -> void:
	panel.custom_minimum_size = Vector2(
		minf(928.0, viewport_size.x - 32.0),
		minf(508.0, viewport_size.y - 32.0)
	)

func get_required_size() -> Vector2:
	return panel.get_combined_minimum_size() + Vector2(32, 32)

func _refresh() -> void:
	var wave := int(current_state.get("wave", 0))
	var coins := int(current_state.get("coins", 0))
	var reward_claimed := bool(current_state.get("reward_claimed", false))
	wave_label.text = "第 %d 波战利品" % wave
	coin_label.text = "金币 %d" % coins
	hint_label.text = "先免费领取一张获胜奖励" if not reward_claimed else "可继续购买，完成后关闭进入下一波"
	close_button.disabled = not bool(current_state.get("can_close", false))

	current_offers.clear()
	var family_entries: Variant = current_state.get("families", [])
	var entries: Array = family_entries if family_entries is Array else []
	for family_id in FAMILY_ORDER:
		var entry := _find_family(entries, family_id)
		var levels: Dictionary = current_state.get("family_levels", {})
		var label: Label = family_labels[family_id]
		label.text = "%s  Lv.%d" % [String(entry.get("label", _family_label(family_id))), int(levels.get(family_id, 1))]
		var offers_value: Variant = entry.get("offers", [])
		if offers_value is Array:
			for offer_value in offers_value:
				if offer_value is Dictionary:
					current_offers.append(offer_value)

	for index in range(offer_buttons.size()):
		var button := offer_buttons[index]
		if index >= current_offers.size():
			button.visible = false
			button.disabled = true
			button.text = ""
			continue
		var offer: Dictionary = current_offers[index]
		var sold := bool(offer.get("sold", false))
		var capped := bool(offer.get("capped", false))
		var affordable := bool(offer.get("affordable", false))
		var action_text := "免费领取"
		if sold:
			action_text = "已获得"
		elif capped:
			action_text = "已达上限"
		elif reward_claimed:
			action_text = "%d 金币" % int(offer.get("cost", 0)) if affordable else "金币不足"
		button.visible = true
		button.disabled = sold or capped or (reward_claimed and not affordable)
		button.text = "%d. %s\n%s\n%s\n[ %s ]" % [
			index + 1,
			String(offer.get("label", "未知模块")),
			String(offer.get("description", "")),
			"卡牌层数 %d" % int(offer.get("rank", 0)),
			action_text,
		]
		button.tooltip_text = button.text

func _find_family(entries: Array, family_id: String) -> Dictionary:
	for entry_value in entries:
		if entry_value is Dictionary and String(entry_value.get("id", "")) == family_id:
			return entry_value
	return {"id": family_id, "label": _family_label(family_id), "offers": []}

func _focus_first_available() -> void:
	for button in offer_buttons:
		if button.visible and not button.disabled:
			button.grab_focus()
			return
	if not close_button.disabled:
		close_button.grab_focus()

func _on_offer_pressed(index: int) -> void:
	if index < 0 or index >= current_offers.size() or offer_buttons[index].disabled:
		return
	offer_selected.emit(current_offers[index].duplicate(true))

func _family_label(family_id: String) -> String:
	match family_id:
		"ballistics": return "火力"
		"mobility": return "机动"
		"automation": return "工程"
	return "通用"

func _family_color(family_id: String) -> Color:
	match family_id:
		"ballistics": return Color(1.0, 0.42, 0.18)
		"mobility": return Color(0.25, 1.0, 0.88)
		"automation": return Color(0.72, 0.42, 1.0)
	return Color.WHITE
