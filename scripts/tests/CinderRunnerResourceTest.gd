extends SceneTree
const SCENE := "res://scenes/actors/native/cinder_runner_paper_v1.tscn"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CinderRunnerResourceTest " + label)
func _initialize() -> void:
	await process_frame
	check(FileAccess.file_exists(SCENE), "new original cinder runner resource missing")
	if failures:
		quit(1)
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/cinder_runner_paper_v1.json"))
	check(manifest is Dictionary and Validator.new().validate_entry(manifest).is_empty(), "native geometry/dependency contract rejected")
	var actor = load(SCENE).instantiate()
	root.add_child(actor)
	actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(actor.skeleton.get_bone_count() == 15, "mantle and two shins are not independent bones")
	for clip in ["idle","walk","warning","attack","hit","death"]:
		check(actor.sample_clip(clip,0), "missing action " + clip)
		actor.sample_clip(clip,actor.player.get_animation(clip).length * 0.45)
		check(actor.position == Vector2.ZERO and actor.rotation == 0 and actor.scale == Vector2.ONE, "animation controls gameplay root")
		var moving := false
		for index in actor.skeleton.get_bone_count():
			moving = moving or not actor.skeleton.get_bone(index).transform.is_equal_approx(actor.skeleton.get_bone(index).rest)
		check(moving, "no actual articulated motion " + clip)
		if clip != "death":
			check(actor.cancel_action(), "cannot cancel live action")
			for index in actor.skeleton.get_bone_count():
				check(actor.skeleton.get_bone(index).transform.is_equal_approx(actor.skeleton.get_bone(index).rest), "stale joint after cancel")
	check(not actor.cancel_action() and not actor.sample_clip("walk",1), "dead body revives")
	actor.free()
	if not failures:
		print("TEST PASS: CinderRunnerResourceTest %d" % checks)
	quit(1 if failures else 0)
