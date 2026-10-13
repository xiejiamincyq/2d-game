extends SceneTree
const SCENE := "res://scenes/actors/native/cinder_runner_paper_v2.tscn"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CinderChargeResourceTest " + label)
func _initialize() -> void:
	await process_frame
	check(FileAccess.file_exists(SCENE),"new version missing; must not overwrite v1")
	if failures:
		quit(1)
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/cinder_runner_paper_v2.json"))
	check(manifest is Dictionary and Validator.new().validate_entry(manifest).is_empty(),"native resource contract")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	for clip in ["charge_warning","charge","charge_recovery"]:
		check(view.sample_clip(clip,0.07),"missing charge clip " + clip)
		check(view.position == Vector2.ZERO and view.rotation == 0,"visual moves gameplay root")
		var torso: Bone2D = view.skeleton.get_bone(0)
		var shin: Bone2D = view.skeleton.get_node("Torso/LegL/ShinL")
		check(not torso.transform.is_equal_approx(torso.rest) and not shin.transform.is_equal_approx(shin.rest),"rigid whole-body bob instead of real articulated action")
		check(view.cancel_action(),"action cannot cancel")
		for index in view.skeleton.get_bone_count():
			check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"action leaves stale bone")
	view.free()
	if not failures:
		print("TEST PASS: CinderChargeResourceTest %d" % checks)
	quit(1 if failures else 0)
