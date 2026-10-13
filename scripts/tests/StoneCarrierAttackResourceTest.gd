extends SceneTree
const SCENE := "res://scenes/actors/native/stone_carrier_paper_v2.tscn"
const MANIFEST := "res://docs/art/native-manifests/stone_carrier_paper_v2.json"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: StoneCarrierAttackResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"post-checkpoint articulated slam resource missing")
	if failures:
		quit(1)
		return
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(Validator.new().validate_entry(entry).is_empty(),"reviewed post-rig large resource rejected")
	var without := entry.duplicate(true)
	without.erase("rig_checkpoint")
	check(not Validator.new().validate_entry(without).is_empty(),"all large attack gates were globally removed")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==17,"new attack changes rig topology")
	check(view.player.get_animation_library("").resource_path=="res://assets/art/actors/native/stone_carrier_motion_v2.tres","attack not editable external library")
	check(view.player.get_animation_list().size()==8,"partial or unexpected motions")
	for pair in [["slam_warning",0.5],["slam_attack",0.12],["slam_recovery",0.63]]:
		check(view.player.has_animation(pair[0]),"missing original slam stage "+pair[0])
		if not view.player.has_animation(pair[0]):
			continue
		var clip: Animation = view.player.get_animation(pair[0])
		check(is_equal_approx(clip.length,pair[1]) and clip.loop_mode==Animation.LOOP_NONE,"stage not aligned to combat window")
		view.cancel_action()
		var before: Array[Transform2D] = []
		for i in 17:
			before.append(view.skeleton.get_bone(i).transform)
		view.sample_clip(pair[0],clip.length*0.6)
		var changed := 0
		for i in 17:
			if not before[i].is_equal_approx(view.skeleton.get_bone(i).transform):
				changed+=1
		check(changed>=3,"attack is only a whole-body bob")
		check(view.position==Vector2.ZERO and view.rotation==0 and view.modulate.a==1,"attack moves/rotates/fades physical root")
		check(view.cancel_action(),"attack cannot be canceled")
		for i in 17:
			check(view.skeleton.get_bone(i).transform.is_equal_approx(view.skeleton.get_bone(i).rest),"cancel leaves distorted joint")
		for track in clip.get_track_count():
			check(clip.track_get_type(track)==Animation.TYPE_VALUE and str(clip.track_get_path(track)).begins_with("Facing/Skeleton2D/"),"animation owns event/damage/collision")
	view.sample_clip("slam_warning",0.42)
	check(absf(view.skeleton.get_node("Torso/ShoulderL").rotation)>1.8 and absf(view.skeleton.get_node("Torso/ShoulderR").rotation)>1.8,"arms never genuinely rise")
	view.sample_clip("slam_attack",0)
	check(absf(view.skeleton.get_node("Torso/ShoulderL").rotation)<0.6,"damage frame still shows raised hands")
	view.sample_clip("death",0.69)
	check(not view.cancel_action() and not view.sample_clip("slam_attack",0),"dead carrier resumes attack")
	view.free()
	if not failures:
		print("TEST PASS: StoneCarrierAttackResourceTest %d" % checks)
	quit(1 if failures else 0)
