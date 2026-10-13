extends SceneTree
const SCENE := "res://scenes/actors/native/salt_needler_paper_v1.tscn"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: SaltNeedlerResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(FileAccess.file_exists(SCENE),"new original needle shooter rig missing")
	if failures:
		quit(1)
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/salt_needler_paper_v1.json"))
	check(manifest is Dictionary and Validator.new().validate_entry(manifest).is_empty(),"native dependency / weighted original geometry contract")
	var actor = load(SCENE).instantiate()
	root.add_child(actor)
	check(actor.skeleton.get_bone_count()==16,"not real hand gun / articulated shins")
	var muzzle: Node2D = actor.get_node("Facing/Skeleton2D/Torso/ArmR/ForearmR/HandR/NeedleGun/Muzzle")
	check(muzzle != null and muzzle.get_parent() is Bone2D,"gun muzzle not attached to hand chain")
	for clip in ["idle","walk","warning","attack","hit","death"]:
		check(actor.sample_clip(clip,actor.player.get_animation(clip).length*0.45),"new action absent "+clip)
		check(actor.position==Vector2.ZERO and actor.rotation==0 and actor.scale==Vector2.ONE,"animation controls gameplay root")
		var moved := false
		for index in actor.skeleton.get_bone_count():
			moved = moved or not actor.skeleton.get_bone(index).transform.is_equal_approx(actor.skeleton.get_bone(index).rest)
		check(moved,"static resource not articulated "+clip)
		if clip != "death":
			actor.cancel_action()
			for index in actor.skeleton.get_bone_count():
				check(actor.skeleton.get_bone(index).transform.is_equal_approx(actor.skeleton.get_bone(index).rest),"stale pose after cancellation")
	check(not actor.cancel_action() and not actor.sample_clip("walk",0.1),"dead rig resumes combat")
	actor.free()
	if not failures:
		print("TEST PASS: SaltNeedlerResourceTest %d" % checks)
	quit(1 if failures else 0)
