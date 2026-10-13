extends SceneTree
## Catches lost hanging-chain/clapper articulation, opaque weights and roots.
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const SCENE := "res://scenes/actors/native/bell_priest_paper_v1.tscn"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: BellPriestResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"independent bell priest skeleton missing")
	if failures:
		quit(1)
		return
	var entry = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/bell_priest_paper_v1.json"))
	check(entry is Dictionary and entry.role=="boss" and Validator.new().validate_entry(entry).is_empty(),"opaque weighted non-attack boss contract")
	if failures:
		quit(1)
		return
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==26,"bell/clapper/ribs/chain pendants not separately weighted")
	check(view.player.get_animation_list().size()==5,"large attack gate bypassed")
	for clip in view.player.get_animation_list():
		check(str(clip) in ["idle","walk","hit","entrance","death"],"premature large attack resource")
	for path in ["Torso/Bell/Clapper/BeatOrigin","Torso/Head/Crown/RecallOrigin","Torso/ArmL/ForearmL/HandL/ChainL/PendantL/PendantOrigin","Torso/ArmR/ForearmR/HandR/ChainR/PendantR/PendantOrigin"]:
		check(view.skeleton.get_node_or_null(path) is Marker2D,"future resonance locator missing")
	for clip in ["idle","walk","hit","entrance"]:
		check(view.sample_clip(clip,view.player.get_animation(clip).length*0.45),"non-attack sample missing")
		check(view.transform==Transform2D.IDENTITY,"animation owns collision root")
		view.cancel_action()
		for index in 26:
			check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel leaves distorted rest pose")
	view.sample_clip("walk",0.3)
	check(absf(view.skeleton.get_node("Torso/LegR/ShinR").rotation)>0.05,"gait reduced to whole-body bob")
	check(absf(view.skeleton.get_node("Torso/ArmL/ForearmL/HandL/ChainL/PendantL").rotation)>0.04,"pendant has no independent lag")
	view.sample_clip("idle",0.9)
	check(absf(view.skeleton.get_node("Torso/Bell/Clapper").rotation)>0.02,"clapper is rigid decoration")
	check(view.skeleton.get_node("Torso/RibsL").rotation*view.skeleton.get_node("Torso/RibsR").rotation<0,"rib plates don't articulate relative to torso")
	view.sample_clip("death",0.9)
	check(not view.cancel_action() and not view.sample_clip("idle",0),"dead resource resurrects")
	view.free()
	if not failures:
		print("TEST PASS: BellPriestResourceTest %d" % checks)
	quit(1 if failures else 0)
