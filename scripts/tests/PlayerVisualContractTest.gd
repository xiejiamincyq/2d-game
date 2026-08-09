extends SceneTree

const PlayerVisualContractScript = preload("res://scripts/art/PlayerVisualContract.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerVisualContractTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(PlayerVisualContractScript.CAMERA_PITCH_DEGREES == 45.0, "camera pitch must be exactly 45 degrees"):
		return
	if not _assert_true(PlayerVisualContractScript.DIRECTION_COUNT == 24, "B pipeline must use 24 directions"):
		return
	if not _assert_true(PlayerVisualContractScript.DIRECTION_STEP_DEGREES == 15.0, "B pipeline direction step must be 15 degrees"):
		return
	if not _assert_true(PlayerVisualContractScript.ATLAS_COLUMNS == 6, "24-direction atlas must use six columns"):
		return
	if not _assert_true(PlayerVisualContractScript.ATLAS_ROWS == 4, "24-direction atlas must use four rows"):
		return
	if not _assert_true(PlayerVisualContractScript.FRAME_SIZE == Vector2i(64, 64), "runtime frames must be 64x64"):
		return
	if not _assert_true(PlayerVisualContractScript.FRAME_PIVOT == Vector2(32.0, 32.0), "player pivot must remain centered over the collision shape"):
		return
	if not _assert_true(PackedStringArray(PlayerVisualContractScript.LAYER_ORDER) == PackedStringArray(["weapon_behind", "body", "weapon_front"]), "weapon occlusion layer order is wrong"):
		return

	var expected_indices := {
		0.0: 0,
		90.0: 6,
		180.0: 12,
		270.0: 18,
		360.0: 0,
		-15.0: 23,
	}
	for degrees: float in expected_indices:
		var expected: int = expected_indices[degrees]
		if not _assert_true(PlayerVisualContractScript.direction_index(deg_to_rad(degrees)) == expected, "angle %.1f mapped to the wrong direction" % degrees):
			return
	if not _assert_true(PlayerVisualContractScript.direction_index(deg_to_rad(7.49)) == 0, "angle below half-step advanced too early"):
		return
	if not _assert_true(PlayerVisualContractScript.direction_index(deg_to_rad(7.51)) == 1, "angle above half-step did not advance"):
		return
	if not _assert_true(PlayerVisualContractScript.frame_rect(0) == Rect2i(0, 0, 64, 64), "frame zero rectangle is wrong"):
		return
	if not _assert_true(PlayerVisualContractScript.frame_rect(23) == Rect2i(320, 192, 64, 64), "last frame rectangle is wrong"):
		return

	print("TEST PASS: PlayerVisualContractTest %d" % assertions)
	quit(0)
