extends SceneTree
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const SCENE := "res://scenes/actors/native/vine_guard_paper_v1.tscn"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VineGuardResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"original first-chapter boss rig missing")
	if failures:
		quit(1)
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/vine_guard_paper_v1.json"))
	check(manifest is Dictionary and manifest.role=="boss" and Validator.new().validate_entry(manifest).is_empty(),"boss resource contract")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==22,"crown/vines/mask/knee articulation absent")
	check(view.player.get_animation_list().size()==5,"all-character gate bypassed")
	for clip in view.player.get_animation_list():
		check(str(clip) in ["idle","walk","hit","death","entrance"],"premature boss attack art")
	for path in ["Torso/ShoulderL/ArmL/ForearmL/HandL/VineOrigin","Torso/ShoulderR/ArmR/ForearmR/HandR/VineOrigin","Torso/Head/Crown/SeedOrigin"]:
		check(view.skeleton.get_node_or_null(path) is Marker2D,"future emitter locator absent")
	for clip in ["idle","walk","hit","entrance"]:
		check(view.sample_clip(clip,view.player.get_animation(clip).length*0.45),"non-attack sample absent")
		check(view.position==Vector2.ZERO and view.rotation==0 and view.scale==Vector2.ONE,"animation moves physical root")
		view.cancel_action()
		for index in 22:
			check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel leaves stale joint")
	view.sample_clip("walk",0.3)
	check(absf(view.skeleton.get_node("Torso/LegL/ShinL").rotation)>0.05,"only whole-body bob")
	check(absf(view.skeleton.get_node("Torso/VineL/TipL").rotation)>0.05,"hanging vine not independently animated")
	view.sample_clip("death",0.8)
	check(not view.cancel_action() and not view.sample_clip("idle",0),"death resurrects")
	view.free()
	if not failures:
		print("TEST PASS: VineGuardResourceTest %d" % checks)
	quit(1 if failures else 0)
