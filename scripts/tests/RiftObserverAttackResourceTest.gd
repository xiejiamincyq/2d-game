extends SceneTree
## Original observer v2 resource articulation; not actual Boss combat proof.
const SCENE := "res://scenes/actors/native/rift_observer_paper_v2.tscn"
const MANIFEST := "res://docs/art/native-manifests/rift_observer_paper_v2.json"
const BASE_SCENE := "res://scenes/actors/native/rift_observer_paper_v1.tscn"
const BASE_LIBRARY := "res://assets/art/actors/native/rift_observer_motion_v1.tres"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const DURATIONS := {"beam":[0.30,0.12,0.45],"probes":[0.32,0.56,0.52],"refract":[0.30,0.60,0.60]}
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverAttackResourceTest "+label)
func pose(view: Node) -> Array[Transform2D]:
	var result: Array[Transform2D] = []
	for index in 30: result.append(view.skeleton.get_bone(index).transform)
	return result
func _initialize() -> void: call_deferred("run")
func run() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE) and FileAccess.file_exists(MANIFEST),"independent observer v2 resource/manifest missing")
	if failures: quit(1); return
	var frozen := {BASE_SCENE:"08fe69c6543d1e691256b800cc3b5a8560e84fa751d02d40852456099be6cbe8",BASE_LIBRARY:"0525621d5092253b121f524e74982267c77227af6ef908a3bc2b303e286ac4ba"}
	for path in frozen: check(FileAccess.get_sha256(path)==frozen[path],"baseline already changed")
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(Validator.new().validate_entry(entry).is_empty(),"opaque weighted/new reviewed checkpoint contract")
	var view = load(SCENE).instantiate(); root.add_child(view)
	check(view.visual_bounds_padding==25,"measured continuous probe framing guard missing")
	check(view.skeleton.get_bone_count()==30 and view.player.get_animation_list().size()==14,"reviewed anatomy or clip roster changed")
	check(view.player.get_animation_library("").resource_path==entry.motion_library,"external editable library absent")
	var baseline: AnimationLibrary = load(BASE_LIBRARY)
	for clip in baseline.get_animation_list():
		var old: Animation = baseline.get_animation(clip); var current: Animation = view.player.get_animation(clip)
		check(current!=null,"original native base clip absent")
		if current==null: continue
		check(current.length==old.length and current.loop_mode==old.loop_mode and current.get_track_count()==old.get_track_count(),"baseline duration/loop/track changed")
		for track in old.get_track_count():
			check(current.track_get_type(track)==old.track_get_type(track) and current.track_get_path(track)==old.track_get_path(track) and current.track_get_key_count(track)==old.track_get_key_count(track),"baseline track changed")
			for key in old.track_get_key_count(track):
				check(current.track_get_key_time(track,key)==old.track_get_key_time(track,key) and current.track_get_key_value(track,key)==old.track_get_key_value(track,key),"baseline key changed")
	for action in DURATIONS:
		var previous: Array[Transform2D] = []
		for stage in ["warning","attack","recovery"]:
			var clip: String = action+"_"+stage; var motion: Animation = view.player.get_animation(clip)
			check(motion!=null,"action stage absent "+clip)
			if motion==null: continue
			check(is_equal_approx(motion.length,DURATIONS[action][["warning","attack","recovery"].find(stage)]) and motion.loop_mode==Animation.LOOP_NONE,"finite duration/loop "+clip)
			for track in motion.get_track_count():
				var path := str(motion.track_get_path(track))
				check(motion.track_get_type(track)==Animation.TYPE_VALUE and path.begins_with("Facing/Skeleton2D/") and path.get_slice(":",1) in ["position","rotation","scale"] and view.get_node_or_null(path.get_slice(":",0)) is Bone2D,"event/root/opacity track "+clip)
			view.set_facing_left(false); view.sample_clip(clip,0)
			if not previous.is_empty():
				for index in 30: check(view.skeleton.get_bone(index).transform.is_equal_approx(previous[index]),"stage discontinuity "+clip)
			view.sample_clip(clip,motion.length); previous = pose(view)
			for left in [false,true]:
				view.cancel_action(); view.set_facing_left(left)
				check(view.sample_clip(clip,motion.length*0.55),"sample "+clip)
				var changed := 0
				for index in 30:
					var bone: Bone2D = view.skeleton.get_bone(index)
					changed += 1 if not bone.transform.is_equal_approx(bone.rest) else 0
				check(changed>=8 and view.transform==Transform2D.IDENTITY and not view.get_node("Warning").visible,"rigid body/root or label masquerades as action "+clip)
				view.cancel_action()
				for index in 30: check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel residual "+clip)
		for index in 30: check(previous[index].is_equal_approx(view.skeleton.get_bone(index).rest),"recovery does not settle")
	for path in ["Torso/Lens/Pupil/AimOrigin","Torso/ScopeArmL/ElbowL/ProbeL/SensorOrigin","Torso/ScopeArmR/ElbowR/ProbeR/SensorOrigin","Torso/Beacon/PhaseOrigin"]:
		check(view.skeleton.get_node_or_null(path) is Marker2D,"actual socket absent")
	view.set_facing_left(false); view.sample_clip("beam_warning",DURATIONS.beam[0])
	var left_iris: Bone2D = view.skeleton.get_node("Torso/Lens/IrisL")
	var right_iris: Bone2D = view.skeleton.get_node("Torso/Lens/IrisR")
	check(left_iris.position.x>left_iris.rest.origin.x+2 and right_iris.position.x<right_iris.rest.origin.x-2,"iris does not independently focus")
	view.sample_clip("beam_attack",DURATIONS.beam[1]*0.2)
	check(left_iris.position.x<left_iris.rest.origin.x-1 and right_iris.position.x>right_iris.rest.origin.x+1,"iris lacks active aperture")
	for side in ["L","R"]:
		view.sample_clip("probes_attack",DURATIONS.probes[1]*(0.18 if side=="L" else 0.46))
		var socket: Marker2D = view.skeleton.get_node("Torso/ScopeArm"+side+"/Elbow"+side+"/Probe"+side+"/SensorOrigin")
		var extended: Vector2 = socket.global_position
		view.sample_clip("probes_attack",DURATIONS.probes[1]*0.90)
		check(extended.distance_to(socket.global_position)>12,"probe does not extend/retract "+side)
		check(absf(view.skeleton.get_node("Torso/ScopeArm"+side+"/Elbow"+side).rotation)>0.01,"probe uses rigid arm "+side)
	view.sample_clip("refract_attack",DURATIONS.refract[1]*0.18)
	var a: Bone2D = view.skeleton.get_node("Torso/RingHub/SegmentA")
	var b: Bone2D = view.skeleton.get_node("Torso/RingHub/SegmentB")
	check(a.rotation*b.rotation<0 and absf(a.rotation)>0.05 and absf(b.rotation)>0.05,"rim does not articulate staggered sections")
	check(absf(view.skeleton.get_node("Torso/RingHub").rotation)<0.1 and view.get_node("Facing").rotation==0,"whole-ring or whole-body turntable")
	check(view.player.callback_mode_process==AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,"second animation clock")
	view.sample_clip("death",0.9); check(not view.cancel_action() and not view.sample_clip("beam_attack",0),"death resurrects action")
	view.free(); await process_frame
	for path in frozen: check(FileAccess.get_sha256(path)==frozen[path],"baseline overwritten by test")
	if not failures: print("TEST PASS: RiftObserverAttackResourceTest %d"%checks)
	quit(1 if failures else 0)
