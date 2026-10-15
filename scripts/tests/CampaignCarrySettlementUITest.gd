extends SceneTree
## Shared six-chapter controls only; not a real Boss clear or GPU acceptance.
const Interface = preload("res://scripts/ui/ChapterRunUI.gd")
var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignCarrySettlementUITest " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# A nested viewport tests logical UI dimensions without the project window's
	# 1280x720 stretch override mixing physical pixels and canvas coordinates.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var ui := Interface.new()
	viewport.add_child(ui)
	if not ui.has_method("present_chapter_clear"):
		check(false, "six-chapter inheritance settlement UI missing")
		ui.free()
		viewport.free()
		quit(1)
		return
	var choices: Array[Dictionary] = [{"id": "damage", "label": "超频弹芯", "description": "子弹伤害 +14%"}, {"id": "mine", "label": "静滞地刺", "description": "解锁地刺"}]
	var observed := {"choice": "", "next": 0}
	ui.carry_choice_requested.connect(func(id: String) -> void: observed.choice = id)
	ui.next_chapter_requested.connect(func() -> void: observed.next += 1)
	for chapter in range(1, 7):
		ui.call("present_chapter_clear", chapter, choices, 57, false)
		var actions := ui.flow_panel.find_children("*", "Button", true, false)
		check(actions.filter(func(button: Button) -> bool: return button.visible and not button is OptionButton).size() == (3 if chapter < 6 else 2), "extra button violates exact requested action count")
		check(ui.next_button.visible == (chapter < 6), "wrong final/nonfinal navigation visibility")
		check(ui.replay_button.visible and ui.return_button.visible, "required replay/tent buttons missing")
		check(ui.replay_button.disabled and ui.return_button.disabled and ui.next_button.disabled, "navigation bypasses pending inherited choice")
		check(ui.carry_selector.visible and ui.carry_selector.selected == 0, "selection not initially required")
		ui.carry_selector.item_selected.emit(0)
		check(observed.choice == "", "placeholder submitted as a reward")
		ui.carry_selector.select(2)
		ui.carry_selector.item_selected.emit(2)
		check(ui.carry_hint.text.contains("解锁地刺"), "selected card not explained")
		check(observed.choice == "mine", "selected stable card ID not emitted")
		observed.choice = ""
		ui.call("present_chapter_clear", chapter, choices, 57, true)
		check(not ui.carry_selector.visible and not ui.replay_button.disabled and not ui.return_button.disabled, "rewarded replay blocked or grants duplicate choice")
		check(ui.replay_button.text == "重玩本关卡" and ui.return_button.text.contains("返回帐篷"), "wrong requested button copy")
	var empty: Array[Dictionary] = []
	ui.call("present_chapter_clear", 6, empty, 12, false)
	check(not ui.next_button.visible and not ui.return_button.disabled and not ui.carry_selector.visible, "no eligible ability softlocks sixth chapter")
	ui.call("present_chapter_clear", 1, choices, 57, false)
	for extent in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		viewport.size = extent
		ui.apply_viewport_size(Vector2(extent))
		await process_frame
		await process_frame
		var panel: Rect2 = ui.flow_panel.get_global_rect()
		check(Rect2(Vector2(8, 8), Vector2(extent) - Vector2(16, 16)).encloses(panel), "carry flow overflow: " + str(extent) + " " + str(panel))
	ui.present("暂停", "继续", &"pause")
	check(not ui.next_button.visible and not ui.carry_selector.visible, "new settlement controls leak into pause")
	check(not ui.return_button.disabled, "pending inheritance disables later pause/tent")
	ui.free()
	viewport.free()
	await process_frame
	if failures == 0:
		print("TEST PASS: CampaignCarrySettlementUITest %d" % assertions)
	quit(0 if failures == 0 else 1)
