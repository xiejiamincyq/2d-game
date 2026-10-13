extends SceneTree
## Decorative motion must not delay inputs, move controls, or run while hidden.
const Menu = preload("res://scripts/ui/CampaignStartScreen.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const MOTION := "res://scripts/ui/CampaignAnimatedBackdrop.gd"
var assertions := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignMenuMotionTest " + message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	check(ResourceLoader.exists(MOTION, "GDScript"), "new menu motion is absent; backdrop is still static")
	if failures: quit(1); return
	var menu = Menu.new()
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(menu)
	menu.size = Vector2(1280, 720)
	menu.set_campaign(Progress.new(), [1, 2, 3, 4, 5, 6], "")
	await process_frame
	var art: Control = menu.get_child(0)
	check(art.get_script() == load(MOTION), "actual menu does not use the new motion variant")
	check(art.mouse_filter == Control.MOUSE_FILTER_IGNORE and art.focus_mode == Control.FOCUS_NONE, "decoration captures input")
	art.set_process(false)
	art.set("_motion_seconds", 0.0)
	var rect: Rect2 = menu.start_button.get_global_rect()
	var initial: Vector2 = art.call("_mist_offset", 0)
	var lamp: Color = art.call("_lamp_color")
	for _step in 60: art.call("_process", 1.0 / 60.0)
	check(initial.distance_to(art.call("_mist_offset", 0)) > 0.1, "mist has no actual motion")
	check(lamp != art.call("_lamp_color"), "lamp remains static")
	check(menu.start_button.get_global_rect() == rect and not menu.start_button.disabled, "motion moves or blocks Start")
	for invalid in [-1.0, NAN, INF, 0.0]:
		var before: float = art.get("_motion_seconds")
		art.call("_process", invalid)
		check(art.get("_motion_seconds") == before, "invalid delta alters motion")
	for seconds in range(0, 120, 3):
		art.set("_motion_seconds", float(seconds))
		for index in 6:
			var offset: Vector2 = art.call("_mist_offset", index)
			check(offset.is_finite() and absf(offset.x) <= 9.001 and absf(offset.y) <= 1.201, "mist escapes its restrained bounds")
		var tint: Color = art.call("_lamp_color")
		check(is_equal_approx(tint.a, 1.0) and tint.r >= 0.0 and tint.r <= 1.0, "lamp/body opacity or color invalid")
	for index in 6:
		art.set("_motion_seconds", 119.999)
		var before_seam: Vector2 = art.call("_mist_offset", index)
		art.set("_motion_seconds", 0.001)
		check(before_seam.distance_to(art.call("_mist_offset", index)) < 0.005, "periodic mist seam jumps")
	art.set("_motion_seconds", 119.999)
	var before_lamp: Color = art.call("_lamp_color")
	art.set("_motion_seconds", 0.001)
	var after_lamp: Color = art.call("_lamp_color")
	check(absf(before_lamp.r - after_lamp.r) < 0.00001 and absf(before_lamp.g - after_lamp.g) < 0.00001 and absf(before_lamp.b - after_lamp.b) < 0.00001, "periodic lamp seam jumps")
	art.set("_motion_seconds", 119.98)
	art.call("_process", 100.0)
	check(is_equal_approx(art.get("_motion_seconds"), 0.08), "long frame is not bounded and periodically wrapped")
	menu.hide()
	check(not art.is_processing(), "hidden menu still schedules background processing")
	var hidden_clock: float = art.get("_motion_seconds")
	art.call("_process", 0.1)
	await process_frame
	check(art.get("_motion_seconds") == hidden_clock, "hidden decoration advances")
	menu.show()
	check(art.is_processing(), "returned menu fails to resume motion")
	paused = true
	var before_pause: float = art.get("_motion_seconds")
	await process_frame
	await process_frame
	check(art.get("_motion_seconds") > before_pause, "visible menu animation cannot run on its UI-only paused branch")
	paused = false
	var requested := [0]
	menu.start_requested.connect(func() -> void: requested[0] += 1)
	menu.start_button.pressed.emit()
	check(requested[0] == 1, "Start is delayed behind an animation gate")
	menu.free()
	await process_frame
	if not failures: print("TEST PASS: CampaignMenuMotionTest %d" % assertions)
	quit(1 if failures else 0)
