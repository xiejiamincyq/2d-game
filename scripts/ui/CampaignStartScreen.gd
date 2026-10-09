extends Control
## UI-only request boundary. Selection never writes progress or starts a director.

signal start_requested
signal continue_requested
signal chapter_requested(chapter: int)
signal quit_requested
signal bgm_volume_changed(value: float)
signal bgm_mute_changed(muted: bool)

const Catalog = preload("res://scripts/systems/ChapterCatalog.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const MenuTheme = preload("res://scripts/ui/CampaignMenuTheme.gd")
const Backdrop = preload("res://scripts/ui/CampaignBackdrop.gd")
const RegionIcon = preload("res://scripts/ui/CampaignRegionIcon.gd")
enum Page { COVER, CHAPTERS, SETTINGS }

var page := Page.COVER
var selected_chapter := 1
var start_button: Button
var continue_button: Button
var regions_button: Button
var settings_button: Button
var quit_button: Button
var back_button: Button
var launch_button: Button
var cover_panel: PanelContainer
var chapter_buttons: Array[Button] = []
var detail_label: Label
var storage_label: Label
var volume_slider: HSlider
var mute_button: CheckButton
var _progress = Progress.new()
var _ready_chapters: Array[int] = []
var _storage_notice := ""
var _margin: MarginContainer
var _header: VBoxContainer
var _title: Label
var _subtitle: Label
var _kicker: Label
var _regions_panel: PanelContainer
var _settings_panel: PanelContainer
var _back_row: HBoxContainer
var _progress_label: Label
var _grid: GridContainer
var _footer: Label

func _ready() -> void:
	name = "CampaignStartScreen"
	mouse_filter = MOUSE_FILTER_STOP
	theme = MenuTheme.create()
	var background := Backdrop.new()
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_margin.add_child(column)
	_header = VBoxContainer.new()
	_header.add_theme_constant_override("separation", 5)
	column.add_child(_header)
	_kicker = _label("巡界档案 / FIELD JOURNAL", 17, Color("c1caa8"))
	_title = _label("废土清剿协议", 38, Color("f3eddc"))
	_subtitle = _label("带上火种，穿过雾与废墟。", 18, Color("c1caa8"))
	for label in [_kicker, _title, _subtitle]:
		_header.add_child(label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(body)
	cover_panel = PanelContainer.new()
	cover_panel.custom_minimum_size.x = 380
	cover_panel.size_flags_vertical = SIZE_SHRINK_BEGIN
	body.add_child(cover_panel)
	var actions := _box(cover_panel)
	actions.add_child(_label("整备帐篷", 22))
	start_button = _button(actions, "进入当前试玩", func() -> void: start_requested.emit())
	continue_button = _button(actions, "继续上次试玩", _continue)
	regions_button = _button(actions, "六区档案", func() -> void: show_page(Page.CHAPTERS))
	settings_button = _button(actions, "声音设置", func() -> void: show_page(Page.SETTINGS))
	quit_button = _button(actions, "退出游戏", func() -> void: quit_requested.emit())
	var notice := _label("试玩仍为波次模式，不计入六关解锁。", 16)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A minimum width keeps wrapping labels from collapsing their parent panel.
	notice.custom_minimum_size.x = 326
	actions.add_child(notice)
	_regions_panel = PanelContainer.new()
	_regions_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_regions_panel.size_flags_vertical = SIZE_SHRINK_BEGIN
	body.add_child(_regions_panel)
	var regions := _box(_regions_panel)
	_back_row = HBoxContainer.new()
	regions.add_child(_back_row)
	back_button = _button(_back_row, "← 返回帐篷", func() -> void: show_page(Page.COVER))
	_progress_label = _label("", 17)
	_progress_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_back_row.add_child(_progress_label)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 10)
	regions.add_child(_grid)
	for chapter in range(1, 7):
		var button := _button(_grid, "", select_chapter.bind(chapter))
		button.name = "Chapter%d" % chapter
		button.custom_minimum_size = Vector2(218, 70)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		var icon := RegionIcon.new()
		icon.chapter = chapter
		icon.size = Vector2(44, 44)
		icon.position = Vector2(10, 13)
		button.add_child(icon)
		chapter_buttons.append(button)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 18)
	regions.add_child(detail_row)
	detail_label = _label("", 17)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.size_flags_horizontal = SIZE_EXPAND_FILL
	detail_label.custom_minimum_size = Vector2(400, 100)
	detail_row.add_child(detail_label)
	launch_button = _button(detail_row, "区域制作中", _launch)
	launch_button.size_flags_vertical = SIZE_SHRINK_CENTER
	launch_button.custom_minimum_size.x = 174
	storage_label = _label("", 16, Color("874629"))
	storage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regions.add_child(storage_label)
	_settings_panel = PanelContainer.new()
	_settings_panel.custom_minimum_size.x = 380
	_settings_panel.size_flags_vertical = SIZE_SHRINK_BEGIN
	body.add_child(_settings_panel)
	var settings := _box(_settings_panel)
	settings.add_child(_label("背景音乐", 22))
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 1
	volume_slider.step = 0.01
	volume_slider.custom_minimum_size = Vector2(326, 44)
	volume_slider.focus_mode = FOCUS_ALL
	volume_slider.value_changed.connect(func(value: float) -> void: bgm_volume_changed.emit(value))
	settings.add_child(volume_slider)
	mute_button = CheckButton.new()
	mute_button.text = "静音背景音乐"
	mute_button.custom_minimum_size.y = 44
	mute_button.toggled.connect(func(value: bool) -> void: bgm_mute_changed.emit(value))
	settings.add_child(mute_button)
	settings.add_child(_label("音量与游戏内音乐设置同步。", 16))
	_footer = _label("WASD 移动 · 鼠标射击 · 空格暂停    |    原生纸偶改造进行中", 16, Color("c1caa8"))
	column.add_child(_footer)
	set_continue_available(false)
	set_campaign(_progress)
	apply_viewport_size(size)
	show_page(Page.COVER)

