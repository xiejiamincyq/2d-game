extends SceneTree
const SCENE := "res://scenes/actors/native/root_commander_paper_v2.tscn"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: RootCommanderAttackResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"new native staff/core action resource missing")
	if failures:
		quit(1)
		return
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/root_commander_paper_v2.json"))
	check(Validator.new().validate_entry(entry).is_empty(),"explicit post-rig commander contract rejected")
	var wrong := entry.duplicate(true)
	wrong.erase("rig_checkpoint")
	check(not Validator.new().validate_entry(wrong).is_empty(),"large attack permitted by default")
	wrong = entry.duplicate(true)
	wrong.required_clips.erase("burst_warning")
	check(not Validator.new().validate_entry(wrong).is_empty(),"unreviewed hidden attack accepted")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==23 and view.player.get_animation_list().size()==11,"new actions change topology or incomplete library")
	check(view.player.get_animation_library("").resource_path=="res://assets/art/actors/native/root_commander_motion_v2.tres","actions lack external editable library")
	for pair in [["melee_warning",0.32],["melee_attack",0.12],["melee_recovery",0.43],["burst_warning",0.9],["burst_attack",0.3],["command",0.35]]:
		check(view.player.has_animation(pair[0]),"new action missing "+pair[0])
		if not view.player.has_animation(pair[0]): continue
		var motion: Animation = view.player.get_animation(pair[0])
		check(is_equal_approx(motion.length,pair[1]) and motion.loop_mode==Animation.LOOP_NONE,"action duration/loop disagrees with combat")
		view.cancel_action()
		var poses: Array[Transform2D] = []
		for i in 23: poses.append(view.skeleton.get_bone(i).transform)
		check(view.sample_clip(pair[0],motion.length*0.6),"action sampling rejected")
		var changed := 0
		for i in 23:
			if not poses[i].is_equal_approx(view.skeleton.get_bone(i).transform): changed+=1
		check(changed>=3 and view.position==Vector2.ZERO and view.rotation==0,"attack only bobs or transforms physical root")
		check(view.cancel_action(),"action not cancelable")
		for i in 23: check(view.skeleton.get_bone(i).transform.is_equal_approx(view.skeleton.get_bone(i).rest),"cancel leaves residual joint")
		for track in motion.get_track_count():
			check(motion.track_get_type(track)==Animation.TYPE_VALUE and str(motion.track_get_path(track)).begins_with("Facing/Skeleton2D/"),"action has damage/event/collision track")
	check(view.skeleton.get_node_or_null("Torso/Core/CommandOrigin") is Marker2D,"radial core emitter absent")
	check(view.skeleton.get_node_or_null("Torso/ArmR/ForearmR/HandR/Staff/StaffOrigin") is Marker2D,"staff socket absent")
	view.sample_clip("death",0.87)
	check(not view.cancel_action() and not view.sample_clip("burst_attack",0),"death resumes fire")
	view.free()
	if not failures: print("TEST PASS: RootCommanderAttackResourceTest %d" % checks)
	quit(1 if failures else 0)
