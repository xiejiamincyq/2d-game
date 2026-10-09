extends SceneTree
## Mechanical serialization, fresh revision only, editable native bones/library.
const Draft = preload("res://scenes/art/technical/PlayerPaperDraft.gd")
const View = preload("res://scripts/components/NativePlayerView.gd")
const SCENE := "res://scenes/actors/native/player_paper_v1.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(SCENE):
		push_error("TEST FAIL: BakePlayerResource refuses existing scene")
		quit(1)
		return
	for direction in ["Front", "Back", "Left", "Right"]:
		if FileAccess.file_exists(_motion_path(direction)):
			push_error("TEST FAIL: BakePlayerResource refuses existing motion")
			quit(1)
			return
	var actor := Node2D.new()
	actor.name = "PlayerPaper"
	root.add_child(actor)
	for direction in ["Front", "Back", "Left", "Right"]:
		var draft := Draft.new()
		draft.direction = direction
		draft.name = direction
		actor.add_child(draft)
		var animator: AnimationPlayer = draft.get_node("AnimationPlayer")
		var path := _motion_path(direction)
		if ResourceSaver.save(animator.get_animation_library(""), path) != OK:
			push_error("TEST FAIL: BakePlayerResource motion save failed")
			actor.free()
			quit(1)
			return
		animator.remove_animation_library("")
		animator.add_animation_library("", load(path))
		draft.get_node("Skin").set_script(null)
		draft.set_script(null)
		draft.visible = direction == "Front"
	actor.set_script(View)
	for child in actor.find_children("*", "Node", true, false):
		child.owner = actor
	var packed := PackedScene.new()
	var ok := packed.pack(actor) == OK and ResourceSaver.save(packed, SCENE) == OK
	actor.free()
	await process_frame
	if ok:
		print("BAKE PASS: four editable original player views and external motion libraries")
	quit(0 if ok else 1)

func _motion_path(direction: String) -> String:
	return "res://assets/art/actors/native/player_%s_motion_v1.tres" % direction.to_lower()
