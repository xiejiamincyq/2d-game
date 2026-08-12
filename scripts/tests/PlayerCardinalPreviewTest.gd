extends SceneTree

const PreviewScript = preload("res://scripts/art/PlayerCardinalPreviewView.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerCardinalPreviewTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(PreviewScript.DIRECTIONS == ["FRONT", "RIGHT SIDE", "REAR"], "direction order changed"):
		return
	if not _assert_true(PreviewScript.OPTION_IDS == ["A", "B", "C"], "approval option labels changed"):
		return
	if not _assert_true(PreviewScript.LAYER_ORDER == ["weapon_behind", "body", "weapon_front"], "layer order changed"):
		return
	for path in PreviewScript.LAYER_PATHS.values():
		var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		if not _assert_true(texture != null, "preview layer failed to import: " + path):
			return
		if not _assert_true(texture.get_size() == Vector2(192, 64), "preview layer is not 192x64: " + path):
			return
	if not _assert_true(PreviewScript.frame_rect(0) == Rect2(Vector2.ZERO, Vector2(64, 64)), "front frame rectangle is wrong"):
		return
	if not _assert_true(PreviewScript.frame_rect(2) == Rect2(Vector2(128, 0), Vector2(64, 64)), "rear frame rectangle is wrong"):
		return
	print("TEST PASS: PlayerCardinalPreviewTest %d" % assertions)
	quit(0)
