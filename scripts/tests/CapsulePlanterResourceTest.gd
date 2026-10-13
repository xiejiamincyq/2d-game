extends SceneTree
const SCENE := "res://scenes/actors/native/capsule_planter_paper_v1.tscn"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CapsulePlanterResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"original bottle-rack planter rig absent")
	if failures:
		quit(1)
		return
	var entry = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/capsule_planter_paper_v1.json"))
	check(entry is Dictionary and Validator.new().validate_entry(entry).is_empty(),"weighted opaque resource contract fails")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==20,"bottle caps/clamp/shin chains incomplete")
	check(view.get_node_or_null("Facing/Skeleton2D/Torso/ArmR/ForearmR/ClampR/Payload/Release") is Marker2D,"planting hand locator missing")
	for clip in ["idle","walk","warning","attack","hit","death"]:
		view.sample_clip(clip,0)
		var before: Transform2D = view.skeleton.get_bone(0).transform
		view.sample_clip(clip,view.player.get_animation(clip).length*0.45)
		check(not before.is_equal_approx(view.skeleton.get_bone(0).transform),"whole character motion static: "+clip)
		check(view.transform.is_equal_approx(Transform2D.IDENTITY) and view.modulate.a==1,"motion changes physical root or opacity")
		if clip!="death":
			check(view.cancel_action(),"living planter cannot cancel")
			for index in view.skeleton.get_bone_count():
				check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancelled rig retains offset")
	check(not view.sample_clip("walk",0) and not view.cancel_action(),"dead planter resurrects")
	view.free()
	if not failures: print("TEST PASS: CapsulePlanterResourceTest %d" % checks)
	quit(1 if failures else 0)
