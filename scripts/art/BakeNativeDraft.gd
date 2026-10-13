extends SceneTree
## Reusable author-only serializer; refuses every existing output.
const View = preload("res://scripts/components/NativeActorView.gd")
func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size()!=2 or not args[0].begins_with("res://scenes/art/technical/") or ".." in args[0] or not args[0].ends_with(".gd") or not args[1].is_valid_identifier():
		push_error("NATIVE BAKE FAIL: expected safe author draft path and resource stem")
		quit(1)
		return
	var scene := "res://scenes/actors/native/"+args[1]+".tscn"
	var motion := "res://assets/art/actors/native/"+args[1].replace("_paper_", "_motion_")+".tres"
	if FileAccess.file_exists(scene) or FileAccess.file_exists(motion):
		push_error("NATIVE BAKE FAIL: choose unused version")
		quit(1)
		return
	var actor = load(args[0]).new()
	actor.name = "NativePaperActor"
	root.add_child(actor)
	if actor.get_node_or_null("Facing/Skeleton2D") == null or actor.get_node_or_null("AnimationPlayer") == null or actor.get_node_or_null("Facing/Skin") == null or actor.player == null or not actor.player.has_animation_library(""):
		push_error("NATIVE BAKE FAIL: incomplete author rig or animation library")
		actor.free()
		quit(1)
		return
	actor.player.stop()
	actor.player.animation_finished.disconnect(actor._on_animation_finished)
	for index in actor.skeleton.get_bone_count():
		actor.skeleton.get_bone(index).apply_rest()
	var result := ResourceSaver.save(actor.player.get_animation_library(""),motion)
	if result==OK:
		actor.player.remove_animation_library("")
		actor.player.add_animation_library("",load(motion))
		actor.get_node("Facing/Skin").set_script(null)
		var reviewed_padding: float = actor.visual_bounds_padding
		actor.set_script(View)
		actor.visual_bounds_padding = reviewed_padding
		for child in actor.find_children("*","Node",true,false):
			child.owner = actor
		var packed := PackedScene.new()
		result = packed.pack(actor)
		if result==OK:
			result = ResourceSaver.save(packed,scene)
	actor.free()
	if result!=OK:
		push_error("NATIVE BAKE FAIL: serialization")
	else:
		print("NATIVE BAKE PASS: "+scene)
	quit(0 if result==OK else 1)
