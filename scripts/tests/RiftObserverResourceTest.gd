extends SceneTree
## Catches rigid rim/iris/tripod rigs, translucent weights and root ownership.
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const SCENE := "res://scenes/actors/native/rift_observer_paper_v1.tscn"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: RiftObserverResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"independent observer skeleton missing")
	if failures:
		quit(1)
		return
	var entry = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/rift_observer_paper_v1.json"))
	check(entry is Dictionary and entry.role=="boss" and Validator.new().validate_entry(entry).is_empty(),"opaque weighted non-attack resource contract")
	if failures:
		quit(1)
		return
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==30,"iris/rim segments/probes/tripod not separately weighted")
	check(view.player.get_animation_list().size()==5,"large attack gate bypassed")
	for clip in view.player.get_animation_list():
		check(str(clip) in ["idle","walk","hit","entrance","death"],"premature large attack resource")
	for path in ["Torso/Lens/Pupil/AimOrigin","Torso/ScopeArmL/ElbowL/ProbeL/SensorOrigin","Torso/ScopeArmR/ElbowR/ProbeR/SensorOrigin","Torso/Beacon/PhaseOrigin"]:
		check(view.skeleton.get_node_or_null(path) is Marker2D,"future observation locator absent")
	for clip in ["idle","walk","hit","entrance"]:
		check(view.sample_clip(clip,view.player.get_animation(clip).length*0.45),"non-attack sample absent")
		check(view.transform==Transform2D.IDENTITY,"animation transforms collision root")
		view.cancel_action()
		for index in 30:
			check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel leaves distorted rest pose")
	view.sample_clip("walk",0.24)
	for leg in ["L","R","B"]:
		check(absf(view.skeleton.get_node("Torso/Leg"+leg+"/Shin"+leg).rotation)>0.05,"tripod knee remains rigid")
	check(view.skeleton.get_node("Torso/LegL").rotation*view.skeleton.get_node("Torso/LegR").rotation<0,"side legs move in lockstep")
	view.sample_clip("idle",1.1)
	check(absf(view.skeleton.get_node("Torso/RingHub/SegmentA").rotation)>0.02,"rim is rigid painted ornament")
	check(view.skeleton.get_node("Torso/Lens/IrisL").position.distance_to(view.skeleton.get_node("Torso/Lens/IrisL").rest.origin)>1,"iris lacks independent aperture movement")
	view.sample_clip("death",0.91)
	check(not view.cancel_action() and not view.sample_clip("idle",0),"dead view resurrects")
	view.free()
	if not failures:
		print("TEST PASS: RiftObserverResourceTest %d" % checks)
	quit(1 if failures else 0)
