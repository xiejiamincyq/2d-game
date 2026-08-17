extends Control
class_name GameHUD

signal pause_requested
signal bgm_volume_changed(value: float)
signal bgm_mute_changed(muted: bool)

const DEFAULT_GRID_TOP_MARGIN := 12

var grid_margin: MarginContainer
var grid: GridContainer
var health_bar: ProgressBar
var health_value_label: Label
var shield_value_label: Label
var coin_value_label: Label
var wave_label: Label
var level_label: Label
var stats_label: Label
var combo_panel: PanelContainer
var combo_label: Label
var overdrive_panel: PanelContainer
var overdrive_label: Label
var overdrive_bar: ProgressBar
var pause_button: Button
var bgm_toggle_button: Button
var bgm_volume_slider: HSlider
var toast_overlay: PanelContainer
var toast_label: Label
var toast_tween: Tween
var collection_panel: PanelContainer
var collection_label: Label
var collection_bar: ProgressBar
var layout_viewport_size := Vector2(1280, 720)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud()

func _build_hud() -> void:
	grid_margin = MarginContainer.new()
	grid_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_margin.add_theme_constant_override("margin_left", 14)
	grid_margin.add_theme_constant_override("margin_top", DEFAULT_GRID_TOP_MARGIN)
	grid_margin.add_theme_constant_override("margin_right", 14)
	grid_margin.add_theme_constant_override("margin_bottom", 12)
	grid_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid_margin)

	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid_margin.add_child(grid)

	var health_box := _make_card()
	health_value_label = _make_label("100 / 100")
	health_bar = _make_bar(Color(1.0, 0.28, 0.18))
	shield_value_label = _make_label("护盾 0 / 60")
	health_box.add_child(_make_title("机体状态"))
	health_box.add_child(health_bar)
	health_box.add_child(health_value_label)
	health_box.add_child(shield_value_label)
	grid.add_child(health_box.get_parent())

	var progression_box := _make_card()
	level_label = _make_title("等级  火力:1  机动:1  工程:1")
	coin_value_label = _make_label("金币 0")
	progression_box.add_child(level_label)
	progression_box.add_child(coin_value_label)
	progression_box.add_child(_make_label("清场后免费升级"))
	grid.add_child(progression_box.get_parent())

	var wave_box := _make_card()
	wave_label = _make_title("波次 1 / 8")
	stats_label = _make_label("击杀 0    用时 00:00")
	wave_box.add_child(wave_label)
	wave_box.add_child(stats_label)
	grid.add_child(wave_box.get_parent())

	var controls_box := _make_card()
	var audio_row := HBoxContainer.new()
	bgm_toggle_button = Button.new()
	bgm_toggle_button.text = "音乐"
	bgm_toggle_button.toggle_mode = true
	bgm_toggle_button.toggled.connect(func(muted: bool) -> void: bgm_mute_changed.emit(muted))
	audio_row.add_child(bgm_toggle_button)
	bgm_volume_slider = HSlider.new()
	bgm_volume_slider.min_value = 0.0
	bgm_volume_slider.max_value = 100.0
	bgm_volume_slider.value = 65.0
	bgm_volume_slider.custom_minimum_size.x = 100.0
	bgm_volume_slider.value_changed.connect(func(value: float) -> void: bgm_volume_changed.emit(value / 100.0))
	audio_row.add_child(bgm_volume_slider)
	pause_button = Button.new()
	pause_button.text = "暂停"
	pause_button.custom_minimum_size = Vector2(120, 44)
	pause_button.focus_mode = Control.FOCUS_ALL
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	controls_box.add_child(audio_row)
	controls_box.add_child(pause_button)
	grid.add_child(controls_box.get_parent())

	combo_panel = PanelContainer.new()
	combo_panel.visible = false
	combo_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	combo_panel.position = Vector2(-80, 130)
	combo_panel.custom_minimum_size = Vector2(160, 44)
	combo_label = _make_title("连杀 x2")
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_panel.add_child(combo_label)
	add_child(combo_panel)
	overdrive_panel = PanelContainer.new()
	overdrive_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overdrive_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	overdrive_panel.position = Vector2(-155, -62)
	overdrive_panel.custom_minimum_size = Vector2(310, 44)
	var overdrive_style := StyleBoxFlat.new()
	overdrive_style.bg_color = Color(0.012, 0.028, 0.044, 0.94)
	overdrive_style.border_color = Color(0.20, 1.0, 0.95, 0.62)
	overdrive_style.set_border_width_all(1)
	overdrive_style.set_corner_radius_all(4)
	overdrive_style.set_content_margin_all(8)
	overdrive_panel.add_theme_stylebox_override("panel", overdrive_style)
	var overdrive_row := HBoxContainer.new()
	overdrive_row.add_theme_constant_override("separation", 10)
	overdrive_label = _make_label("超载 0%")
	overdrive_label.custom_minimum_size.x = 76.0
	overdrive_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overdrive_label.add_theme_color_override("font_color", Color("9fffee"))
	overdrive_row.add_child(overdrive_label)
	overdrive_bar = _make_bar(Color("33fff2"))
	overdrive_bar.max_value = 100.0
	overdrive_bar.value = 0.0
	overdrive_bar.custom_minimum_size = Vector2(196, 10)
	overdrive_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overdrive_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	overdrive_row.add_child(overdrive_bar)
	overdrive_panel.add_child(overdrive_row)
	add_child(overdrive_panel)

	collection_panel = PanelContainer.new()
	collection_panel.visible = false
	collection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	collection_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	collection_panel.position = Vector2(-190, -118)
	collection_panel.custom_minimum_size = Vector2(380, 58)
	var collection_box := VBoxContainer.new()
	collection_box.add_theme_constant_override("separation", 5)
	collection_label = _make_title("倒计时：5.0s")
	collection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collection_bar = _make_bar(Color("33fff2"))
	collection_bar.custom_minimum_size = Vector2(350, 8)
	collection_box.add_child(collection_label)
	collection_box.add_child(collection_bar)
	collection_panel.add_child(collection_box)
	add_child(collection_panel)

	toast_overlay = PanelContainer.new()
	toast_overlay.visible = false
	toast_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_overlay.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_overlay.position = Vector2(-170, 82)
	toast_overlay.custom_minimum_size = Vector2(340, 52)
	toast_label = _make_title("")
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_overlay.add_child(toast_label)
	add_child(toast_overlay)

