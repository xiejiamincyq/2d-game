extends SceneTree

var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignMenuTest " + message)

func _initialize() -> void:
	var path := "res://scripts/ui/CampaignStartScreen.gd"
	check(ResourceLoader.exists(path, "GDScript"), "new start/region/settings component is absent")
	if failures > 0:
		quit(1)
		return
	var menu_script = load(path)
	check(menu_script != null and menu_script.can_instantiate(), "menu script failed to parse")
	if failures > 0:
		quit(1)
		return
	var menu = menu_script.new()
	root.add_child(menu)
	await process_frame
	check(menu.has_signal("legacy_start_requested") and menu.get("legacy_button") != null, "explicit legacy page and request boundary missing")
	if failures:
		menu.queue_free()
		await process_frame
		quit(1)
		return
	var starts := [0]
	var continues := [0]
	var chapters: Array[int] = []
	menu.start_requested.connect(func() -> void: starts[0] += 1)
	menu.continue_requested.connect(func() -> void: continues[0] += 1)
	menu.chapter_requested.connect(func(chapter: int) -> void: chapters.append(chapter))
	check(menu.page == menu.Page.COVER, "initial page is not the cover")
	check(menu.start_button.disabled and menu.regions_button.has_focus(), "unready primary entry pretends playable or traps focus")
	check(not menu.continue_button.visible and menu.continue_button.disabled, "empty snapshot invents Continue")
	menu.start_button.pressed.emit()
	check(starts[0] == 0, "unready primary bypasses policy")
	menu.continue_button.pressed.emit()
	check(continues[0] == 0, "disabled Continue bypasses guard")
	menu.set_continue_available(true)
	menu.continue_button.pressed.emit()
	check(continues[0] == 0, "cover directly continues legacy snapshot")
	menu.legacy_button.pressed.emit()
	check(menu.page == menu.Page.LEGACY and menu.back_button.has_focus(), "legacy page lost Back focus")
	menu.continue_button.pressed.emit()
	check(continues[0] == 1, "explicit legacy page cannot continue valid snapshot")
	var legacy_starts := [0]
	menu.legacy_start_requested.connect(func() -> void: legacy_starts[0] += 1)
	menu.legacy_start_button.pressed.emit()
	check(legacy_starts[0] == 1 and starts[0] == 0, "legacy start is mixed with formal start")
	menu.back_button.pressed.emit()
	var progress = load("res://scripts/systems/CampaignProgress.gd").new()
	var initial: Dictionary = progress.to_state()
	menu.set_campaign(progress)
	menu.regions_button.pressed.emit()
	check(menu.page == menu.Page.CHAPTERS and menu.back_button.has_focus(), "regions lost visible/default Back")
	check(menu.chapter_buttons.size() == 6, "region list is not six independent entries")
	check(menu.chapter_buttons[0].text.contains("制作中"), "unbuilt unlocked chapter pretends playable")
	check(menu.chapter_buttons[1].text.contains("锁定"), "chapter two is not explicitly locked")
	check(menu.launch_button.disabled, "unbuilt chapter starts")
	menu.launch_button.pressed.emit()
	check(chapters.is_empty(), "unbuilt launch signal escaped disabled state")
	menu.chapter_buttons[5].pressed.emit()
	menu.launch_button.disabled = false # hostile/accidental UI mutation must not bypass model
	menu.launch_button.pressed.emit()
	check(chapters.is_empty(), "locked/unbuilt guard trusts only button.disabled")
	check(menu.selected_chapter == 6 and menu.detail_label.text.contains("裂隙观测者"), "locked region cannot be inspected")
	check(progress.to_state() == initial, "preview selection changed permanent unlock")
	var ready_chapters: Array[int] = [1]
	menu.set_campaign(progress, ready_chapters)
	menu.show_page(menu.Page.COVER)
	menu.start_button.pressed.emit()
	check(starts[0] == 1 and menu.start_button.text.contains("开始探索"), "ready primary does not request formal frontier")
	menu.show_page(menu.Page.CHAPTERS)
	menu.select_chapter(1)
	check(not menu.launch_button.disabled, "ready/unlocked frontier cannot launch")
	menu.launch_button.pressed.emit()
	check(chapters == [1], "ready chapter launch emits wrong id/count")
	menu.select_chapter(2)
	check(menu.launch_button.disabled, "ready mask bypasses sequential lock")
	menu.set_campaign(progress, ready_chapters, "存档异常：已保留原文件")
	menu.select_chapter(1)
	menu.launch_button.pressed.emit()
	check(menu.launch_button.disabled and chapters == [1], "storage warning allows chapter write flow")
	check(menu.storage_label.text.contains("存档异常"), "storage failure is hidden")
	menu.show_page(menu.Page.COVER)
	menu.start_button.disabled = false
	menu.start_button.pressed.emit()
	check(starts[0] == 1, "hostile primary button mutation bypasses unsafe storage")
	menu.back_button.pressed.emit()
	check(menu.page == menu.Page.COVER and menu.regions_button.has_focus(), "blocked Back does not restore safe cover focus")
	menu.settings_button.pressed.emit()
	check(menu.page == menu.Page.SETTINGS and menu.back_button.has_focus(), "settings have no low-cost Back")
	var volumes: Array[float] = []
	var mutes: Array[bool] = []
	menu.bgm_volume_changed.connect(func(value: float) -> void: volumes.append(value))
	menu.bgm_mute_changed.connect(func(value: bool) -> void: mutes.append(value))
	menu.set_bgm_state(0.36, true)
	check(volumes.is_empty() and mutes.is_empty(), "reading audio state spuriously writes audio")
	menu.volume_slider.value = 0.62
	menu.mute_button.button_pressed = false
	check(volumes.size() == 1 and is_equal_approx(volumes[0], 0.62), "volume change not forwarded once")
	check(mutes == [false], "mute change not forwarded once")
	var full_progress = load("res://scripts/systems/CampaignProgress.gd").new()
	for chapter in range(1, 7): full_progress.record_boss_defeat(chapter)
	var all_ready: Array[int] = [1, 2, 3, 4, 5, 6]
	menu.set_campaign(full_progress, all_ready)
	menu.show_page(menu.Page.COVER)
	menu.start_button.pressed.emit()
	check(menu.page == menu.Page.CHAPTERS and menu.selected_chapter == 6 and starts[0] == 1, "complete primary invents next run rather than replay selection")
	for extent in [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080)]:
		menu.size = extent
		menu.apply_viewport_size(extent)
		for page in [menu.Page.COVER, menu.Page.CHAPTERS, menu.Page.SETTINGS, menu.Page.LEGACY]:
			menu.show_page(page)
			await process_frame
			await process_frame
			for target in menu.get_active_controls():
				var rect: Rect2 = target.get_global_rect()
				check(Rect2(Vector2.ZERO, extent).encloses(rect), "visible control %s exceeds %s page %s: %s" % [target.name, extent, page, rect])
				if target is Button:
					check(target.size.y >= 44 and target.focus_mode == Control.FOCUS_ALL, "button lost 44px keyboard target")
	menu.queue_free()
	await process_frame
	if failures == 0:
		print("TEST PASS: CampaignMenuTest %d" % assertions)
	quit(1 if failures > 0 else 0)