func _box(parent: Node) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.add_theme_constant_override("separation", 8)
	parent.add_child(result)
	return result

func _label(text: String, font_size: int, color := MenuTheme.INK) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

func _button(parent: Node, text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 44
	result.focus_mode = FOCUS_ALL
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func set_continue_available(available: bool) -> void:
	continue_button.visible = available
	continue_button.disabled = not available
	_link_focus()

func set_bgm_state(volume: float, muted: bool) -> void:
	volume_slider.set_value_no_signal(clampf(volume, 0, 1))
	mute_button.set_pressed_no_signal(muted)

## Copies the progression model. Readiness is explicit and defaults to none.
## A nonempty storage notice blocks future chapter launch, never the old demo.
func set_campaign(progress: CampaignProgress, ready_chapters: Array[int] = [], storage_notice := "") -> void:
	_progress.restore_state(progress.to_state())
	_ready_chapters.clear()
	for chapter in ready_chapters:
		if chapter >= 1 and chapter <= 6 and chapter not in _ready_chapters:
			_ready_chapters.append(chapter)
	_storage_notice = storage_notice
	storage_label.text = storage_notice
	storage_label.visible = not storage_notice.is_empty()
	_progress_label.text = "通关 %d / 6 · 解锁至第 %d 区" % [_progress.to_state().cleared_chapters.size(), _progress.get_highest_unlocked_chapter()]
	for chapter in range(1, 7):
		var data: Dictionary = Catalog.get_chapter(chapter)
		var state := "已通关" if _progress.has_cleared(chapter) else ("已解锁" if _progress.is_unlocked(chapter) else "锁定")
		if chapter not in _ready_chapters:
			state += " · 制作中"
		chapter_buttons[chapter - 1].text = "%02d  %s\n%s" % [chapter, data.name, state]
	select_chapter(selected_chapter)

func select_chapter(chapter: int) -> void:
	var data: Dictionary = Catalog.get_chapter(chapter)
	if data.is_empty():
		return
	selected_chapter = chapter
	detail_label.text = "%02d / %s\n%s\n区域首领：%s" % [chapter, data.name, data.description, data.boss_name]
	launch_button.disabled = not _can_launch()
	launch_button.text = "进入区域" if _can_launch() else ("击败前区首领后解锁" if not _progress.is_unlocked(chapter) else ("请先处理存档异常" if not _storage_notice.is_empty() else "区域制作中"))
	_link_focus()

func _can_launch() -> bool:
	return _storage_notice.is_empty() and _progress.is_unlocked(selected_chapter) and selected_chapter in _ready_chapters

func _launch() -> void:
	if _can_launch():
		chapter_requested.emit(selected_chapter)

func _continue() -> void:
	if continue_button.visible and not continue_button.disabled:
		continue_requested.emit()

func show_page(next: Page) -> void:
	page = next
	cover_panel.visible = page == Page.COVER
	_regions_panel.visible = page == Page.CHAPTERS
	_settings_panel.visible = page == Page.SETTINGS
	_title.text = ["废土清剿协议", "六区档案", "声音设置"][page]
	_kicker.visible = page == Page.COVER
	_subtitle.visible = page == Page.COVER
	# One common Back target for keyboard and integration callers.
	if page == Page.SETTINGS:
		back_button.reparent(_settings_panel.get_child(0))
		_settings_panel.get_child(0).move_child(back_button, 0)
	elif back_button.get_parent() != _back_row:
		back_button.reparent(_back_row)
		_back_row.move_child(back_button, 0)
	_link_focus()
	(start_button if page == Page.COVER else back_button).grab_focus()

func apply_viewport_size(extent: Vector2) -> void:
	var padding := 24 if extent.x < 1100 else 48
	for side in ["left", "top", "right", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, padding)
	_title.add_theme_font_size_override("font_size", 32 if extent.x < 1100 else 38)
	_footer.add_theme_font_size_override("font_size", 14 if extent.x < 1100 else 16)

func get_active_controls() -> Array[Control]:
	var result: Array[Control] = [_title, _footer]
	match page:
		Page.COVER:
			result.append_array([cover_panel, start_button, regions_button, settings_button, quit_button])
			if continue_button.visible:
				result.append(continue_button)
		Page.CHAPTERS:
			result.append_array([_regions_panel, back_button, _progress_label, detail_label, launch_button])
			result.append_array(chapter_buttons)
		Page.SETTINGS:
			result.append_array([_settings_panel, back_button, volume_slider, mute_button])
	return result

func _link_focus() -> void:
	var controls: Array[Control] = []
	match page:
		Page.COVER:
			controls = [start_button]
			if continue_button.visible:
				controls.append(continue_button)
			controls.append_array([regions_button, settings_button, quit_button])
		Page.CHAPTERS:
			controls = [back_button]
			controls.append_array(chapter_buttons)
			if not launch_button.disabled:
				controls.append(launch_button)
		Page.SETTINGS:
			controls = [back_button, volume_slider, mute_button]
	for i in controls.size():
		var before := controls[(i - 1 + controls.size()) % controls.size()]
		var after := controls[(i + 1) % controls.size()]
		controls[i].focus_previous = controls[i].get_path_to(before)
		controls[i].focus_next = controls[i].get_path_to(after)
		controls[i].focus_neighbor_top = controls[i].focus_previous
		controls[i].focus_neighbor_bottom = controls[i].focus_next

func _unhandled_input(event: InputEvent) -> void:
	if visible and page != Page.COVER and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		show_page(Page.COVER)
		get_viewport().set_input_as_handled()
