extends CanvasLayer
class_name GameUI

signal settlement_offer_selected(offer: Dictionary)
signal settlement_close_requested
signal wave_banner_finished(context: StringName)
signal start_requested
signal restart_requested
signal pause_requested
signal bgm_volume_changed(value: float)
signal bgm_mute_changed(muted: bool)

const HUDScene = preload("res://scenes/ui/HUD.tscn")
const PauseScene = preload("res://scenes/ui/PauseScreen.tscn")
const SettlementScene = preload("res://scenes/ui/SettlementScreen.tscn")
const ResultScene = preload("res://scenes/ui/ResultScreen.tscn")
const WaveBannerScene = preload("res://scenes/ui/WaveBanner.tscn")
const CyberTheme = preload("res://themes/CyberTheme.tres")

var root: Control
var hud: Control
var pause_screen: Control
var settlement_screen: Control
var result_screen: Control
var wave_banner: Control
var start_backdrop: ColorRect
var start_panel: PanelContainer
var start_button: Button

# Compatibility references used by Main and focused tests.
var hud_root: Control
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = CyberTheme
	add_child(root)

	hud = HUDScene.instantiate()
	pause_screen = PauseScene.instantiate()
	settlement_screen = SettlementScene.instantiate()
	result_screen = ResultScene.instantiate()
	wave_banner = WaveBannerScene.instantiate()
	root.add_child(hud)
	root.add_child(pause_screen)
	root.add_child(settlement_screen)
	root.add_child(result_screen)
	root.add_child(wave_banner)
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
	pause_screen.resume_requested.connect(func() -> void: pause_requested.emit())
	settlement_screen.offer_selected.connect(func(offer: Dictionary) -> void: settlement_offer_selected.emit(offer))
	settlement_screen.close_requested.connect(func() -> void: settlement_close_requested.emit())
	wave_banner.finished.connect(func(context: StringName) -> void: wave_banner_finished.emit(context))
	result_screen.restart_requested.connect(func() -> void: restart_requested.emit())

func _bind_compatibility_references() -> void:
	hud_root = hud
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

func _unhandled_input(event: InputEvent) -> void:
	if start_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_SPACE]:
			start_requested.emit()
			return
	if result_screen.visible and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		restart_requested.emit()
		return
	if settlement_screen.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var settlement_index: int = event.keycode - KEY_1
			if settlement_index < settlement_screen.offer_buttons.size():
				var settlement_button: Button = settlement_screen.offer_buttons[settlement_index]
				if settlement_button.visible and not settlement_button.disabled:
					settlement_button.pressed.emit()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if not start_panel.visible and not settlement_screen.visible and not result_screen.visible:
			pause_requested.emit()
			return

func apply_viewport_size(viewport_size: Vector2) -> void:
	hud.apply_viewport_size(viewport_size)
	pause_screen.apply_viewport_size(viewport_size)
	settlement_screen.apply_viewport_size(viewport_size)
	result_screen.apply_viewport_size(viewport_size)
	wave_banner.apply_viewport_size(viewport_size)
	start_panel.custom_minimum_size = Vector2(minf(520.0, viewport_size.x - 40.0), minf(310.0, viewport_size.y - 40.0))

func set_health(current: float, maximum: float) -> void:
	hud.set_health(current, maximum)

func set_shield(value: float, maximum: float) -> void:
	hud.set_shield(value, maximum)

func set_progression_state(state: Dictionary) -> void:
	hud.set_progression_state(state)

func set_settlement_state(state: Dictionary) -> void:
	settlement_screen.set_state(state)

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

func show_settlement() -> void:
	settlement_screen.show_screen()

func hide_settlement() -> void:
	settlement_screen.hide_screen()

func show_wave_banner(text: String, context: StringName, duration: float = 1.1) -> void:
	wave_banner.show_message(text, context, duration)

func show_manual_pause() -> void:
	pause_screen.show_screen()
	pause_button.text = "继续"

func hide_manual_pause() -> void:
	pause_screen.hide_screen()
	pause_button.text = "暂停"
	if pause_button != null:
		pause_button.grab_focus()

func show_result(victory: bool, wave_text: String, kills: int, elapsed_seconds: float, progression_state: Dictionary) -> void:
	result_screen.show_result(victory, wave_text, kills, elapsed_seconds, progression_state)

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
