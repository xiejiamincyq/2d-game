extends SceneTree
const SCENE := "res://scenes/actors/native/circling_shade_paper_v1.tscn"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CirclingShadeResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"original hood/cape/hook rig absent")
	if failures:
		quit(1)
		return
	var entry = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/circling_shade_paper_v1.json"))
	check(entry is Dictionary and Validator.new().validate_entry(entry).is_empty(),"weighted opaque pure-visual contract fails")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==18,"cape/hook/pendant chains incomplete")
	for clip in ["idle","walk","warning","attack","hit","death"]:
		view.sample_clip(clip,0)
		var before: Transform2D = view.skeleton.get_bone(0).transform
		view.sample_clip(clip,view.player.get_animation(clip).length*0.45)
		check(not before.is_equal_approx(view.skeleton.get_bone(0).transform),"static pose: "+clip)
		check(view.transform.is_equal_approx(Transform2D.IDENTITY) and view.modulate.a==1,"clip changes physics root/opacity")
		if clip!="death":
			check(view.cancel_action(),"cannot cancel live pose")
			for index in view.skeleton.get_bone_count():
				check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel leaves bent cape/hook")
	check(not view.sample_clip("walk",0) and not view.cancel_action(),"death resurrects")
	view.free()
	if not failures: print("TEST PASS: CirclingShadeResourceTest %d" % checks)
	quit(1 if failures else 0)
