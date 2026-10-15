extends "res://scripts/art/VerifyFoundryChapterFlow.gd"
## Genuine engine popup keyboard input, not a synthetic victory/selection signal.
const Interface = preload("res://scripts/ui/ChapterRunUI.gd")
func _initialize() -> void: call_deferred("input_checks")
func input_checks() -> void:
	await process_frame
	await prepare_scene_host()
	var ui:=Interface.new()
	embedded_view.add_child(ui)
	var choices: Array[Dictionary]=[{"id":"damage","label":"伤害模块","kind":"support","description":"测试界面输入"}]
	var chosen: Array[String]=[]
	ui.carry_choice_requested.connect(func(id: String): chosen.append(id))
	ui.present_chapter_clear(1,choices,37,false)
	for frame in 4: await process_frame
	check(ui.next_button.disabled and ui.return_button.disabled,"real choice must initially gate navigation")
	check(await select_first_carry(ui),"real pointer/popup/keyboard cannot select first inheritance")
	check(chosen==["damage"],"engine input must emit exactly one genuinely selected card")
	ui.queue_free()
	await process_frame
	var scroll:=ScrollContainer.new()
	scroll.size=Vector2(400,240); scroll.follow_focus=true
	embedded_view.add_child(scroll)
	var content:=VBoxContainer.new()
	scroll.add_child(content)
	var first:=Button.new(); first.text="First"; first.custom_minimum_size=Vector2(300,46)
	content.add_child(first)
	var spacer:=Control.new(); spacer.custom_minimum_size=Vector2(300,800)
	content.add_child(spacer)
	var last:=Button.new(); last.text="Finish below scroll"; last.custom_minimum_size=Vector2(300,46)
	content.add_child(last)
	var activations:=[0]
	last.pressed.connect(func(): activations[0]+=1)
	for frame in 4: await process_frame
	first.grab_focus()
	await _click(last)
	check(activations[0]==1 and scroll.scroll_vertical>0,"real keyboard reveal must expose clipped footer and actual pointer click it exactly once")
	scroll.queue_free()
	await process_frame
	if failures==0: print("TEST PASS: CampaignEndlessInputTest %d"%assertions)
	quit(1 if failures else 0)
