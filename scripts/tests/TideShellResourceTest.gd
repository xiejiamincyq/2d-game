extends SceneTree
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const SCENE := "res://scenes/actors/native/tide_shell_paper_v1.tscn"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: TideShellResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"independent crab boss skeleton missing")
	if failures:
		quit(1)
		return
	var entry = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/tide_shell_paper_v1.json"))
	check(entry is Dictionary and entry.role=="boss" and Validator.new().validate_entry(entry).is_empty(),"weighted opaque non-attack boss contract")
	if failures:
		quit(1)
		return
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==25,"independent carapace/eyes/claws/four legs missing")
	check(view.player.get_animation_list().size()==5,"large attack resource gate bypassed")
	for clip in view.player.get_animation_list():
		check(str(clip) in ["idle","walk","hit","entrance","death"],"premature large attack keys")
	for path in ["Torso/ShoulderL/ArmL/PincerL/ClawOrigin","Torso/ShoulderR/ArmR/PincerR/ClawOrigin","Torso/Carapace/RippleOrigin","Torso/Tail/WakeOrigin"]:
		check(view.skeleton.get_node_or_null(path) is Marker2D,"future claw/wave locator missing")
	for clip in ["idle","walk","hit","entrance"]:
		check(view.sample_clip(clip,view.player.get_animation(clip).length*0.45),"required non-attack sample missing")
		check(view.transform==Transform2D.IDENTITY,"animation owns physical root")
		view.cancel_action()
		for index in 25:
			check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel breaks rest joint")
	view.sample_clip("walk",0.2)
	for leg in ["FL","FR","BL","BR"]:
		check(absf(view.skeleton.get_node("Torso/Leg"+leg+"/Shin"+leg).rotation)>0.05,"crab leg remains rigid")
	check(view.skeleton.get_node("Torso/LegFL").rotation*view.skeleton.get_node("Torso/LegFR").rotation<0,"opposite front legs move in lockstep")
	view.sample_clip("idle",0.9)
	check(absf(view.skeleton.get_node("Torso/Head/EyeStalkL").rotation)>0.02,"eye stalk is painted rather than articulated")
	view.sample_clip("death",0.8)
	check(not view.cancel_action() and not view.sample_clip("idle",0),"death resurrects")
	view.free()
	if not failures:
		print("TEST PASS: TideShellResourceTest %d" % checks)
	quit(1 if failures else 0)
