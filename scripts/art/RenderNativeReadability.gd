extends SceneTree

const Actor = preload("res://scenes/actors/native/rootling_paper_v3.tscn")
const OUTPUT := "res://docs/art/previews/campaign/rootling-native-readability-v1.png"
const ALPHA := "res://docs/art/previews/campaign/rootling-native-opacity-v1.png"
const REPORT := "res://docs/art/previews/campaign/rootling-native-opacity-v1.json"

func _initialize() -> void:
	await process_frame
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var grounds := [Color("ded4bc"), Color("263d32"), Color("30313e"), Color("454033")]
	var names := ["PAPER / actual size", "MOSS DARK / actual size", "ASH DARK / group overlap", "STONE / mirrored and short warning"]
	for panel in 4:
		var origin := Vector2((panel % 2) * 640, (panel / 2) * 360)
		var background := ColorRect.new()
		background.position = origin
		background.size = Vector2(640, 360)
		background.color = grounds[panel]
		viewport.add_child(background)
		var label := Label.new()
		label.text = names[panel] + " / NOT GAMEPLAY"
		label.position = origin + Vector2(20, 14)
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", Color("172822") if panel == 0 else Color("e8ddc8"))
		viewport.add_child(label)
		for index in 12:
			var actor := Actor.instantiate()
			actor.position = origin + Vector2(64 + (index % 6) * 98, 148 + (index / 6) * 138)
			if panel == 2:
				actor.position = origin + Vector2(180 + (index % 6) * 46, 180 + (index / 6) * 34)
			viewport.add_child(actor)
			actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			actor.set_facing_left(panel == 3 and index % 2 == 0)
			var clip := "warning" if panel == 3 and index == 3 else "walk"
			actor.play_clip(clip)
			actor.player.seek(0.07 if clip == "warning" else index * 0.047, true)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(OUTPUT) != OK:
		push_error("TEST FAIL: Native readability render failed")
		quit(1)
		return
	viewport.queue_free()
	await process_frame
	var isolated := SubViewport.new()
	isolated.size = Vector2i(128, 128)
	isolated.transparent_bg = true
	isolated.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(isolated)
	var actor := Actor.instantiate()
	actor.position = Vector2(64, 76)
	isolated.add_child(actor)
	actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.player.seek(0, true)
	await process_frame
	await RenderingServer.frame_post_draw
	var transparent := isolated.get_texture().get_image()
	var opaque := 0
	var partial := 0
	for y in 128:
		for x in 128:
			var alpha: float = transparent.get_pixel(x, y).a
			opaque += 1 if alpha > 0.99 else 0
			partial += 1 if alpha > 0.01 and alpha < 0.99 else 0
	var core_opaque := true
	for y in range(42, 54):
		for x in range(60, 68):
			core_opaque = core_opaque and transparent.get_pixel(x, y).a > 0.99
	var passed := opaque > 1000 and partial == 0 and core_opaque and transparent.get_pixel(0, 0).a == 0
	transparent.save_png(ALPHA)
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "actual GPU native scene at idle/rest only; not combat or all-pose alpha proof", "opaque_pixels": opaque, "partial_alpha_pixels": partial, "head_core_opaque": core_opaque, "transparent_corner": transparent.get_pixel(0, 0).a, "passed": passed}, "\t"))
	file.close()
	isolated.queue_free()
	await process_frame
	if not passed:
		push_error("TEST FAIL: Native opacity runtime report rejected")
	print("RENDER %s: native dark-ground/group sheet and rest opacity, %d opaque / %d partial" % ["PASS" if passed else "FAIL", opaque, partial])
	quit(0 if passed else 1)
