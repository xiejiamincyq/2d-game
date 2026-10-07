extends SceneTree

const Reticle = preload("res://scripts/ui/AimReticle.gd")
var assertions := 0
var failures := 0

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("TEST FAIL: AimReticleOutlineTest: " + message)

func _initialize() -> void:
	var reticle := Reticle.new()
	root.add_child(reticle)
	await process_frame
	check(reticle.OUTLINE == Color.BLACK, "aim reticle still uses a low-contrast green outline, not black")
	check(reticle.size == Vector2(24, 24), "outline enlarged reticle over target bodies")
	check(reticle.mouse_filter == Control.MOUSE_FILTER_IGNORE and reticle.focus_mode == Control.FOCUS_NONE, "reticle intercepted input")
	for point in [Vector2.ZERO, Vector2(640, 360), Vector2(1279, 719)]:
		reticle.set_screen_position(point)
		check(reticle.get_rect().get_center().is_equal_approx(point), "outline shifted aim center")
	reticle.set_active(true)
	check(reticle.visible and reticle.is_processing(), "reticle did not activate")
	reticle.set_active(false)
	check(not reticle.visible and not reticle.is_processing(), "reticle remained on modal UI")
	reticle.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("TEST PASS: AimReticleOutlineTest %d" % assertions)
	quit(0 if failures == 0 else 1)
