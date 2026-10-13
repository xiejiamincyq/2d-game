extends SceneTree
const SCENE := "res://scenes/actors/native/furnace_foreman_paper_v2.tscn"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const Gate = preload("res://scripts/art/NativeRigCheckpoint.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: FurnaceForemanAttackResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"separately versioned furnace native attacks absent")
	if failures: quit(1); return
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/furnace_foreman_paper_v2.json"))
	check(Validator.new().validate_entry(entry).is_empty(),"explicit furnace checkpoint/geometry invalid")
	var wrong := entry.duplicate(true); wrong.rig_checkpoint = "res://docs/art/native-checkpoints/vine_guard_attack_v1.json"
	check(not Gate.new().validate_entry(wrong).is_empty(),"first Boss approval silently approves furnace")
	wrong = entry.duplicate(true); wrong.erase("rig_checkpoint")
	check(not Validator.new().validate_entry(wrong).is_empty(),"no-checkpoint furnace attacks accepted")
	var view = load(SCENE).instantiate(); root.add_child(view)
	check(view.skeleton.get_bone_count()==23 and view.player.get_animation_list().size()==14,"covered furnace anatomy changed")
	check(view.player.get_animation_library("").resource_path==entry.motion_library,"not editable external library")
	for pair in [["jet_warning",0.24],["jet_attack",0.18],["jet_recovery",0.55],["ram_warning",0.28],["ram_attack",0.5],["ram_recovery",0.7],["vents_warning",0.32],["vents_attack",0.45],["vents_recovery",0.6]]:
		var clip: String = pair[0]
		check(view.player.has_animation(clip),"missing "+clip)
		if not view.player.has_animation(clip): continue
		var motion: Animation = view.player.get_animation(clip)
		check(is_equal_approx(motion.length,pair[1]) and motion.loop_mode==Animation.LOOP_NONE,"combat/motion duration mismatch "+clip)
		view.cancel_action(); view.sample_clip(clip,motion.length*0.6)
		var changed := 0
		for index in 23:
			var bone: Bone2D = view.skeleton.get_bone(index)
			changed += 1 if not bone.transform.is_equal_approx(bone.rest) else 0
		check(changed>=3 and view.position==Vector2.ZERO and view.scale==Vector2.ONE and view.rotation==0,"only body bob/no articulation "+clip)
		check(view.cancel_action(),"cannot cancel "+clip)
		for index in 23: check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"residual bones")
		for track in motion.get_track_count(): check(motion.track_get_type(track)==Animation.TYPE_VALUE and str(motion.track_get_path(track)).begins_with("Facing/Skeleton2D/"),"damage/event/root animation track")
	check(view.skeleton.get_node_or_null("Torso/Chest/VentR/VentOrigin") is Marker2D,"actual firing nozzle absent")
	view.sample_clip("ram_attack",0.125)
	var first_step: float = view.skeleton.get_node("Torso/LegL").rotation
	view.sample_clip("ram_attack",0.25)
	check(absf(first_step-view.skeleton.get_node("Torso/LegL").rotation)>0.4,"ram active is a frozen sliding body")
	view.sample_clip("death",0.9)
	check(not view.cancel_action() and not view.sample_clip("ram_attack",0),"death can resurrect")
	view.free()
	if not failures: print("TEST PASS: FurnaceForemanAttackResourceTest %d"%checks)
	quit(1 if failures else 0)
