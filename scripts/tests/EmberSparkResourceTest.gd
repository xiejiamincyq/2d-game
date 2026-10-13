extends SceneTree
const SCENE := "res://scenes/actors/native/ember_spark_paper_v1.tscn"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: EmberSparkResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"new furnace scatterer skeleton missing")
	if failures:
		quit(1)
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/ember_spark_paper_v1.json"))
	check(manifest is Dictionary and Validator.new().validate_entry(manifest).is_empty(),"editable skin/motion dependency contract fails")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==16,"articulated furnace/nozzle/bellows/feet incomplete")
	check(view.has_node("Facing/Skeleton2D/Torso/ArmR/Nozzle/Muzzle"),"hand-chain emitter absent")
	for clip in ["idle","walk","warning","attack","hit","death"]:
		view.sample_clip(clip,0)
		var before: Transform2D = view.skeleton.get_bone(0).transform
		view.sample_clip(clip,view.player.get_animation(clip).length*0.45)
		check(not view.skeleton.get_bone(0).transform.is_equal_approx(before) or not view.skeleton.get_node("Torso/Bellows").transform.is_equal_approx(view.skeleton.get_node("Torso/Bellows").rest),"clip lacks new articulated motion: "+clip)
		check(view.transform.is_equal_approx(Transform2D.IDENTITY) and view.modulate.a==1,"clip controls physical root/whole-body alpha")
		if clip!="death":
			check(view.cancel_action(),"live action cannot cancel")
			for i in view.skeleton.get_bone_count():
				check(view.skeleton.get_bone(i).transform.is_equal_approx(view.skeleton.get_bone(i).rest),"cancel retains an articulated offset")
	check(not view.cancel_action() and not view.sample_clip("walk",0.5),"terminal animation revives")
	view.free()
	if not failures:
		print("TEST PASS: EmberSparkResourceTest %d" % checks)
	quit(1 if failures else 0)
