extends SceneTree
const Draft = preload("res://scenes/art/technical/CinderRunnerDraft.gd")
const View = preload("res://scripts/components/NativeActorView.gd")
const SCENE := "res://scenes/actors/native/cinder_runner_paper_v1.tscn"
const MOTION := "res://assets/art/actors/native/cinder_runner_motion_v1.tres"
func _initialize() -> void:
	await process_frame
	if FileAccess.file_exists(SCENE) or FileAccess.file_exists(MOTION):
		push_error("CINDER BAKE FAIL: existing outputs; choose a new version")
		quit(1)
		return
	var actor := Draft.new()
	actor.name = "CinderRunnerPaper"
	root.add_child(actor)
	if not actor.player.has_animation_library("") or actor.get_node("Facing/Skin").polygon.is_empty():
		actor.free()
		push_error("CINDER BAKE FAIL: draft initialization")
		quit(1)
		return
	actor.player.stop()
	actor.player.clear_queue()
	actor.player.animation_finished.disconnect(actor._on_animation_finished)
	for index in actor.skeleton.get_bone_count():
		actor.skeleton.get_bone(index).apply_rest()
	var result := ResourceSaver.save(actor.player.get_animation_library(""),MOTION)
	if result != OK:
		actor.free()
		push_error("CINDER BAKE FAIL: animation serialization")
		quit(1)
		return
	actor.player.remove_animation_library("")
	actor.player.add_animation_library("",load(MOTION))
	actor.get_node("Facing/Skin").set_script(null)
	actor.set_script(View)
	for child in actor.find_children("*","Node",true,false):
		child.owner = actor
	var packed := PackedScene.new()
	result = packed.pack(actor)
	actor.free()
	if result == OK:
		result = ResourceSaver.save(packed,SCENE)
	if result != OK:
		push_error("CINDER BAKE FAIL: scene serialization")
		quit(1)
		return
	print("CINDER BAKE PASS: 15 original bones, six new clips")
	quit(0)
