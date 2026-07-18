extends CanvasLayer
class_name GameUI

signal upgrade_selected(choice: Dictionary)
signal start_requested
signal restart_requested
signal pause_requested
signal bgm_volume_changed(value: float)
signal bgm_mute_changed(muted: bool)

const HUDScene = preload("res://scenes/ui/HUD.tscn")
const UpgradeScene = preload("res://scenes/ui/UpgradeScreen.tscn")
const PauseScene = preload("res://scenes/ui/PauseScreen.tscn")
const ResultScene = preload("res://scenes/ui/ResultScreen.tscn")
const CyberTheme = preload("res://themes/CyberTheme.tres")

var root: Control
var hud: Control
var upgrade_screen: Control
var pause_screen: Control
var result_screen: Control
var start_backdrop: ColorRect
var start_panel: PanelContainer
var start_button: Button

# Compatibility references used by Main and focused tests.
var hud_root: Control
var upgrade_overlay: Control
var upgrade_panel: PanelContainer
var pause_overlay: Control
var pause_panel: PanelContainer
var result_overlay: Control
var result_panel: PanelContainer
var pause_button: Button
var health_bar: ProgressBar
var health_value_label: Label
var shield_value_label: Label
var coin_value_label: Label
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = CyberTheme
	add_child(root)

	hud = HUDScene.instantiate()
	upgrade_screen = UpgradeScene.instantiate()
	pause_screen = PauseScene.instantiate()
	result_screen = ResultScene.instantiate()
	root.add_child(hud)
	root.add_child(upgrade_screen)
	root.add_child(pause_screen)
	root.add_child(result_screen)
	_build_start_screen()
	_connect_components()
	_bind_compatibility_references()
	apply_viewport_size(get_viewport().get_visible_rect().size)
	get_viewport().size_changed.connect(func() -> void: apply_viewport_size(get_viewport().get_visible_rect().size))
	show_start_screen()

func _build_start_screen() -> void:
	start_backdrop = ColorRect.new()
	start_backdrop.color = Color(0.015, 0.025, 0.04, 0.97)
	start_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(start_backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_backdrop.add_child(center)
	start_panel = PanelContainer.new()
	start_panel.custom_minimum_size = Vector2(520, 310)
	center.add_child(start_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	start_panel.add_child(box)
	var title := Label.new()
	title.text = "废土清剿协议"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "移动、射击、冲刺，在八个波次中存活"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	start_button = Button.new()
	start_button.text = "开始清剿"
	start_button.custom_minimum_size = Vector2(220, 52)
	start_button.focus_mode = Control.FOCUS_ALL
	start_button.pressed.connect(func() -> void: start_requested.emit())
	box.add_child(start_button)

func _connect_components() -> void:
	hud.pause_requested.connect(func() -> void: pause_requested.emit())
	hud.bgm_volume_changed.connect(func(value: float) -> void: bgm_volume_changed.emit(value))
	hud.bgm_mute_changed.connect(func(muted: bool) -> void: bgm_mute_changed.emit(muted))
	upgrade_screen.choice_selected.connect(func(choice: Dictionary) -> void: upgrade_selected.emit(choice))
	pause_screen.resume_requested.connect(func() -> void: pause_requested.emit())
	result_screen.restart_requested.connect(func() -> void: restart_requested.emit())

func _bind_compatibility_references() -> void:
	hud_root = hud
	upgrade_overlay = upgrade_screen
	upgrade_panel = upgrade_screen.panel
	pause_overlay = pause_screen
	pause_panel = pause_screen.panel
	result_overlay = result_screen
	result_panel = result_screen.panel
	pause_button = hud.pause_button
	health_bar = hud.health_bar
	health_value_label = hud.health_value_label
	shield_value_label = hud.shield_value_label
	coin_value_label = hud.coin_value_label
	wave_label = hud.wave_label
	level_label = hud.level_label
	stats_label = hud.stats_label
	toast_panel = hud.toast_overlay
	toast_label = hud.toast_label
	result_label = result_screen.result_label
	combo_panel = hud.combo_panel
	combo_label = hud.combo_label
	bgm_toggle_button = hud.bgm_toggle_button
	bgm_volume_slider = hud.bgm_volume_slider
	buttons = upgrade_screen.buttons

func _unhandled_input(event: InputEvent) -> void:
	if start_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_SPACE]:
			start_requested.emit()
			return
	if result_screen.visible and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		restart_requested.emit()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if not start_panel.visible and not upgrade_screen.visible and not result_screen.visible:
			pause_requested.emit()
			return
	if not upgrade_screen.visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_3:
		var index: int = event.keycode - KEY_1
		if index < buttons.size() and buttons[index].visible:
			buttons[index].pressed.emit()

func apply_viewport_size(viewport_size: Vector2) -> void:
	hud.apply_viewport_size(viewport_size)
	upgrade_screen.apply_viewport_size(viewport_size)
	pause_screen.apply_viewport_size(viewport_size)
	result_screen.apply_viewport_size(viewport_size)
	start_panel.custom_minimum_size = Vector2(minf(520.0, viewport_size.x - 40.0), minf(310.0, viewport_size.y - 40.0))

func is_upgrade_open() -> bool:
	return upgrade_screen.visible

func set_health(current: float, maximum: float) -> void:
	hud.set_health(current, maximum)

func set_shield(value: float, maximum: float) -> void:
	hud.set_shield(value, maximum)

func set_progression(coins: int, level: int) -> void:
	hud.set_progression(coins, level)

func set_wave(index: int, total: int, remaining: int) -> void:
	hud.set_wave(index, total, remaining)

func set_run_stats(kills: int, elapsed_seconds: float) -> void:
	hud.set_run_stats(kills, elapsed_seconds)

func set_combo(count: int) -> void:
	hud.set_combo(count)

func clear_combo() -> void:
	hud.clear_combo()

func show_toast(text: String) -> void:
	hud.show_toast(text)

func show_upgrades(choices: Array[Dictionary]) -> void:
	upgrade_screen.show_choices(choices)

func hide_upgrades() -> void:
	upgrade_screen.hide_screen()
	if pause_button != null:
		pause_button.grab_focus()

func show_manual_pause() -> void:
	pause_screen.show_screen()
	pause_button.text = "继续"

func hide_manual_pause() -> void:
	pause_screen.hide_screen()
	pause_button.text = "暂停"
	if pause_button != null:
		pause_button.grab_focus()

func show_result(victory: bool, wave_text: String, kills: int, elapsed_seconds: float, level: int) -> void:
	result_screen.show_result(victory, wave_text, kills, elapsed_seconds, level)

func hide_result() -> void:
	result_screen.hide_screen()

func show_start_screen() -> void:
	hud.visible = false
	start_backdrop.visible = true
	start_panel.visible = true
	start_button.grab_focus()

func hide_start_screen() -> void:
	hud.visible = true
	start_backdrop.visible = false
	start_panel.visible = false
