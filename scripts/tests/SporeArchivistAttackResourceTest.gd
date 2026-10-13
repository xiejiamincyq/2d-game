extends SceneTree
## Resource-only contract: real bone articulation, unchanged baseline, no damage clock.
const SCENE := "res://scenes/actors/native/spore_archivist_paper_v2.tscn"
const MANIFEST := "res://docs/art/native-manifests/spore_archivist_paper_v2.json"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const DURATIONS := {"page":[0.22,0.40,0.52],"seal":[0.24,0.28,0.64],"brood":[0.26,0.36,0.70]}
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: SporeArchivistAttackResourceTest "+label)
func pose(view: Node) -> Array[Transform2D]:
	var result: Array[Transform2D] = []
	for index in 27: result.append(view.skeleton.get_bone(index).transform)
	return result
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE) and FileAccess.file_exists(MANIFEST),"versioned archivist actions missing")
	if failures: quit(1); return
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(Validator.new().validate_entry(entry).is_empty(),"opaque native/checkpoint contract")
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==27 and view.player.get_animation_list().size()==14,"reviewed anatomy/base motions changed")
	check(view.player.get_animation_library("").resource_path==entry.motion_library,"external editable library missing")
	var baseline: AnimationLibrary = load("res://assets/art/actors/native/spore_archivist_motion_v1.tres")
	for clip in baseline.get_animation_list():
		var old: Animation = baseline.get_animation(clip)
		var current: Animation = view.player.get_animation(clip)
		check(current.length==old.length and current.loop_mode==old.loop_mode and current.get_track_count()==old.get_track_count(),"base clip changed "+clip)
		for track in old.get_track_count():
			check(current.track_get_type(track)==old.track_get_type(track) and current.track_get_path(track)==old.track_get_path(track) and current.track_get_key_count(track)==old.track_get_key_count(track),"base track changed")
			for key in old.track_get_key_count(track):
				check(current.track_get_key_time(track,key)==old.track_get_key_time(track,key) and current.track_get_key_value(track,key)==old.track_get_key_value(track,key),"base key changed")
	var physical := view.transform as Transform2D
	for action in DURATIONS:
		var prior: Array[Transform2D] = []
		for stage in ["warning","attack","recovery"]:
			var clip: String = action+"_"+stage
			check(view.player.has_animation(clip),"missing "+clip)
			if not view.player.has_animation(clip): continue
			var motion: Animation = view.player.get_animation(clip)
			check(is_equal_approx(motion.length,DURATIONS[action][["warning","attack","recovery"].find(stage)]) and motion.loop_mode==Animation.LOOP_NONE,"duration/loop mismatch")
			for track in motion.get_track_count():
				var path := str(motion.track_get_path(track))
				check(motion.track_get_type(track)==Animation.TYPE_VALUE and path.begins_with("Facing/Skeleton2D/") and path.get_slice(":",1) in ["position","rotation","scale"] and view.get_node_or_null(path.get_slice(":",0)) is Bone2D,"event/root/opacity track")
			view.sample_clip(clip,0)
			if not prior.is_empty():
				for index in 27: check(view.skeleton.get_bone(index).transform.is_equal_approx(prior[index]),"stage boundary snaps "+clip)
			view.sample_clip(clip,motion.length)
			prior = pose(view)
			for left in [false,true]:
				view.cancel_action()
				view.set_facing_left(left)
				check(view.sample_clip(clip,motion.length*0.55),"sampling failed")
				var changed := 0
				for index in 27:
					var bone: Bone2D = view.skeleton.get_bone(index)
					changed += 1 if not bone.transform.is_equal_approx(bone.rest) else 0
				check(changed>=8 and view.transform==physical,"whole-body wobble/physical mutation")
				check(not view.get_node("Warning").visible,"laboratory label leaks")
				check(view.cancel_action(),"cancel rejected")
				for index in 27:
					var bone: Bone2D = view.skeleton.get_bone(index)
					check(bone.transform.is_equal_approx(bone.rest),"cancel retains deformed joint")
		for index in 27: check(prior[index].is_equal_approx(view.skeleton.get_bone(index).rest),"recovery does not end at rest")
	for path in ["Torso/Book/Spine/IndexOrigin","Torso/Head/Cap/SporeOrigin","Torso/SporeSatchel/ColonyOrigin"]:
		check(view.skeleton.get_node_or_null(path) is Marker2D,"semantic socket missing "+path)
	view.set_facing_left(false)
	view.sample_clip("page_attack",0.08)
	var early: float = view.skeleton.get_node("Torso/Book/PageL").rotation
	# Compare the serialized peak at 0.08 with its return at 0.22, not two peaks.
	view.sample_clip("page_attack",0.22)
	check(absf(early-view.skeleton.get_node("Torso/Book/PageL").rotation)>0.25,"page lacks a real leaf flick")
	view.sample_clip("seal_attack",0.16)
	check(view.skeleton.get_node("Torso/Head/GillL").rotation*view.skeleton.get_node("Torso/Head/GillR").rotation<0,"seal gills do not open independently")
	view.sample_clip("brood_attack",0.18)
	check(view.skeleton.get_node("Torso/SporeSatchel").scale.y>1.05 and absf(view.skeleton.get_node("Torso/Book/Spine").rotation)>0.05,"summon lacks satchel/spine release")
	check(view.player.callback_mode_process==AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,"second autonomous action clock")
	view.sample_clip("death",0.84)
	check(not view.cancel_action() and not view.sample_clip("page_attack",0),"death resurrects attack")
	view.free()
	if not failures: print("TEST PASS: SporeArchivistAttackResourceTest %d" % checks)
	quit(1 if failures else 0)