func _make_card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(210, 112)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.028, 0.044, 0.94)
	style.border_color = Color(0.2, 1.0, 0.95, 0.68)
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	return box

func _make_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.82, 1.0, 1.0))
	return label

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	return label

func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.005, 0.015, 0.024, 0.94)
	background.border_color = Color(0.20, 1.0, 0.95, 0.24)
	background.set_border_width_all(1)
	background.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	return bar

func apply_viewport_size(viewport_size: Vector2) -> void:
	layout_viewport_size = viewport_size
	grid.columns = 2 if viewport_size.x < 900.0 else 4
	for child in grid.get_children():
		child.custom_minimum_size.x = 190.0 if grid.columns == 2 else 210.0

func get_required_size() -> Vector2:
	var minimum := grid.get_combined_minimum_size() + Vector2(28, 24)
	return Vector2(minf(minimum.x, layout_viewport_size.x), minf(minimum.y, layout_viewport_size.y))

func set_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_value_label.text = "%d / %d" % [int(ceil(current)), int(maximum)]

func set_shield(value: float, maximum: float) -> void:
	shield_value_label.text = "护盾 %d / %d" % [int(ceil(value)), int(maximum)]

func set_progression_state(state: Dictionary) -> void:
	var levels: Dictionary = state.get("family_levels", {})
	coin_value_label.text = "金币 %d" % int(state.get("coins", 0))
	level_label.text = "等级  火力:%d  机动:%d  工程:%d" % [
		int(levels.get("ballistics", 1)),
		int(levels.get("mobility", 1)),
		int(levels.get("automation", 1)),
	]

func set_wave(index: int, total: int, remaining: int) -> void:
	wave_label.text = "波次 %d / %d    剩余 %d" % [index, total, remaining]

func set_run_stats(kills: int, elapsed_seconds: float) -> void:
	stats_label.text = "击杀 %d    用时 %02d:%02d" % [kills, int(elapsed_seconds) / 60, int(elapsed_seconds) % 60]

func set_combo(count: int) -> void:
	combo_panel.visible = count > 1
	combo_label.text = "连杀 x%d" % count
	combo_label.add_theme_color_override("font_color", Color(0.86, 1.0, 1.0))

func clear_combo() -> void:
	combo_panel.visible = false

func set_overdrive(active: bool, remaining: float = 0.0) -> void:
	if not active:
		return
	combo_panel.visible = true
	combo_label.text = "超载 %.1fs  无敌 · 全武器强化" % maxf(0.0, remaining)
	combo_label.add_theme_color_override("font_color", Color("ff571f"))

func set_overdrive_charge(value: float, active: bool) -> void:
	var clamped_value := clampf(value, 0.0, 100.0)
	var overdrive_color := Color("b45cff") if active else Color("33fff2")
	overdrive_bar.value = clamped_value
	_set_bar_fill_color(overdrive_bar, overdrive_color)
	overdrive_label.text = "超载运行" if active else "超载 %d%%" % int(round(clamped_value))
	overdrive_label.add_theme_color_override("font_color", Color("d9a8ff") if active else Color("9fffee"))
	var panel_style := overdrive_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style != null:
		panel_style.border_color = Color(0.71, 0.36, 1.0, 0.85) if active else Color(0.20, 1.0, 0.95, 0.62)

func _set_bar_fill_color(bar: ProgressBar, color: Color) -> void:
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = color

func set_collection_window(remaining: float, duration: float) -> void:
	var safe_duration := maxf(duration, 0.01)
	collection_bar.max_value = safe_duration
	collection_bar.value = clampf(remaining, 0.0, safe_duration)
	collection_label.text = "倒计时：%.1fs" % maxf(0.0, remaining)
	collection_panel.visible = remaining > 0.0
	collection_panel.modulate.a = clampf(remaining / 0.35, 0.0, 1.0)

func show_toast(text: String) -> void:
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	toast_label.text = "模块上线 // " + text
	toast_overlay.visible = true
	toast_overlay.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(1.0)
	toast_tween.tween_property(toast_overlay, "modulate:a", 0.0, 0.25)
	toast_tween.tween_callback(_finish_toast)

func _finish_toast() -> void:
	toast_overlay.visible = false
	toast_overlay.modulate.a = 1.0
