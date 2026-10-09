extends SceneTree

var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NurseryClearanceProofTest " + message)

func _initialize() -> void:
	var probe = load("res://scripts/art/VerifyNurseryEncounterRun.gd")
	var found := false
	for method in probe.get_script_method_list():
		found = found or method.name == "has_body_clearance"
	check(found, "GPU acceptance confuses conservative square navigation with circular body collision")
	if failures > 0:
		quit(1)
		return
	var bounds := Rect2(-100, -100, 200, 200)
	var obstacles: Array[Dictionary] = [{"rect": Rect2(0, 0, 20, 20)}]
	check(Rect2(0, 0, 20, 20).grow(10).has_point(Vector2(-8, -8)), "corner fixture does not reproduce conservative navigation rejection")
	check(probe.has_body_clearance(Vector2(-8, -8), bounds, obstacles, 10), "clear rounded corner rejected")
	check(not probe.has_body_clearance(Vector2(-7, -7), bounds, obstacles, 10), "actual rounded-corner penetration accepted")
	check(not probe.has_body_clearance(Vector2(-9, 5), bounds, obstacles, 10), "actual face penetration accepted")
	check(not probe.has_body_clearance(Vector2(10, 10), bounds, obstacles, 10), "body inside obstacle accepted")
	check(probe.has_body_clearance(Vector2(-10.08, 5), bounds, obstacles, 10), "positive physics safe margin rejected")
	check(not probe.has_body_clearance(Vector2(-95, 50), bounds, obstacles, 10), "body escaped world bounds")
	check(probe.has_body_clearance(Vector2(-90, 50), bounds, obstacles, 10), "body exactly at allowed world edge rejected")
	var empty: Array[Dictionary] = []
	check(probe.has_body_clearance(Vector2(-80, 50), bounds, empty, 10), "empty world falsely blocks body")
	if failures == 0:
		print("TEST PASS: NurseryClearanceProofTest %d" % assertions)
	quit(1 if failures > 0 else 0)
