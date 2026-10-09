extends SceneTree

# Native rendering of real enemy actors; staged health/warnings, not a playtest.
const Enemy = preload("res://scripts/actors/Enemy.gd")

func _initialize() -> void:
	call_deferred("run")

func label_at(view: SubViewport, text: String, position: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	view.add_child(label)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native renderer required")
		quit(1)
		return
	var view := SubViewport.new()
	view.size = Vector2i(1280, 600)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.size = Vector2(1280, 600)
	background.color = Color("254741")
	view.add_child(background)
	label_at(view, "v13 - real enemy health bars / native Godot rendering", Vector2(30, 20), 26)
	label_at(view, "FULL HEALTH + HEAD WARNING (bruiser keeps damaged-only bar)", Vector2(30, 85), 19)
	label_at(view, "50% HEALTH + HEAD WARNING", Vector2(30, 330), 19)
	var names := ["Scrapper", "Dasher", "Spitter", "Bruiser", "Marksman", "Lobber", "Overseer enemy"]
	for row in range(2):
		for kind in range(7):
			var enemy := Enemy.new()
			enemy.setup(kind, 0, view)
			enemy.position = Vector2(110 + kind * 175, 215 + row * 245)
			view.add_child(enemy)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			if row == 1:
				enemy.health.current_health = enemy.health.max_health * 0.5
			enemy.is_attacking = true
			enemy.attack_timer = 0.10
			enemy.queue_redraw()
			label_at(view, names[kind], Vector2(55 + kind * 175, 285 + row * 245), 17)
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://build/diagnostics/enemy-health-bars-v1.png"
	var result := view.get_texture().get_image().save_png(path)
	view.queue_free()
	await process_frame
	print("ENEMY_HEALTH_BARS_PREVIEW saved=%s" % (result == OK))
	quit(0 if result == OK else 1)
