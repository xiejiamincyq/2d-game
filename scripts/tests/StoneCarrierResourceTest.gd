extends SceneTree
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const SCENE := "res://scenes/actors/native/stone_carrier_paper_v1.tscn"
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: StoneCarrierResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"original articulated large carrier missing")
	if failures:
		quit(1)
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/stone_carrier_paper_v1.json"))
	check(manifest is Dictionary and manifest.role=="large" and Validator.new().validate_entry(manifest).is_empty(),"large non-attack resource contract")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==17,"shoulder/backstone/shin articulation missing")
	check(view.body_rect.has_point(Vector2(-30,43)),"entrance shin/foot not covered by visual occlusion bounds")
	for clip in view.player.get_animation_list():
		check(str(clip) in ["idle","walk","hit","death","entrance"],"large attack gate bypassed")
	for path in ["Torso/ShoulderL/ArmL/ForearmL/HandL/SlamOrigin","Torso/ShoulderR/ArmR/ForearmR/HandR/SlamOrigin"]:
		check(view.skeleton.get_node_or_null(path) is Marker2D,"future hand mount missing")
	for clip in ["idle","walk","hit","entrance"]:
		check(view.sample_clip(clip,view.player.get_animation(clip).length*0.45),"required non-attack motion missing")
		check(view.position==Vector2.ZERO and view.rotation==0,"animation moves collision root")
		view.cancel_action()
		for index in 17:
			check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel doesn't restore joint")
	view.sample_clip("walk",0.25)
	check(absf(view.skeleton.get_node("Torso/LegL/ShinL").rotation)>0.05,"walk only bobs whole body")
	view.sample_clip("death",0.69)
	check(not view.cancel_action() and not view.sample_clip("idle",0),"death resurrects")
	view.free()
	if not failures:
		print("TEST PASS: StoneCarrierResourceTest %d" % checks)
	quit(1 if failures else 0)
