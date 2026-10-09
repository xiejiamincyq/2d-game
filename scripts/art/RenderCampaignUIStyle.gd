extends SceneTree

func _initialize() -> void:
	await process_frame
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background = load("res://scripts/ui/CampaignBackdrop.gd").new()
	background.size = viewport.size
	viewport.add_child(background)
	var panel := PanelContainer.new()
	panel.position = Vector2(48, 48)
	panel.size = Vector2(432, 438)
	panel.theme = load("res://scripts/ui/CampaignMenuTheme.gd").create()
	viewport.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "巡界档案 / 界面风格样板"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 14)
	box.add_child(icons)
	for chapter in range(1, 7):
		var icon = load("res://scripts/ui/CampaignRegionIcon.gd").new()
		icon.chapter = chapter
		icons.add_child(icon)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var button := Button.new()
		button.text = "区域档案 · " + state
		button.custom_minimum_size.y = 44
		button.add_theme_stylebox_override("normal", panel.theme.get_stylebox("normal" if state == "focus" else state, "Button"))
		box.add_child(button)
		if state == "focus":
			button.grab_focus()
	await process_frame
	await RenderingServer.frame_post_draw
	if viewport.get_texture().get_image().save_png("res://docs/art/previews/campaign/paper-ui-style-v1.png") != OK:
		push_error("TEST FAIL: menu UI style capture")
		quit(1)
		return
	viewport.queue_free()
	await process_frame
	print("TEST PASS: RenderCampaignUIStyle 1")
	quit(0)
