extends "res://scripts/ui/GameUI.gd"
## Chapter-only UI; the old demo's wave/pause/result contracts remain unchanged.

signal proceed_requested
signal route_requested(route: StringName)
signal return_requested
signal resume_requested
signal retry_save_requested
signal replay_requested

const PaperTheme = preload("res://scripts/ui/CampaignMenuTheme.gd")
var flow_root: Control
var flow_panel: PanelContainer
var flow_title: Label
var flow_description: Label
var proceed_button: Button
var supply_button: Button
var risk_button: Button
var resume_button: Button
var retry_save_button: Button
var replay_button: Button
var return_button: Button

func _ready() -> void:
	super._ready()
	root.theme = PaperTheme.create()
	hide_start_screen()
	flow_root = Control.new()
	flow_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(flow_root)
	var shade := ColorRect.new()
	shade.color = Color("142520ad")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flow_root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	flow_root.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	flow_panel = PanelContainer.new()
	flow_panel.custom_minimum_size.x = 680
	center.add_child(flow_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	flow_panel.add_child(column)
	flow_title = Label.new()
	flow_title.add_theme_font_size_override("font_size", 28)
	column.add_child(flow_title)
	flow_description = Label.new()
	flow_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow_description.custom_minimum_size = Vector2(600, 100)
	column.add_child(flow_description)
	proceed_button = _action(column, "进入遭遇", func() -> void: proceed_requested.emit())
	supply_button = _action(column, "保守补给：12金币 · 恢复最多20生命", func() -> void: route_requested.emit(&"supply"))
	risk_button = _action(column, "高风险根巢：额外战斗 · 免费构筑 · 完成后35金币", func() -> void: route_requested.emit(&"risk"))
	resume_button = _action(column, "继续战斗", func() -> void: resume_requested.emit())
	retry_save_button = _action(column, "重试保存通关", func() -> void: retry_save_requested.emit())
	replay_button = _action(column, "重新探索（新地图种子）", func() -> void: replay_requested.emit())
	return_button = _action(column, "← 返回帐篷", func() -> void: return_requested.emit())
	apply_viewport_size(get_viewport().get_visible_rect().size)

func _action(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func present(title: String, description: String, stage: StringName) -> void:
	hide_settlement()
	hide_manual_pause()
	hide_result()
	flow_root.show()
	flow_title.text = title
	flow_description.text = description
	proceed_button.visible = stage in [&"intro", &"boss"]
	proceed_button.disabled = false
	proceed_button.text = "进入遭遇" if stage == &"intro" else "迎战过渡首领"
	supply_button.visible = stage == &"route"
	risk_button.visible = stage == &"route"
	resume_button.visible = stage == &"pause"
	retry_save_button.visible = stage == &"save_error"
	replay_button.visible = stage in [&"cleared", &"failed"]
	var active: Array[Button] = []
	for button in [proceed_button, supply_button, risk_button, resume_button, retry_save_button, replay_button, return_button]:
		if button.visible and not button.disabled:
			active.append(button)
	for index in active.size():
		active[index].focus_next = active[(index + 1) % active.size()].get_path()
		active[index].focus_previous = active[(index - 1) % active.size()].get_path()
	(resume_button if stage == &"pause" else return_button).grab_focus()
	set_aim_reticle_visible(false)

func hide_flow() -> void:
	flow_root.hide()
	hide_settlement()
	set_aim_reticle_visible(true)

func set_encounter_reward(state: Dictionary, encounter_name: String) -> void:
	set_settlement_state(state)
	settlement_screen.title_label.text = "遭遇战利品 / 构筑升级"
	settlement_screen.wave_label.text = encounter_name
	settlement_screen.close_button.text = "完成整备并继续探索"
	settlement_screen.hint_label.text = "先免费领取一张奖励" if not state.get("reward_claimed", false) else "可用金币追加购买，然后继续探索"

func apply_viewport_size(extent: Vector2) -> void:
	super.apply_viewport_size(extent)
	if flow_panel != null:
		flow_panel.custom_minimum_size.x = minf(680, extent.x - 48)
		flow_description.custom_minimum_size.x = minf(600, extent.x - 80)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or (event.keycode == KEY_SPACE and flow_root.visible and resume_button.visible)):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if flow_root.visible:
		return
	super._unhandled_input(event)
