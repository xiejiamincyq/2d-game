extends SceneTree
const Draft = preload("res://scenes/art/technical/CinderChargeDraft.gd")
const View = preload("res://scripts/components/NativeActorView.gd")
const SCENE := "res://scenes/actors/native/cinder_runner_paper_v2.tscn"
const MOTION := "res://assets/art/actors/native/cinder_runner_motion_v2.tres"
func _initialize() -> void:
	await process_frame
	if FileAccess.file_exists(SCENE) or FileAccess.file_exists(MOTION):
		push_error("CINDER CHARGE BAKE FAIL: choose unused version")
		quit(1)
		return
	var actor := Draft.new()
	actor.name = "CinderRunnerPaper"
	root.add_child(actor)
	actor.player.stop()
	actor.player.animation_finished.disconnect(actor._on_animation_finished)
	for index in actor.skeleton.get_bone_count():
		actor.skeleton.get_bone(index).apply_rest()
	var result := ResourceSaver.save(actor.player.get_animation_library(""),MOTION)
	if result == OK:
		actor.player.remove_animation_library("")
		actor.player.add_animation_library("",load(MOTION))
		actor.get_node("Facing/Skin").set_script(null)
		actor.set_script(View)
		for child in actor.find_children("*","Node",true,false):
			child.owner = actor
		var packed := PackedScene.new()
		result = packed.pack(actor)
		if result == OK:
			result = ResourceSaver.save(packed,SCENE)
	actor.free()
	if result != OK:
		push_error("CINDER CHARGE BAKE FAIL: serialization")
	else:
		print("CINDER CHARGE BAKE PASS: original 15-bone v2, nine clips")
	quit(0 if result == OK else 1)
