extends SceneTree
const SCENE := "res://scenes/actors/native/sporeling_paper_v1.tscn"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: SporelingResourceTest " + label)
func _initialize() -> void:
	await process_frame
	check(FileAccess.file_exists(SCENE), "new editable spore shooter resource missing")
	if failures:
		quit(1)
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/sporeling_paper_v1.json"))
	check(manifest is Dictionary and Validator.new().validate_entry(manifest).is_empty(), "native geometry / dependency / motion contract rejected")
	var packed: PackedScene = load(SCENE)
	var actor = packed.instantiate()
	root.add_child(actor)
	actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(actor.skeleton.get_bone_count() == 14, "mouth and spore sac are not distinct native joints")
	var mouth: Bone2D = actor.skeleton.get_node("Torso/Head/Mouth")
	var sac: Bone2D = actor.skeleton.get_node("Torso/SporeSac")
	for clip in ["idle", "walk", "warning", "attack", "hit", "death"]:
		check(actor.sample_clip(clip, 0), "missing new action " + clip)
		var length: float = actor.player.get_animation(clip).length
		actor.sample_clip(clip, length * 0.5)
		check(actor.position == Vector2.ZERO and actor.rotation == 0 and actor.scale == Vector2.ONE, "motion controls gameplay root")
		check(actor.skeleton.get_bone(0).transform != actor.skeleton.get_bone(0).rest or mouth.transform != mouth.rest or sac.transform != sac.rest, "new clip has no real joint motion: " + clip)
		if clip != "death":
			check(actor.cancel_action(), "live action cannot cancel")
			for index in actor.skeleton.get_bone_count():
				check(actor.skeleton.get_bone(index).transform.is_equal_approx(actor.skeleton.get_bone(index).rest), "cancel leaves joint offset")
	check(not actor.cancel_action() and not actor.sample_clip("walk", 1), "terminal body revives")
	actor.free()
	if failures == 0:
		print("TEST PASS: SporelingResourceTest %d" % checks)
	quit(1 if failures else 0)
