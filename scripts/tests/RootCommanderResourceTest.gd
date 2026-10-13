extends SceneTree
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const SCENE := "res://scenes/actors/native/root_commander_paper_v1.tscn"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: RootCommanderResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"original overseer skeleton missing")
	if failures:
		quit(1)
		return
	var entry = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/root_commander_paper_v1.json"))
	check(entry is Dictionary and entry.role=="large" and Validator.new().validate_entry(entry).is_empty(),"opaque non-attack large contract")
	if failures:
		quit(1)
		return
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==23,"hood/horns/mantles/staff/seed pack incomplete")
	check(view.player.get_animation_list().size()==5,"large attack gate bypassed")
	for clip in view.player.get_animation_list():
		check(str(clip) in ["idle","walk","hit","entrance","death"],"premature large attack keys")
	for path in ["Torso/Core/CommandOrigin","Torso/SeedPack/ReinforcementOrigin","Torso/ArmR/ForearmR/HandR/Staff/StaffOrigin"]:
		check(view.skeleton.get_node_or_null(path) is Marker2D,"future command locator absent")
	for clip in ["idle","walk","hit","entrance"]:
		view.sample_clip(clip,view.player.get_animation(clip).length*0.45)
		check(view.transform==Transform2D.IDENTITY,"animation moves physical root")
		view.cancel_action()
		for index in 23:
			check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel leaves distorted rest joint")
	view.sample_clip("walk",0.26)
	check(absf(view.skeleton.get_node("Torso/LegR/ShinR").rotation)>0.05,"gait is only whole-body bob")
	check(absf(view.skeleton.get_node("Torso/ArmR/ForearmR/HandR/Staff").rotation)<0.16,"held staff swings implausibly around body")
	view.sample_clip("idle",0.9)
	check(absf(view.skeleton.get_node("Torso/Head/HornL").rotation)>0.02,"horn/crown rigid")
	view.sample_clip("death",0.8)
	check(not view.cancel_action() and not view.sample_clip("idle",0),"dead resource resurrects")
	view.free()
	if not failures:
		print("TEST PASS: RootCommanderResourceTest %d" % checks)
	quit(1 if failures else 0)
