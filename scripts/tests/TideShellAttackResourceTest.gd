extends SceneTree
const SCENE := "res://scenes/actors/native/tide_shell_paper_v2.tscn"
const MANIFEST := "res://docs/art/native-manifests/tide_shell_paper_v2.json"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const DURATIONS := {"ripple":[0.28,0.72,0.60],"pincer":[0.24,0.36,0.58],"salt":[0.26,0.18,0.62]}
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: TideShellAttackResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE) and FileAccess.file_exists(MANIFEST),"versioned tide-shell actions missing")
	if failures: quit(1); return
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(Validator.new().validate_entry(entry).is_empty(),"opaque native resource/checkpoint invalid")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==25 and view.player.get_animation_list().size()==14,"covered anatomy/base motions not preserved")
	check(view.player.get_animation_library("").resource_path==entry.motion_library,"library is not an external editable resource")
	var at: Transform2D = view.transform
	for action in DURATIONS:
		for stage in ["warning","attack","recovery"]:
			var clip: String = action+"_"+stage
			check(view.player.has_animation(clip),"missing "+clip)
			if not view.player.has_animation(clip): continue
			var animation: Animation = view.player.get_animation(clip)
			check(is_equal_approx(animation.length,DURATIONS[action][["warning","attack","recovery"].find(stage)]) and animation.loop_mode==Animation.LOOP_NONE,"duration/loop mismatch")
			for track in animation.get_track_count():
				check(animation.track_get_type(track)==Animation.TYPE_VALUE and str(animation.track_get_path(track)).begins_with("Facing/Skeleton2D/"),"event/root damage track")
			for left in [false,true]:
				view.cancel_action()
				view.set_facing_left(left)
				check(view.sample_clip(clip,animation.length*0.55),"sampling failed")
				var changed := 0
				for index in 25:
					var bone: Bone2D = view.skeleton.get_bone(index)
					changed += 1 if not bone.transform.is_equal_approx(bone.rest) else 0
				check(changed>=6 and view.transform==at,"whole-body wobble or physical root mutation")
				check(not view.get_node("Warning").visible,"laboratory marker leaks into combat")
				check(view.cancel_action(),"cancel rejected")
				for index in 25:
					var bone: Bone2D = view.skeleton.get_bone(index)
					check(bone.transform.is_equal_approx(bone.rest),"cancel leaves residual joint")
	for path in ["Torso/Carapace/RippleOrigin","Torso/ShoulderL/ArmL/PincerL/ClawOrigin","Torso/ShoulderR/ArmR/PincerR/ClawOrigin","Torso/Head/Jaw/SaltOrigin"]:
		check(view.skeleton.get_node_or_null(path) is Marker2D,"action socket absent "+path)
	view.set_facing_left(false)
	view.sample_clip("pincer_attack",0.04)
	var first_left: float = view.skeleton.get_node("Torso/ShoulderL/ArmL").rotation
	var first_right: float = view.skeleton.get_node("Torso/ShoulderR/ArmR").rotation
	view.sample_clip("pincer_attack",0.26)
	check(absf(first_left-view.skeleton.get_node("Torso/ShoulderL/ArmL").rotation)>0.25 and absf(first_right-view.skeleton.get_node("Torso/ShoulderR/ArmR").rotation)>0.25,"double-pincer active lacks alternating strokes")
	view.sample_clip("salt_attack",0.12)
	check(absf(view.skeleton.get_node("Torso/Head/Jaw").rotation)>0.15,"salt does not articulate jaw")
	check(view.player.callback_mode_process==AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,"second autonomous attack clock")
	view.sample_clip("death",0.8)
	check(not view.cancel_action() and not view.sample_clip("pincer_attack",0),"death resurrects attack")
	view.free()
	if not failures: print("TEST PASS: TideShellAttackResourceTest %d" % checks)
	quit(1 if failures else 0)
