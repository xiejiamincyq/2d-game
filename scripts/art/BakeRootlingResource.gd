extends SceneTree

# Mechanical Godot serialization of the reviewed original draft. The baked
# resource has no runtime dependency on excluded authoring/technical scripts.
const Draft = preload("res://scenes/art/technical/RootlingDraft.gd")
const View = preload("res://scripts/components/NativeActorView.gd")
const SCENE := "res://scenes/actors/native/rootling_paper_v3.tscn"
const MOTION := "res://assets/art/actors/native/rootling_motion_v3.tres"

func fail(message: String) -> void:
	push_error("TEST FAIL: BakeRootlingResource " + message)
	quit(1)

func _initialize() -> void:
	await process_frame
	# New version paths only. Never replace an approved resource automatically.
	if FileAccess.file_exists(SCENE) or FileAccess.file_exists(MOTION):
		fail("output already exists; choose a new revision")
		return
	var actor := Draft.new()
	actor.name = "RootlingPaper"
	root.add_child(actor)
	actor.player.stop()
	actor.player.clear_queue()
	actor.player.animation_finished.disconnect(actor._on_animation_finished)
	for index in actor.skeleton.get_bone_count():
		actor.skeleton.get_bone(index).apply_rest()
	actor.get_node("Warning").visible = false
	var library: AnimationLibrary = actor.player.get_animation_library("")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOTION).get_base_dir())
	if ResourceSaver.save(library, MOTION) != OK:
		actor.free()
		fail("motion resource could not be serialized")
		return
	# Saving a newly created resource does not retain its resource_path in 4.7.
	# Reload the file so PackedScene serializes an external dependency.
	var external: AnimationLibrary = load(MOTION)
	if external == null or external.resource_path != MOTION:
		actor.free()
		fail("saved motion could not reload as an external resource")
		return
	actor.player.remove_animation_library("")
	actor.player.add_animation_library("", external)
	actor.get_node("Facing/Skin").set_script(null)
	actor.set_script(View)
	for child in actor.find_children("*", "Node", true, false):
		child.owner = actor
	var packed := PackedScene.new()
	var result := packed.pack(actor)
	actor.free()
	if result != OK:
		fail("scene pack failed")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE).get_base_dir())
	if ResourceSaver.save(packed, SCENE) != OK:
		fail("scene resource could not be serialized")
		return
	print("BAKE PASS: editable rootling scene and external AnimationLibrary")
	quit(0)
