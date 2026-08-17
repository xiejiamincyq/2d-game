extends SceneTree

const ViewScript = preload("res://scripts/art/PlayerActionSliceView.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerActionSliceViewTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(ViewScript.BOARD_SIZE == Vector2i(1280, 720), "board must use the base viewport"):
		return
	if not _assert_true(ViewScript.ACTIONS == ["idle", "run", "fire", "dash", "hit"], "actions or order changed"):
		return
	if not _assert_true(ViewScript.FRAMES_PER_ACTION == 6, "each action must have six frames"):
		return
	if not _assert_true(ViewScript.LAYER_ORDER == ["weapon_behind", "body", "weapon_front"], "layer order changed"):
		return
	if not _assert_true(ViewScript.ACTION_FPS.keys() == ViewScript.ACTIONS, "action FPS table is incomplete or out of order"):
		return
	if not _assert_true(ViewScript.playback_frame("run", 0.0) == 0, "run must start at frame zero"):
		return
	if not _assert_true(ViewScript.playback_frame("run", 0.11) == 1, "run did not advance at 10 FPS"):
		return
	if not _assert_true(ViewScript.playback_frame("run", 0.61) == 0, "run loop did not wrap after six frames"):
		return

	for action_index in range(ViewScript.ACTIONS.size()):
		for frame_index in range(ViewScript.FRAMES_PER_ACTION):
			var rect := ViewScript.frame_rect(action_index, frame_index)
			if not _assert_true(rect.position == Vector2i(frame_index * 64, action_index * 64), "frame position is wrong"):
				return
			if not _assert_true(rect.size == Vector2i(64, 64), "frame size is wrong"):
				return

	for path in ViewScript.LAYER_PATHS.values():
		var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		if not _assert_true(texture != null, "layer did not import: " + path):
			return
		if not _assert_true(texture.get_size() == Vector2(384, 320), "layer atlas size is wrong: " + path):
			return

	var view := ViewScript.new()
	root.add_child(view)
	await process_frame
	for action in ViewScript.ACTIONS:
		var base_vector := view.socket_position(action, 0, "muzzle") - view.socket_position(action, 0, "grip")
		for frame_index in range(ViewScript.FRAMES_PER_ACTION):
			var vector := view.socket_position(action, frame_index, "muzzle") - view.socket_position(action, frame_index, "grip")
			if not _assert_true(vector == base_vector, "weapon direction changed in " + action):
				return
			if not _assert_true(view.socket_position(action, frame_index, "grip") != Vector2.ZERO, "grip socket missing"):
				return

	print("TEST PASS: PlayerActionSliceViewTest %d" % assertions)
	quit(0)
