extends SceneTree

func _initialize() -> void:
	await process_frame
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop = load("res://scripts/ui/CampaignBackdrop.gd").new()
	backdrop.size = viewport.size
	viewport.add_child(backdrop)
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := viewport.get_texture().get_image()
	var path := "res://docs/art/previews/campaign/paper-environment-style-v1.png"
	if capture == null or capture.is_empty() or capture.save_png(path) != OK:
		push_error("TEST FAIL: campaign backdrop render")
		quit(1)
		return
	viewport.queue_free()
	await process_frame
	print("TEST PASS: RenderCampaignBackdrop 1")
	quit(0)
