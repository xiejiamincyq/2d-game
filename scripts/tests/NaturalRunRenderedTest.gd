extends SceneTree

const Recorder = preload("res://scripts/art/VerifyNaturalRunRendered.gd")
var assertions := 0

func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: NaturalRunRenderedTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var info := {"state": "PLAYING", "wave": 1, "step": 30, "visible_live": 20, "dash": true, "warning_overlap": true, "boss_active": true}
	if not _check(Recorder.eligible_tags(info) == ["opening", "crowd", "dash", "overlap", "boss"], "natural conditions did not select their captures"):
		return
	info = {"state": "PLAYING", "wave": 2, "step": 1, "visible_live": 19, "dash": false, "warning_overlap": false, "boss_active": false}
	if not _check(Recorder.eligible_tags(info).is_empty(), "missing conditions were invented"):
		return
	info["live"] = 100
	info.visible_live = 0
	if not _check(Recorder.eligible_tags(info).is_empty(), "offscreen enemies counted as visual crowd"):
		return
	info.state = "SETTLEMENT"
	info["shop_ready"] = true
	if not _check(Recorder.eligible_tags(info) == ["shop"], "shop not selected"):
		return
	info.state = "PAUSED"
	info.dash = true
	info.boss_active = true
	if not _check(Recorder.eligible_tags(info).is_empty(), "paused fixture mislabeled as combat"):
		return
	print("TEST PASS: NaturalRunRenderedTest %d" % assertions)
	quit(0)
