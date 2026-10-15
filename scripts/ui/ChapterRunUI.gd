extends "res://scripts/ui/GameUI.gd"
## Chapter-only UI; the old demo's wave/pause/result contracts remain unchanged.

signal proceed_requested
signal route_requested(route: StringName)
signal return_requested
signal resume_requested
signal retry_save_requested
signal replay_requested
signal next_chapter_requested
signal carry_choice_requested(card_id: String)

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
var next_button: Button
var carry_selector: OptionButton
var carry_hint: Label
var risk_name := "根巢"

func _ready() -> void:
	super._ready()
	root.theme = PaperTheme.create()
	settlement_screen.enable_chapter_scroll_layout()
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
	carry_selector = OptionButton.new()
	carry_selector.custom_minimum_size.y = 46
	carry_selector.clip_text = true
	column.add_child(carry_selector)
	carry_hint = Label.new()
	carry_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(carry_hint)
	carry_selector.item_selected.connect(_select_carry)
	next_button = _action(column, "进入下一关", func() -> void:
		if next_button.visible and not next_button.disabled:
			next_chapter_requested.emit()
	)
	proceed_button = _action(column, "进入遭遇", func() -> void: proceed_requested.emit())
	supply_button = _action(column, "保守补给：12金币 · 恢复最多20生命", func() -> void: route_requested.emit(&"supply"))
	risk_button = _action(column, "高风险%s：额外战斗 · 免费构筑 · 完成后35金币" % risk_name, func() -> void: route_requested.emit(&"risk"))
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
	flow_description.custom_minimum_size.y = 100
	next_button.hide()
	carry_selector.hide()
	carry_hint.hide()
	return_button.disabled = false
	replay_button.disabled = false
	proceed_button.visible = stage in [&"intro", &"boss"]
	proceed_button.disabled = false
	proceed_button.text = "进入遭遇" if stage == &"intro" else "迎战首领"
	supply_button.visible = stage == &"route"
	risk_button.visible = stage == &"route"
	resume_button.visible = stage == &"pause"
	retry_save_button.visible = stage == &"save_error"
	retry_save_button.text = "重试保存通关"
	replay_button.visible = stage in [&"cleared", &"failed"]
	_link_flow_focus()
	(resume_button if stage == &"pause" else return_button).grab_focus()
	set_aim_reticle_visible(false)

func _link_flow_focus() -> void:
	var active: Array[Button] = []
	for button in [carry_selector, next_button, proceed_button, supply_button, risk_button, resume_button, retry_save_button, replay_button, return_button]:
		if button.visible and not button.disabled:
			active.append(button)
	for index in active.size():
		active[index].focus_next = active[(index + 1) % active.size()].get_path()
		active[index].focus_previous = active[(index - 1) % active.size()].get_path()

func present_chapter_clear(chapter: int, choices: Array[Dictionary], balance: int, reward_already_claimed: bool) -> void:
	present("第%d关通关" % chapter, "金币 %d · 选择一项已获得能力继承一个等级，终极技能不可继承。" % balance, &"cleared")
	flow_description.custom_minimum_size.y = 50
	var pending := not reward_already_claimed and not choices.is_empty()
	next_button.visible = chapter >= 1 and chapter < 6
	next_button.disabled = pending
	replay_button.text = "重玩本关卡"
	replay_button.disabled = pending
	return_button.disabled = pending
	carry_selector.visible = pending
	carry_hint.visible = pending
	carry_selector.clear()
	carry_selector.add_item("选择要继承的能力")
	carry_selector.set_item_metadata(0, {})
	for card in choices:
		carry_selector.add_item(String(card.label))
		carry_selector.set_item_metadata(carry_selector.item_count - 1, card.duplicate(true))
	carry_hint.text = "每轮每关仅领取一次。先继承核心模块，后续才能继承其附属能力。"
	if reward_already_claimed:
		flow_description.text = "金币 %d · 本轮本关继承奖励已领取，重玩不会重复叠加。" % balance
	elif not pending:
		flow_description.text = "金币 %d · 没有可继承的普通能力，可继续旅程。" % balance
	if chapter==6:
		flow_description.text+="\n回帐篷后继续进入下一轮第1关；重玩仍在当前轮第6关。"
	_link_flow_focus()
	(carry_selector if pending else return_button).grab_focus()

func _select_carry(index: int) -> void:
	var valid := carry_selector.visible and index > 0 and index < carry_selector.item_count
	if valid:
		var card: Dictionary = carry_selector.get_item_metadata(index)
		carry_hint.text = String(card.get("description", ""))
		carry_choice_requested.emit(String(card.get("id", "")))

func hide_flow() -> void:
	flow_root.hide()
	hide_settlement()
	set_aim_reticle_visible(true)

func set_encounter_reward(state: Dictionary, encounter_name: String) -> void:
	set_settlement_state(state)
	var finale: bool = state.get("stage_kind", "") == "boss_prep"
	settlement_screen.title_label.text = "首领前整备 / 最后一次构筑" if finale else "遭遇战利品 / 构筑升级"
	settlement_screen.wave_label.text = "第%d次遭遇后 · 首领前整备" % int(state.get("wave", 0)) if finale else encounter_name
	settlement_screen.close_button.text = "完成整备并迎战首领" if finale else "完成整备并继续探索"
	if finale:
		settlement_screen.hint_label.text = "最后一次免费选择：流派达3级且必需模块齐备时可选进化" if not state.get("reward_claimed", false) else "可用金币追加购买；完成整备后迎战首领，本局最多一项进化"
	else:
		settlement_screen.hint_label.text = "免费选择提升对应流派等级；连续专注两次并备齐核心，可在首领前选择进化" if not state.get("reward_claimed", false) else "可用金币追加购买，然后继续探索；购买不提升流派等级"

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
