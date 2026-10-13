extends SceneTree
## Resource-only: independent articulation and continuity, not combat proof.
const SCENE := "res://scenes/actors/native/bell_priest_paper_v2.tscn"
const MANIFEST := "res://docs/art/native-manifests/bell_priest_paper_v2.json"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const DURATIONS := {"bell":[0.24,0.42,0.54],"pendant":[0.22,0.56,0.66],"crown":[0.24,0.48,0.60]}
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BellPriestAttackResourceTest "+label)
func pose(view: Node) -> Array[Transform2D]:
	var result: Array[Transform2D] = []
	for index in 26: result.append(view.skeleton.get_bone(index).transform)
	return result
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE) and FileAccess.file_exists(MANIFEST),"independent priest v2 actions missing")
	if failures: quit(1); return
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(Validator.new().validate_entry(entry).is_empty(),"opaque weighted/checkpoint contract")
	var view = load(SCENE).instantiate(); root.add_child(view)
	check(view.skeleton.get_bone_count()==26 and view.player.get_animation_list().size()==14,"reviewed anatomy/base clips changed")
	check(view.player.get_animation_library("").resource_path==entry.motion_library,"external editable library missing")
	check(view.visual_bounds_padding==64,"reviewed thrown-pendant framing extent lost")
	var baseline: AnimationLibrary = load("res://assets/art/actors/native/bell_priest_motion_v1.tres")
	for clip in baseline.get_animation_list():
		var old: Animation = baseline.get_animation(clip); var current: Animation = view.player.get_animation(clip)
		check(current.length==old.length and current.loop_mode==old.loop_mode and current.get_track_count()==old.get_track_count(),"original new-native base clip changed")
		for track in old.get_track_count():
			check(current.track_get_type(track)==old.track_get_type(track) and current.track_get_path(track)==old.track_get_path(track) and current.track_get_key_count(track)==old.track_get_key_count(track),"base track changed")
			for key in old.track_get_key_count(track):
				check(current.track_get_key_time(track,key)==old.track_get_key_time(track,key) and current.track_get_key_value(track,key)==old.track_get_key_value(track,key),"base key changed")
	for action in DURATIONS:
		var prior: Array[Transform2D] = []
		for stage in ["warning","attack","recovery"]:
			var clip: String = action+"_"+stage; var motion: Animation = view.player.get_animation(clip)
			check(motion!=null and is_equal_approx(motion.length,DURATIONS[action][["warning","attack","recovery"].find(stage)]) and motion.loop_mode==Animation.LOOP_NONE,"duration/loop "+clip)
			if motion==null: continue
			for track in motion.get_track_count():
				var path := str(motion.track_get_path(track))
				check(motion.track_get_type(track)==Animation.TYPE_VALUE and path.begins_with("Facing/Skeleton2D/") and path.get_slice(":",1) in ["position","rotation","scale"] and view.get_node_or_null(path.get_slice(":",0)) is Bone2D,"event/root/opacity track")
			view.sample_clip(clip,0)
			if not prior.is_empty():
				for index in 26: check(view.skeleton.get_bone(index).transform.is_equal_approx(prior[index]),"stage boundary snaps "+clip)
			view.sample_clip(clip,motion.length); prior = pose(view)
			for left in [false,true]:
				view.cancel_action(); view.set_facing_left(left)
				check(view.sample_clip(clip,motion.length*0.55),"sampling "+clip)
				var changed := 0
				for index in 26:
					var bone: Bone2D = view.skeleton.get_bone(index)
					changed += 1 if not bone.transform.is_equal_approx(bone.rest) else 0
				check(changed>=8 and view.transform==Transform2D.IDENTITY and not view.get_node("Warning").visible,"root wobble/label instead of articulated action")
				view.cancel_action()
				for index in 26: check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel retains joint pose")
		for index in 26: check(prior[index].is_equal_approx(view.skeleton.get_bone(index).rest),"recovery lacks rest")
	for path in ["Torso/Bell/Clapper/BeatOrigin","Torso/Head/Crown/RecallOrigin","Torso/ArmL/ForearmL/HandL/ChainL/PendantL/PendantOrigin","Torso/ArmR/ForearmR/HandR/ChainR/PendantR/PendantOrigin"]:
		check(view.skeleton.get_node_or_null(path) is Marker2D,"semantic socket missing")
	view.set_facing_left(false); view.sample_clip("bell_attack",0.07)
	check(view.skeleton.get_node("Torso/Bell/Clapper").rotation>0.3 and view.skeleton.get_node("Torso/Bell").position.y>3,"bell/clapper lacks actual downstroke")
	view.sample_clip("pendant_attack",0.14)
	var thrown: Vector2 = view.skeleton.get_node("Torso/ArmL/ForearmL/HandL/ChainL/PendantL/PendantOrigin").global_position
	view.sample_clip("pendant_attack",0.5)
	check(thrown.distance_to(view.skeleton.get_node("Torso/ArmL/ForearmL/HandL/ChainL/PendantL/PendantOrigin").global_position)>20,"pendant never throws and recalls")
	view.sample_clip("crown_attack",0.08)
	check(view.skeleton.get_node("Torso/Head/Crown").position.y<-24 and view.skeleton.get_node("Torso/RibsL").rotation<-0.1 and view.skeleton.get_node("Torso/RibsR").rotation>0.1,"crown/rib release absent")
	check(view.player.callback_mode_process==AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,"second autonomous action clock")
	view.sample_clip("death",0.9); check(not view.cancel_action() and not view.sample_clip("bell_attack",0),"death resurrects attack")
	view.free()
	if not failures: print("TEST PASS: BellPriestAttackResourceTest %d"%checks)
	quit(1 if failures else 0)
