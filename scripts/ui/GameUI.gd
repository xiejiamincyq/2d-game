extends CanvasLayer
class_name GameUI

signal upgrade_selected(choice: Dictionary)
signal start_requested
signal restart_requested
signal pause_requested
signal bgm_volume_changed(value: float)
signal bgm_mute_changed(muted: bool)

const CyberBackdropScript = preload("res://scripts/ui/CyberBackdrop.gd")
const CyberHudChromeScript = preload("res://scripts/ui/CyberHudChrome.gd")

var root: Control
var hud_root: Control
var start_backdrop: Control
var start_panel: PanelContainer
var upgrade_overlay: ColorRect
var upgrade_panel: PanelContainer
var pause_overlay: ColorRect
var pause_panel: PanelContainer
var result_overlay: ColorRect
var result_panel: PanelContainer
var pause_button: Button
var health_bar: ProgressBar
var xp_bar: ProgressBar
var health_value_label: Label
var shield_value_label: Label
var xp_value_label: Label
var wave_label: Label
var level_label: Label
var stats_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var result_label: Label
var combo_panel: PanelContainer
var combo_label: Label
var bgm_toggle_button: Button
var bgm_volume_slider: HSlider
var buttons: Array[Button] = []
var ui_font: SystemFont

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_theme()
	_build_root()
	_build_hud()
	_build_start_panel()
	_build_upgrade_panel()
	_build_pause_panel()
	_build_result_panel()

func _unhandled_input(event: InputEvent) -> void:
	if start_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			start_requested.emit()
			return
	if result_panel.visible and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		restart_requested.emit()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if not start_panel.visible and not upgrade_panel.visible and not result_panel.visible:
			pause_requested.emit()
			return
	if not upgrade_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_3:
			var index: int = key - KEY_1
			if index < buttons.size() and buttons[index].visible:
				buttons[index].pressed.emit()

func is_upgrade_open() -> bool:
	return upgrade_panel.visible

func set_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_value_label.text = "%d / %d" % [int(ceil(current)), int(maximum)]

func set_shield(value: float, maximum: float) -> void:
	shield_value_label.text = "护盾 %d / %d" % [int(ceil(value)), int(maximum)]

func set_experience(current: int, required: int, level: int) -> void:
	xp_bar.max_value = required
	xp_bar.value = current
	xp_value_label.text = "%d / %d" % [current, required]
	level_label.text = "等级 %d" % level

func set_wave(index: int, total: int, remaining: int) -> void:
	wave_label.text = "波次 %d / %d    剩余 %d" % [index, total, remaining]

func set_run_stats(kills: int, elapsed_seconds: float) -> void:
	stats_label.text = "击杀 %d    用时 %s" % [kills, _format_time(elapsed_seconds)]

func set_combo(count: int) -> void:
	if count <= 1:
		combo_panel.visible = false
		return
	combo_label.text = "连杀 x%d" % count
	combo_panel.visible = true
	combo_panel.modulate.a = 1.0
	combo_panel.scale = Vector2(1.10, 1.10)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(combo_panel, "scale", Vector2.ONE, 0.12)

func clear_combo() -> void:
	combo_panel.visible = false

func show_toast(text: String) -> void:
	toast_label.text = "模块上线 // " + text
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(toast_panel, "modulate:a", 0.0, 0.25)

func show_upgrades(choices: Array[Dictionary]) -> void:
	upgrade_overlay.visible = true
	upgrade_panel.visible = true
	upgrade_panel.modulate.a = 0.0
	upgrade_panel.scale = Vector2(0.96, 0.96)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(upgrade_panel, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(upgrade_panel, "scale", Vector2.ONE, 0.16)
	for index in range(buttons.size()):
		var button := buttons[index]
		if index < choices.size():
			var choice := choices[index]
			button.visible = true
			button.text = "0%d  %s\n\n%s" % [index + 1, choice["label"], choice["description"]]
			button.set_meta("choice", choice)
		else:
			button.visible = false
	if not buttons.is_empty():
		buttons[0].grab_focus()

func show_manual_pause() -> void:
	pause_overlay.visible = true
	pause_panel.visible = true
	pause_button.text = "继续"

func hide_manual_pause() -> void:
	pause_overlay.visible = false
	pause_panel.visible = false
	pause_button.text = "暂停"

func show_result(victory: bool, wave_text: String, kills: int, elapsed_seconds: float, level: int) -> void:
	result_overlay.visible = true
	result_panel.visible = true
	var title := "清剿完成" if victory else "系统失效"
	result_label.text = "%s\n%s\n击杀数量  %d\n作战用时  %s\n最终等级  %d\n战术评级  %s\n\n按 R 重新开始" % [
		title,
		wave_text,
		kills,
		_format_time(elapsed_seconds),
		level,
		_rating_for(kills, elapsed_seconds, victory)
	]
	get_tree().paused = true

func show_start_screen() -> void:
	hud_root.visible = false
	start_backdrop.visible = true
	start_panel.visible = true
	start_panel.modulate.a = 0.0
	var start_button := start_panel.get_node("Margin/Box/StartButton") as Button
	start_button.grab_focus()
	create_tween().tween_property(start_panel, "modulate:a", 1.0, 0.2)

func hide_start_screen() -> void:
	hud_root.visible = true
	start_backdrop.visible = false
	start_panel.visible = false

func _build_theme() -> void:
	ui_font = SystemFont.new()
	ui_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "Noto Sans CJK SC"])

