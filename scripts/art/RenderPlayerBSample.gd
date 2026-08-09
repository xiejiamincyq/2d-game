extends SceneTree

const PlayerBSampleViewScript = preload("res://scripts/art/PlayerBSampleView.gd")
const OUTPUT_PATH := "res://docs/art/previews/characters-combat/player-b-8dir-runtime-board-v1.png"

func _initialize() -> void:
	print("RENDER START: Player B sample board")
	var viewport := SubViewport.new()
	viewport.size = PlayerBSampleViewScript.BOARD_SIZE
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	viewport.add_child(PlayerBSampleViewScript.new())

	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty():
		push_error("Player B runtime sample board capture is empty")
		quit(1)
		return
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if capture.save_png(absolute_path) != OK:
		push_error("Could not save Player B runtime sample board: " + OUTPUT_PATH)
		quit(1)
		return
	print("RENDER PASS: Player B sample board %dx%d -> %s" % [
		capture.get_width(),
		capture.get_height(),
		OUTPUT_PATH,
	])
	quit(0)
