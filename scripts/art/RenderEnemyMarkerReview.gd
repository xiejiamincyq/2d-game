extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const FloorScript = preload("res://scripts/world/FloorGrid.gd")

func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1120, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(FloorScript.new())
	for row in range(2):
		for kind in EnemyScript.EnemyKind.values():
			var enemy := EnemyScript.new()
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.setup(kind, 1, viewport)
			viewport.add_child(enemy)
			await process_frame
			enemy.position = Vector2(80 + kind * 160, 128 + row * 240)
			if row == 1:
				enemy.health.current_health = enemy.health.max_health * 0.5
			enemy.queue_redraw()
			var label := Label.new()
			label.position = Vector2(16 + kind * 160, 24 + row * 240)
			label.text = EnemyScript.EnemyKind.keys()[kind] + (" / Full" if row == 0 else " / 50%")
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color("123b3b"))
			viewport.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := viewport.get_texture().get_image()
	var version := "before" if OS.get_cmdline_user_args().has("before") else "after"
	var path := "res://docs/art/previews/environment/enemy-markers-%s-v1.png" % version
	if capture == null or capture.is_empty() or capture.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("Enemy marker capture failed")
		quit(1)
		return
	viewport.queue_free()
	await process_frame
	print("ENEMY MARKERS PASS: ", path)
	quit(0)