func _build_root() -> void:
	root = Control.new()
	root.name = "UIRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var chrome := CyberHudChromeScript.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chrome)

func _build_hud() -> void:
	hud_root = Control.new()
	hud_root.name = "HUD"
	hud_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_root.offset_left = 14
	hud_root.offset_top = 10
	hud_root.offset_right = -14
	hud_root.offset_bottom = 104
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_root)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.018, 0.027, 0.76), Color(0.15, 0.95, 1.0, 0.56), 2, 5, 16))
	hud_root.add_child(frame)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	frame.add_child(row)

	var left_panel := VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(390, 66)
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.add_theme_constant_override("separation", 5)
	row.add_child(left_panel)
	var status_title := _make_micro_label("CORE STATUS", Color(1.0, 0.55, 0.22))
	left_panel.add_child(status_title)
	health_bar = _make_bar(Color(0.98, 0.12, 0.20), 100.0)
	health_value_label = _make_label("100 / 100", 13, Color(1.0, 0.88, 0.9))
	left_panel.add_child(_meter_row("生命", health_bar, health_value_label, Color(0.98, 0.24, 0.28)))
	xp_bar = _make_bar(Color(0.18, 0.9, 1.0), 10.0)
	xp_value_label = _make_label("0 / 10", 13, Color(0.82, 1.0, 1.0))
	left_panel.add_child(_meter_row("经验", xp_bar, xp_value_label, Color(0.18, 0.9, 1.0)))
	shield_value_label = _make_label("护盾 0 / 60", 13, Color(0.45, 1.0, 0.45))
	left_panel.add_child(shield_value_label)

	level_label = _make_badge("等级 1", Color(0.04, 0.11, 0.14, 0.94), Color(0.25, 1.0, 0.95))
	level_label.custom_minimum_size = Vector2(104, 48)
	row.add_child(level_label)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var right_stack := VBoxContainer.new()
	right_stack.custom_minimum_size = Vector2(260, 64)
	right_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right_stack)
	right_stack.add_child(_make_micro_label("WAVE TELEMETRY", Color(0.18, 0.9, 1.0)))
	wave_label = _make_label("等待部署", 18, Color(1.0, 0.62, 0.25))
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_stack.add_child(wave_label)
	stats_label = _make_label("击杀 0    用时 00:00", 14, Color(0.75, 0.88, 0.9))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_stack.add_child(stats_label)

	row.add_child(_build_bgm_controls())
	pause_button = _make_button("暂停", 15)
	pause_button.custom_minimum_size = Vector2(82, 40)
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	row.add_child(pause_button)

	toast_panel = PanelContainer.new()
	toast_panel.visible = false
	toast_panel.modulate.a = 0.0
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.08, 0.095, 0.95), Color(1.0, 0.55, 0.24, 0.92), 2, 5, 14))
	row.add_child(toast_panel)
	toast_label = _make_label("", 15, Color(0.94, 1.0, 1.0))
	toast_panel.add_child(toast_label)
	_build_combo_display()

func _build_combo_display() -> void:
	combo_panel = PanelContainer.new()
	combo_panel.name = "ComboPanel"
	combo_panel.visible = false
	combo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_panel.anchor_left = 0.5
	combo_panel.anchor_top = 1.0
	combo_panel.anchor_right = 0.5
	combo_panel.anchor_bottom = 1.0
	combo_panel.offset_left = -170
	combo_panel.offset_top = -96
	combo_panel.offset_right = 170
	combo_panel.offset_bottom = -36
	combo_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.025, 0.018, 0.86), Color(1.0, 0.56, 0.16, 1.0), 2, 5, 18))
	root.add_child(combo_panel)
	combo_label = _make_label("连杀 x0", 30, Color(1.0, 0.84, 0.26))
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_panel.add_child(combo_label)

