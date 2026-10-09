extends SceneTree
## External driver for an actual PCK; never touches game saves or actor stats.
const Actor = preload("res://scenes/actors/native/player_paper_v1.tscn")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyNativePlayerPack " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(not FileAccess.file_exists("res://scenes/art/technical/PlayerPaperDraft.gd"), "author source leaked into PCK or test is running against workspace")
	var actor = Actor.instantiate()
	root.add_child(actor)
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		check(actor.set_aim(direction), "pack aim failed")
		var rig: Skeleton2D = actor.get_node(actor.facing + "/Skeleton2D")
		check(rig.get_bone_count() == 13, "pack native joints missing")
		for clip in ["idle", "walk", "shoot", "dash", "hit", "entrance"]:
			check(actor.sample_clip(clip, 0.1), "pack motion cannot load " + clip)
			check(actor.get_muzzle_position().is_finite(), "pack muzzle invalid")
	check(actor.sample_clip("death", 0.3) and not actor.cancel_action(), "pack death not terminal")
	actor.free()
	await process_frame
	if failures == 0:
		print("NATIVE PLAYER PACK PASS: editable four-view bones, actual motion sampling and hand muzzle; authoring excluded")
	quit(1 if failures else 0)
