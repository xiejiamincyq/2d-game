extends SceneTree
const SCENE := "res://scenes/actors/native/flanking_crab_paper_v1.tscn"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: FlankingCrabResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"original four-legged crab resource missing")
	if failures:
		quit(1)
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/flanking_crab_paper_v1.json"))
	check(manifest is Dictionary and Validator.new().validate_entry(manifest).is_empty(),"editable weighted skin/clip contract fails")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==20,"four legs/eyes/two hinged pincers incomplete")
	for side in ["L","R"]:
		check(view.has_node("Facing/Skeleton2D/Torso/Arm"+side+"/Claw"+side+"/Jaw"+side+"/Tip"),"real hinged pincer locator missing")
	for clip in ["idle","walk","warning","attack","hit","death"]:
		view.sample_clip(clip,0)
		var before: Transform2D = view.skeleton.get_bone(0).transform
		view.sample_clip(clip,view.player.get_animation(clip).length*0.45)
		check(not before.is_equal_approx(view.skeleton.get_bone(0).transform) or absf(view.skeleton.get_node("Torso/ArmR/ClawR/JawR").rotation)>0.01,"motion static: "+clip)
		check(view.transform.is_equal_approx(Transform2D.IDENTITY) and view.modulate.a==1,"animation moves physics root/makes body translucent")
		if clip!="death":
			check(view.cancel_action(),"live clip fails to cancel")
			for index in view.skeleton.get_bone_count():
				check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"canceled pincer/leg retains offset")
	check(not view.cancel_action() and not view.sample_clip("walk",0.1),"dead crab resurrects")
	view.free()
	if not failures:
		print("TEST PASS: FlankingCrabResourceTest %d" % checks)
	quit(1 if failures else 0)
