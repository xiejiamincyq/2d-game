extends SceneTree
const SCENE := "res://scenes/actors/native/vine_guard_paper_v2.tscn"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VineGuardAttackResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"new first-chapter attack motions absent")
	if failures: quit(1); return
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/vine_guard_paper_v2.json"))
	check(Validator.new().validate_entry(entry).is_empty(),"explicit post-rig Boss proof rejected")
	var wrong := entry.duplicate(true)
	wrong.erase("rig_checkpoint")
	check(not Validator.new().validate_entry(wrong).is_empty(),"new Boss attacks accepted by default")
	wrong = entry.duplicate(true)
	wrong.required_clips.erase("roots_warning")
	check(not Validator.new().validate_entry(wrong).is_empty(),"hidden undeclared attack accepted")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==22 and view.player.get_animation_list().size()==14,"covered anatomy changed or clips incomplete")
	check(view.player.get_animation_library("").resource_path=="res://assets/art/actors/native/vine_guard_motion_v2.tres","animation is not editable external native library")
	for pair in [["lash_warning",0.30],["lash_attack",0.14],["lash_recovery",0.55],["roots_warning",0.40],["roots_attack",0.18],["roots_recovery",0.50],["seeds_warning",0.35],["seeds_attack",0.12],["seeds_recovery",0.65]]:
		var clip: String = pair[0]
		check(view.player.has_animation(clip),"missing motion "+clip)
		if not view.player.has_animation(clip): continue
		var motion: Animation = view.player.get_animation(clip)
		check(is_equal_approx(motion.length,pair[1]) and motion.loop_mode==Animation.LOOP_NONE,"combat/motion duration mismatch "+clip)
		view.cancel_action()
		var poses: Array[Transform2D] = []
		for i in 22: poses.append(view.skeleton.get_bone(i).transform)
		view.sample_clip(clip,motion.length*0.6)
		var changed := 0
		for i in 22: changed += 1 if not poses[i].is_equal_approx(view.skeleton.get_bone(i).transform) else 0
		check(changed>=3 and view.position==Vector2.ZERO and view.rotation==0,"only bobbing/no native articulation "+clip)
		check(view.cancel_action(),"cannot cancel "+clip)
		for i in 22: check(view.skeleton.get_bone(i).transform.is_equal_approx(view.skeleton.get_bone(i).rest),"residual bone after cancel")
		for track in motion.get_track_count(): check(motion.track_get_type(track)==Animation.TYPE_VALUE and str(motion.track_get_path(track)).begins_with("Facing/Skeleton2D/"),"damage/event/physical-root animation track")
	check(view.skeleton.get_node_or_null("Torso/Head/Crown/SeedOrigin") is Marker2D,"actual crown emitter absent")
	view.sample_clip("death",0.88)
	check(not view.cancel_action() and not view.sample_clip("lash_attack",0),"dead Boss resurrects")
	view.free()
	if not failures: print("TEST PASS: VineGuardAttackResourceTest %d"%checks)
	quit(1 if failures else 0)
