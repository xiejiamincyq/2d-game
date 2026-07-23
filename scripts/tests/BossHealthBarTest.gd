extends SceneTree

const BossHealthBarScript = preload("res://scripts/ui/BossHealthBar.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: BossHealthBarTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var bar: Control = BossHealthBarScript.new()
	root.add_child(bar)
	await process_frame
	if not _assert_true(not bar.visible, "Boss health bar should be hidden before a Boss spawns"):
		return

	bar.show_boss("深渊监工 / OVERSEER", 1000.0)
	if not _assert_true(bar.visible and bar.name_label.text == "深渊监工 / OVERSEER", "Boss spawn did not reveal the named health bar"):
		return
	if not _assert_true(bar.health_bar.value == 1000.0 and bar.phase_label.text.contains("PHASE I"), "Boss spawn did not initialize health and phase"):
		return

	bar.set_boss_health(620.0, 1000.0, 2)
	if not _assert_true(is_equal_approx(bar.health_bar.value, 620.0) and bar.phase_label.text.contains("PHASE II"), "Boss damage did not update health and phase"):
		return
	if not _assert_true(bar.thresholds == [0.70, 0.35], "Boss bar lost the 70% and 35% phase markers"):
		return

	for viewport_size in [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1080)]:
		bar.apply_viewport_size(viewport_size)
		await process_frame
		if not _assert_true(bar.position.y == 18.0 and bar.size.y == 28.0, "Boss bar did not retain its top-safe 28px height at %s" % viewport_size):
			return
		if not _assert_true(bar.size.x >= viewport_size.x * 0.60 and bar.size.x <= viewport_size.x * 0.78, "Boss bar width %s did not stay inside the 60-78%% responsive range at %s" % [bar.size.x, viewport_size]):
			return
		if not _assert_true(bar.anchor_left == 0.5 and bar.anchor_right == 0.5 and bar.position.x == -bar.size.x * 0.5, "Boss bar was not centered inside viewport %s" % viewport_size):
			return

	bar.hide_boss()
	if not _assert_true(not bar.visible, "Boss defeat did not hide the health bar"):
		return
	bar.queue_free()
	await process_frame
	print("TEST PASS: BossHealthBarTest %d" % assertions)
	quit(0)
