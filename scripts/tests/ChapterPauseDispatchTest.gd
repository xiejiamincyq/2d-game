extends SceneTree
## Real viewport dispatch (not direct callbacks); isolated UI, no saves/combat cheats.
const UI = preload("res://scripts/ui/ChapterRunUI.gd")
var failures := 0
var assertions := 0
var pause_count := 0
var return_count := 0
var resume_count := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: ChapterPauseDispatchTest " + message)

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var ui := UI.new()
	root.add_child(ui)
	ui.pause_requested.connect(func() -> void:
		pause_count += 1
		if ui.flow_root.visible and ui.resume_button.visible:
			ui.hide_flow()
		else:
			ui.present("暂停探索", "", &"pause")
	)
	ui.resume_requested.connect(func() -> void:
		resume_count += 1
		ui.hide_flow()
	)
	ui.return_requested.connect(func() -> void: return_count += 1)
	ui.proceed_requested.connect(ui.hide_flow)
	ui.present("第1关", "", &"intro")
	await process_frame
	await process_frame
	var point: Vector2 = ui.proceed_button.get_global_rect().get_center()
	print("DISPATCH proceed center: ", point)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = down
		root.push_input(click, true)
		await process_frame
	check(not ui.flow_root.visible, "real mouse failed to enter combat UI")
	print("DISPATCH focus before Space: ", root.gui_get_focus_owner())
	_key(KEY_SPACE, true)
	await process_frame
	_key(KEY_SPACE, false)
	await process_frame
	check(pause_count == 1, "Space did not dispatch exactly one pause request")
	check(return_count == 0, "Space activated return-to-camp instead of pause")
	check(ui.flow_root.visible and ui.resume_button.visible, "Space failed to retain pause overlay")
	_key(KEY_SPACE, true)
	await process_frame
	_key(KEY_SPACE, false)
	await process_frame
	check(not ui.flow_root.visible and return_count == 0, "focused resume Space returned to camp")
	_key(KEY_ESCAPE, true)
	await process_frame
	_key(KEY_ESCAPE, false)
	await process_frame
	check(ui.flow_root.visible and ui.resume_button.visible, "Esc failed to pause")
	_key(KEY_ESCAPE, true)
	await process_frame
	_key(KEY_ESCAPE, false)
	await process_frame
	check(not ui.flow_root.visible and return_count == 0, "Esc resume returned to camp")
	check(pause_count + resume_count == 4, "pause/resume requests were duplicated by GUI propagation")
	ui.free()
	await process_frame
	if failures == 0: print("TEST PASS: ChapterPauseDispatchTest %d" % assertions)
	quit(1 if failures > 0 else 0)
