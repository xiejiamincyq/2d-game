extends SceneTree
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Menu = preload("res://scripts/ui/CampaignStartScreen.gd")
var checks := 0
var failures := 0
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignPendingEntryMenuTest "+message)
func _initialize() -> void:
	var progress := Progress.new()
	check(progress.record_boss_defeat(1),"controlled preceding clear")
	var menu := Menu.new()
	root.add_child(menu)
	await process_frame
	var requested: Array[int] = []
	menu.chapter_requested.connect(func(chapter: int): requested.append(chapter))
	var ready: Array[int] = [1,2,3,4,5,6]
	menu.set_campaign(progress,ready)
	menu.set_journey({"loop":1,"chapter":2},{"coins":72,"inherited_counts":{"damage":1}},true)
	menu.show_page(menu.Page.CHAPTERS)
	menu.select_chapter(1)
	check(menu.launch_button.disabled and menu.launch_button.text.contains("领取"),"pending reward leaves previous chapter launch apparently usable")
	menu.launch_button.disabled = false
	menu.launch_button.pressed.emit()
	check(requested.is_empty(),"hostile button mutation bypasses pending reward menu guard")
	requested.clear()
	menu.select_chapter(2)
	check(not menu.launch_button.disabled and menu.launch_button.text.contains("领取"),"pending reward entry has no truthful action label")
	menu.launch_button.pressed.emit()
	check(requested==[2],"current pending chapter cannot resume reward")
	menu.set_journey({"loop":1,"chapter":2},{"coins":72,"inherited_counts":{"damage":1}},false)
	menu.select_chapter(1)
	check(not menu.launch_button.disabled,"reward completion leaves unrelated chapter blocked")
	menu.free()
	if not failures: print("TEST PASS: CampaignPendingEntryMenuTest %d"%checks)
	quit(1 if failures else 0)
