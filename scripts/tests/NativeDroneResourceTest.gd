extends SceneTree
const SCENE := "res://scenes/actors/native/ranger_drone_paper_v1.tscn"
const CLIPS := ["idle","walk","shoot","entrance","death"]
var assertions := 0
var failures := 0
func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativeDroneResourceTest "+message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	check(ResourceLoader.exists(SCENE),"original companion native resource missing")
	if failures:
		quit(1)
		return
	var packed := load(SCENE) as PackedScene
	var actor = packed.instantiate()
	root.add_child(actor)
	check(actor.find_children("*","CollisionObject2D",true,false).is_empty(),"art owns gameplay physics")
	var rig: Skeleton2D = actor.get_node("Facing/Skeleton2D")
	var skin: Polygon2D = actor.get_node("Facing/Skin")
	check(rig.get_bone_count()==10 and skin.get_bone_count()==10,"ten real/bound bones missing")
	check(skin.texture==null and skin.get_script()==null,"old raster/author dependency")
	check(actor.player.get_animation_library("").resource_path=="res://assets/art/actors/native/ranger_drone_motion_v1.tres","external editable motion library missing")
	for vertex in skin.polygon.size():
		var total := 0.0
		for binding in skin.get_bone_count(): total += skin.get_bone_weights(binding)[vertex]
		check(is_equal_approx(total,1) and is_equal_approx(skin.vertex_colors[vertex].a,1),"unbound/translucent body")
	for clip in CLIPS:
		check(actor.player.has_animation(clip),"new action absent "+clip)
		var sample = packed.instantiate()
		root.add_child(sample)
		var skeleton: Skeleton2D = sample.get_node("Facing/Skeleton2D")
		sample.sample_clip(clip,0)
		var poses: Array[Transform2D] = []
		for index in skeleton.get_bone_count(): poses.append(skeleton.get_bone(index).transform)
		sample.sample_clip(clip,sample.player.get_animation(clip).length*0.3)
		var changed := 0
		for index in skeleton.get_bone_count():
			changed += 1 if not poses[index].is_equal_approx(skeleton.get_bone(index).transform) else 0
		check(changed>=2,"action only bobs whole body "+clip)
		for track in sample.player.get_animation(clip).get_track_count():
			var animation: Animation = sample.player.get_animation(clip)
			check(animation.track_get_type(track)==Animation.TYPE_VALUE and str(animation.track_get_path(track)).begins_with("Facing/Skeleton2D/"),"action writes gameplay/root")
		var frozen: Transform2D = skeleton.get_node("Torso/WingL").transform
		await process_frame
		await process_frame
		check(frozen.is_equal_approx(skeleton.get_node("Torso/WingL").transform),"manual visual runs independent clock")
		sample.free()
	actor.sample_clip("shoot",0.05)
	check(actor.cancel_action(),"cancel failed")
	for bone in rig.get_bone_count(): check(rig.get_bone(bone).transform.is_equal_approx(rig.get_bone(bone).rest),"cancel leaves recoil")
	check(actor.sample_clip("death",0.3) and not actor.cancel_action() and not actor.sample_clip("walk",0),"terminal death revives")
	check(not actor.sample_clip("walk",NAN) and not actor.sample_clip("walk",-1),"invalid clock accepted")
	actor.free()
	await process_frame
	if failures==0: print("TEST PASS: NativeDroneResourceTest %d"%assertions)
	quit(1 if failures else 0)
