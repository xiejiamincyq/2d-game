extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")

const BODY_PATH := "res://assets/art/actors/player/action_slices/player_b_action_slice_down_right_body.png"
const WEAPON_BEHIND_PATH := "res://assets/art/actors/player/action_slices/player_b_action_slice_down_right_weapon_behind.png"
const WEAPON_FRONT_PATH := "res://assets/art/actors/player/action_slices/player_b_action_slice_down_right_weapon_front.png"

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerActionSliceCombatTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var player: CharacterBody2D = PlayerScript.new()
	root.add_child(player)
	await process_frame

	if not _assert_true(player.action_slice_preview_enabled, "combat preview must be enabled for the approved direction slot"):
		return
	if not _assert_true(player.uses_action_slice(deg_to_rad(45.0)), "45 degrees must use the approved action slice"):
		return
	if not _assert_true(player.uses_action_slice(deg_to_rad(52.49)), "the complete 15-degree slot must use the action slice"):
		return
	if not _assert_true(not player.uses_action_slice(deg_to_rad(52.51)), "angles outside the approved slot must fall back to turnaround art"):
		return
	if not _assert_true(not player.uses_action_slice(deg_to_rad(-45.0)), "the opposite screen quadrant must not reuse this slice"):
		return

	if not _assert_true(player.resolve_action_slice_action(false, false, false, false) == "idle", "idle state did not resolve"):
		return
	if not _assert_true(player.resolve_action_slice_action(true, false, false, false) == "run", "movement did not resolve to run"):
		return
	if not _assert_true(player.resolve_action_slice_action(true, true, false, false) == "fire", "fire did not override movement"):
		return
	if not _assert_true(player.resolve_action_slice_action(true, true, true, false) == "dash", "dash did not override fire"):
		return
	if not _assert_true(player.resolve_action_slice_action(true, true, true, true) == "hit", "hit did not have highest visual priority"):
		return

	if not _assert_true(player.action_slice_frame("run", 0.11) == 1, "run did not advance at 10 FPS"):
		return
	if not _assert_true(player.action_slice_frame("run", 0.61) == 0, "run did not wrap after six frames"):
		return
	if not _assert_true(player.action_slice_source_rect("fire", 2) == Rect2(Vector2(128, 128), Vector2(64, 64)), "fire frame atlas rectangle is wrong"):
		return

	for path in [WEAPON_BEHIND_PATH, BODY_PATH, WEAPON_FRONT_PATH]:
		var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		if not _assert_true(texture != null, "combat layer did not import: " + path):
			return
		if not _assert_true(texture.get_size() == Vector2(384, 320), "combat layer has the wrong atlas size: " + path):
			return

	player.queue_free()
	await process_frame
	print("TEST PASS: PlayerActionSliceCombatTest %d" % assertions)
	quit(0)
