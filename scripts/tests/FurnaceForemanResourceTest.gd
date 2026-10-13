extends SceneTree
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const SCENE := "res://scenes/actors/native/furnace_foreman_paper_v1.tscn"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: FurnaceForemanResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"original furnace boss resource missing")
	if failures:
		quit(1)
		return
	var entry = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/furnace_foreman_paper_v1.json"))
	check(entry is Dictionary and entry.role=="boss" and Validator.new().validate_entry(entry).is_empty(),"opaque weighted boss resource contract")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==23,"furnace/vents/bellows/visor not separately articulated")
	check(view.player.get_animation_list().size()==5,"large attack gate bypassed")
	for clip in view.player.get_animation_list():
		check(str(clip) in ["idle","walk","hit","entrance","death"],"premature large attack animation")
	for locator in ["Torso/Chest/Door/CoreOrigin","Torso/Chest/VentL/VentOrigin","Torso/Chest/VentR/VentOrigin","Torso/Chimney/ExhaustOrigin"]:
		check(view.skeleton.get_node_or_null(locator) is Marker2D,"future vent locator absent")
	for clip in ["idle","walk","hit","entrance"]:
		check(view.sample_clip(clip,view.player.get_animation(clip).length*0.45),"missing non-attack playback")
		check(view.transform==Transform2D.IDENTITY,"animation drives physical root")
		view.cancel_action()
		for index in 23:
			check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel leaves broken rest joint")
	view.sample_clip("walk",0.28)
	check(absf(view.skeleton.get_node("Torso/LegR/ShinR").rotation)>0.05,"walk is only whole-body bob")
	check(absf(view.skeleton.get_node("Torso/Chimney").rotation)>0.02,"chimney has no delayed secondary motion")
	view.sample_clip("idle",0.95)
	check(not view.skeleton.get_node("Torso/Bellows").scale.is_equal_approx(Vector2.ONE),"bellows not genuinely articulated")
	view.sample_clip("death",0.88)
	check(not view.cancel_action() and not view.sample_clip("idle",0),"death resurrects")
	view.free()
	if not failures:
		print("TEST PASS: FurnaceForemanResourceTest %d" % checks)
	quit(1 if failures else 0)