func _build_bgm_controls() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.name = "BGMControls"
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	var label := _make_micro_label("BGM", Color(0.7, 0.95, 1.0))
	label.custom_minimum_size = Vector2(34, 24)
	box.add_child(label)
	bgm_volume_slider = HSlider.new()
	bgm_volume_slider.min_value = 0.0
	bgm_volume_slider.max_value = 100.0
	bgm_volume_slider.step = 1.0
	bgm_volume_slider.value = 65.0
	bgm_volume_slider.custom_minimum_size = Vector2(104, 28)
	bgm_volume_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	bgm_volume_slider.add_theme_stylebox_override("slider", _bar_style(Color(0.02, 0.04, 0.05), Color(0.1, 0.45, 0.5)))
	bgm_volume_slider.add_theme_stylebox_override("grabber_area", _bar_style(Color(0.18, 0.9, 1.0), Color(0.65, 1.0, 1.0)))
	bgm_volume_slider.value_changed.connect(func(value: float) -> void:
		bgm_volume_changed.emit(value / 100.0)
	)
	box.add_child(bgm_volume_slider)
	bgm_toggle_button = _make_button("BGM 开", 13)
	bgm_toggle_button.toggle_mode = true
	bgm_toggle_button.custom_minimum_size = Vector2(76, 30)
	bgm_toggle_button.toggled.connect(func(pressed: bool) -> void:
		bgm_toggle_button.text = "BGM 关" if pressed else "BGM 开"
		bgm_mute_changed.emit(pressed)
	)
	box.add_child(bgm_toggle_button)
	return box

