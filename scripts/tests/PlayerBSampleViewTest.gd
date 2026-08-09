extends SceneTree

const PlayerBSampleViewScript = preload("res://scripts/art/PlayerBSampleView.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerBSampleViewTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(PlayerBSampleViewScript.BOARD_SIZE == Vector2i(1280, 720), "runtime board must use the base viewport"):
		return
	if not _assert_true(PlayerBSampleViewScript.SAMPLE_DIRECTION_COUNT == 8, "sample must contain eight key directions"):
		return
	if not _assert_true(PlayerBSampleViewScript.SAMPLE_STEP_DEGREES == 45.0, "sample step must be 45 degrees"):
		return

	for degrees in range(0, 360, 45):
		if not _assert_true(PlayerBSampleViewScript.sample_index(deg_to_rad(float(degrees))) == degrees / 45, "sample angle %d mapped incorrectly" % degrees):
			return
	if not _assert_true(PlayerBSampleViewScript.sample_index(deg_to_rad(-45.0)) == 7, "negative sample angle did not wrap"):
		return
	if not _assert_true(PlayerBSampleViewScript.sample_index(deg_to_rad(22.49)) == 0, "angle below half-step advanced too early"):
		return
	if not _assert_true(PlayerBSampleViewScript.sample_index(deg_to_rad(22.51)) == 1, "angle above half-step did not advance"):
		return

	for index in range(8):
		var expected_behind := index >= 5
		if not _assert_true(PlayerBSampleViewScript.weapon_draws_behind(index) == expected_behind, "weapon occlusion pass is wrong for sample %d" % index):
			return

	for path in [
		PlayerBSampleViewScript.BODY_ATLAS_PATH,
		PlayerBSampleViewScript.WEAPON_ATLAS_PATH,
		PlayerBSampleViewScript.COMPOSITE_ATLAS_PATH,
	]:
		var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		if not _assert_true(texture != null, "sample atlas did not import: " + path):
			return
		if not _assert_true(texture.get_size() == Vector2(512, 64), "sample atlas size is wrong: " + path):
			return
		var image := texture.get_image()
		if not _assert_true(image != null and image.get_pixel(0, 0).a == 0.0, "sample atlas corner is not transparent: " + path):
			return

	print("TEST PASS: PlayerBSampleViewTest %d" % assertions)
	quit(0)
