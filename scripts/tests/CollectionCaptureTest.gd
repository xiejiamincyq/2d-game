extends SceneTree

const Recorder = preload("res://scripts/art/VerifyNaturalRunRendered.gd")
const HUD = preload("res://scripts/ui/HUD.gd")
var assertions := 0

func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: CollectionCaptureTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var due := Callable(Recorder, "collection_capture_due")
	if not _check(due.is_valid(), "six-scene quota cannot record a full collection window"):
		return
	for case in [
		[false, false, false, 0, -1, false],
		[true, false, false, 0, -1, true],
		[true, false, false, 2, 0, false],
		[true, false, false, 3, 0, true],
		[true, false, false, 4, 0, true],
		[false, true, false, 2, 0, true],
		[false, true, true, 3, 0, false],
		[true, false, true, 3, 0, false],
	]:
		if not _check(due.call(case[0], case[1], case[2], case[3], case[4]) == case[5], "start/cadence/end/completion capture policy failed"):
			return
	_check_real_hud.call_deferred()

func _check_real_hud() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	await process_frame
	hud.set_collection_window(2.9658347, 3.0)
	if not _check(is_equal_approx(hud.collection_bar.step, 0.01), "real collection Range step changed"):
		hud.free()
		return
	if not _check(is_equal_approx(hud.collection_bar.value, 2.97), "real collection Range does not snap to 0.01"):
		hud.free()
		return
	if not _check(hud.collection_label.text == "倒计时：3.0s" and hud.collection_panel.visible, "real positive collection UI differs"):
		hud.free()
		return
	hud.set_collection_window(0.0, 3.0)
	if not _check(is_zero_approx(hud.collection_bar.value) and not hud.collection_panel.visible, "real zero collection tail is not hidden"):
		hud.free()
		return
	hud.free()
	await process_frame
	print("TEST PASS: CollectionCaptureTest %d" % assertions)
	quit(0)