func _build_start_panel() -> void:
	start_backdrop = CyberBackdropScript.new()
	start_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(start_backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	start_panel = PanelContainer.new()
	start_panel.name = "StartPanel"
	start_panel.custom_minimum_size = Vector2(780, 540)
	start_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	start_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.016, 0.026, 0.038, 0.96), Color(0.18, 0.95, 1.0, 0.95), 3, 6, 30))
	center.add_child(start_panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	start_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 15)
	margin.add_child(box)
	var kicker := _make_micro_label("PROJECT // SWEEP PROTOCOL", Color(1.0, 0.48, 0.18))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(kicker)
	var title := _make_label("废土清剿协议", 52, Color(0.2, 1.0, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := _make_label("高射速割草 / 多枪线进化 / 无人机激光阵列", 20, Color(0.9, 0.96, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(_divider(Color(0.18, 0.95, 1.0, 0.55), 560))
	var briefing := _make_label("游戏说明\nWASD 移动，鼠标瞄准，左键持续扫射。\n击杀敌人掉落经验晶片，升级时游戏会完全暂停。\n撑过 8 波敌潮，在护盾、枪线、无人机和地刺之间做取舍。", 19, Color(0.84, 0.94, 0.96))
	briefing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(briefing)
	var start_button := _make_button("开始部署", 24)
	start_button.name = "StartButton"
	start_button.custom_minimum_size = Vector2(380, 62)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(func() -> void: start_requested.emit())
	box.add_child(start_button)
	var hint := _make_label("Enter / Space 也可以开始", 14, Color(0.56, 0.73, 0.76))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

func _build_upgrade_panel() -> void:
	upgrade_overlay = _make_overlay(0.40)
	upgrade_overlay.visible = false
	root.add_child(upgrade_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	upgrade_panel = PanelContainer.new()
	upgrade_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	upgrade_panel.visible = false
	upgrade_panel.custom_minimum_size = Vector2(960, 430)
	upgrade_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	upgrade_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.016, 0.024, 0.034, 0.98), Color(1.0, 0.56, 0.22, 0.95), 3, 6, 28))
	center.add_child(upgrade_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 15)
	upgrade_panel.add_child(box)
	var title := _make_label("选择战斗模块", 30, Color(0.2, 1.0, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _make_label("时间已暂停，慢慢选一个爽的", 15, Color(1.0, 0.68, 0.30))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(_divider(Color(1.0, 0.56, 0.22, 0.48), 820))
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 14)
	box.add_child(card_row)
	for index in range(3):
		var button := _make_upgrade_button("")
		button.pressed.connect(_on_upgrade_button_pressed.bind(button))
		buttons.append(button)
		card_row.add_child(button)

func _build_pause_panel() -> void:
	pause_overlay = _make_overlay(0.42)
	pause_overlay.visible = false
	root.add_child(pause_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	pause_panel = PanelContainer.new()
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	pause_panel.custom_minimum_size = Vector2(390, 210)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.028, 0.04, 0.97), Color(0.2, 1.0, 0.95, 0.9), 3, 6, 24))
	center.add_child(pause_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	pause_panel.add_child(box)
	var title := _make_label("暂停中", 32, Color(0.2, 1.0, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint := _make_label("空格键或右上角按钮继续", 16, Color(0.82, 0.94, 0.96))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var resume := _make_button("继续作战", 20)
	resume.custom_minimum_size = Vector2(230, 52)
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(func() -> void: pause_requested.emit())
	box.add_child(resume)

func _build_result_panel() -> void:
	result_overlay = _make_overlay(0.52)
	result_overlay.visible = false
	root.add_child(result_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	result_panel = PanelContainer.new()
	result_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	result_panel.visible = false
	result_panel.custom_minimum_size = Vector2(560, 390)
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	result_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.028, 0.04, 0.97), Color(0.2, 1.0, 0.95, 0.9), 3, 6, 26))
	center.add_child(result_panel)
	result_label = _make_label("", 23, Color(0.9, 1.0, 1.0))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_panel.add_child(result_label)

func _on_upgrade_button_pressed(button: Button) -> void:
	var choice := button.get_meta("choice") as Dictionary
	upgrade_overlay.visible = false
	upgrade_panel.visible = false
	upgrade_selected.emit(choice)

func _meter_row(label_text: String, bar: ProgressBar, value_label: Label, tint: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var label := _make_micro_label(label_text, tint.lightened(0.12))
	label.custom_minimum_size = Vector2(42, 18)
	row.add_child(label)
	row.add_child(bar)
	value_label.custom_minimum_size = Vector2(76, 18)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return row

func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", ui_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_micro_label(text: String, color: Color) -> Label:
	var label := _make_label(text, 12, color)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	return label

func _make_badge(text: String, fill: Color, color: Color) -> Label:
	var label := _make_label(text, 17, color)
	label.custom_minimum_size = Vector2(100, 38)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _panel_style(fill, color.darkened(0.1), 2, 4, 12))
	return label

func _make_button(text: String, size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", ui_font)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.055, 0.11, 0.135), Color(0.18, 0.95, 1.0, 0.76)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.10, 0.24, 0.29), Color(1.0, 0.56, 0.22, 0.95)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.03, 0.07, 0.09), Color(1.0, 0.32, 0.16, 0.95)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.10, 0.24, 0.29), Color(1.0, 0.56, 0.22, 0.95)))
	button.add_theme_color_override("font_color", Color(0.92, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	return button

func _make_upgrade_button(text: String) -> Button:
	var button := _make_button(text, 18)
	button.custom_minimum_size = Vector2(292, 220)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_stylebox_override("normal", _button_style(Color(0.035, 0.055, 0.072), Color(0.16, 0.72, 0.82, 0.82), 18))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.075, 0.14, 0.16), Color(0.25, 1.0, 0.95, 1.0), 18))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.03, 0.055, 0.065), Color(1.0, 0.56, 0.22, 1.0), 18))
	return button

func _make_bar(fill: Color, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(232, 16)
	bar.max_value = max_value
	bar.value = max_value
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.015, 0.023, 0.032), Color(0.08, 0.20, 0.22)))
	bar.add_theme_stylebox_override("fill", _bar_style(fill, fill.lightened(0.24)))
	return bar

func _make_overlay(alpha: float) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, alpha)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return overlay

func _divider(color: Color, width: int = 500) -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(width, 2)
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _panel_style(fill: Color, border: Color, border_width: int, radius: int, margin: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	style.shadow_color = Color(border.r, border.g, border.b, 0.22)
	style.shadow_size = 14
	style.shadow_offset = Vector2.ZERO
	return style

func _button_style(fill: Color, border: Color, margin: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	style.shadow_color = Color(border.r, border.g, border.b, 0.18)
	style.shadow_size = 8
	return style

func _bar_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func _format_time(seconds: float) -> String:
	var total := int(floor(seconds))
	return "%02d:%02d" % [total / 60, total % 60]

func _rating_for(kills: int, elapsed_seconds: float, victory: bool) -> String:
	if victory and kills >= 700:
		return "S 级：弹幕风暴"
	if victory:
		return "A 级：清场专家"
	if kills >= 350:
		return "B 级：火力过载"
	return "C 级：协议中断"
