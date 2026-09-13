extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const VfxScript = preload("res://scripts/effects/CombatVfx.gd")
const FloorScript = preload("res://scripts/world/FloorGrid.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var version := "after" if args.has("after") else "before"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(FloorScript.new())
	for column in range(3):
		var center := Vector2(160.0 + column * 320.0, 180.0)
		var player := PlayerScript.new()
		player.position = center
		viewport.add_child(player)
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.advance_entrance(player.get_entrance_duration() + 0.01)
		player.gun_angle = 0.0
		player.queue_redraw()
		var vfx := VfxScript.new()
		viewport.add_child(vfx)
		vfx.process_mode = Node.PROCESS_MODE_DISABLED
		for index in range(20 if column == 2 else 1):
			vfx.request_effect(VfxScript.SPARK, center, Vector2.RIGHT)
		if column > 0:
			vfx.request_effect(VfxScript.BLAST, center)
		if version == "before":
			# Reproduce the previous draw rule: every spark paints a full hit texture.
			for spark in vfx._sparks:
				spark["textured"] = true
		vfx._process(0.03)
		var label := Label.new()
		label.text = ["Single hit", "Hit + blast", "20 hits + blast"][column]
		label.position = Vector2(center.x - 100.0, 36.0)
		label.add_theme_color_override("font_color", Color("123b3b"))
		label.add_theme_font_size_override("font_size", 22)
		viewport.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := viewport.get_texture().get_image()
	var path := "res://docs/art/previews/environment/impact-readability-%s-v1.png" % version
	if capture == null or capture.is_empty() or capture.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("Impact readability capture failed")
		quit(1)
		return
	viewport.queue_free()
	await process_frame
	print("Impact readability capture: ", path)
	quit(0)
