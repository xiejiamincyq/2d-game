extends SceneTree

const PreviewScript = preload("res://scripts/art/PlayerCardinalPreviewView.gd")
const OUTPUT_PATH := "res://docs/art/previews/characters-combat/player-b-cardinal-layered-runtime-comparison-v1.png"

func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = PreviewScript.BOARD_SIZE
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	viewport.add_child(PreviewScript.new())
	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty():
		push_error("Player cardinal preview capture is empty")
		quit(1)
		return
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if capture.save_png(absolute_path) != OK:
		push_error("Could not save player cardinal preview: " + OUTPUT_PATH)
		quit(1)
		return
	print("RENDER PASS: Player cardinal previews -> " + OUTPUT_PATH)
	quit(0)
