extends SceneTree

const StyleActor = preload("res://scenes/art/technical/PaperStyleActor.gd")
const Rootling = preload("res://scenes/actors/native/rootling_paper_v3.tscn")
const Impact = preload("res://scenes/art/technical/PaperImpactDraft.gd")
const DIR := "res://docs/art/previews/campaign/"

func label(viewport: SubViewport, text: String, at: Vector2, size := 19) -> void:
	var caption := Label.new()
	caption.text = text
	caption.position = at
	caption.add_theme_font_size_override("font_size", size)
	caption.add_theme_color_override("font_color", Color("eadcc1"))
	viewport.add_child(caption)

func make_actor(index: int) -> Node2D:
	if index == 1:
		return Rootling.instantiate()
	if index == 3:
		return Impact.new()
	var actor := StyleActor.new()
	actor.kind = "large" if index == 2 else "player"
	return actor

func _initialize() -> void:
	await process_frame
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bg := ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color("28352f")
	viewport.add_child(bg)
	label(viewport, "INK PAPER / ORIGINAL NATIVE STYLE GROUP / PREVIEW ONLY", Vector2(28, 18), 24)
	label(viewport, "No gameplay integration. Player front only. Large enemy STATIC: no attack animations.", Vector2(28, 53), 17)
	var names := ["FIELD SCOUT", "ROOT PURSUER", "STONE BULWARK", "COMPACT IMPACT"]
	for index in 4:
		var x := 160 + index * 320
		label(viewport, names[index], Vector2(x - 120, 94))
		label(viewport, "3x detail", Vector2(x - 120, 120), 16)
		label(viewport, "1x / actual scale", Vector2(x - 120, 423), 16)
		for row in 2:
			var actor := make_actor(index)
			actor.position = Vector2(x, 373 if row == 0 else 564)
			actor.scale = Vector2.ONE * (3 if row == 0 else 1)
			viewport.add_child(actor)
			if index == 1:
				actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				actor.player.stop()
				for bone in actor.skeleton.find_children("*", "Bone2D", true, false):
					bone.transform = bone.rest
			if index == 3:
				actor.set_phase(0.32)
	label(viewport, "Cream hood / teal coat\nTrue hand weapon socket", Vector2(40, 607), 17)
	label(viewport, "Bark mask / leaf crest\nExisting new native candidate", Vector2(360, 607), 17)
	label(viewport, "Slab body / heavy root feet\nOwn proportions and silhouette", Vector2(680, 607), 17)
	label(viewport, "0.14 seconds / radius 14 px\nNo broad glow or damage logic", Vector2(1000, 607), 17)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(DIR + "paper-style-group-v1.png") != OK:
		push_error("TEST FAIL: native style group capture failed")
		quit(1)
		return
	viewport.queue_free()
	await process_frame
	var reports: Array[Dictionary] = []
	for index in [0, 2, 3]:
		var isolated := SubViewport.new()
		isolated.size = Vector2i(128, 128)
		isolated.transparent_bg = true
		isolated.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(isolated)
		var actor := make_actor(index)
		actor.position = Vector2(64, 80)
		isolated.add_child(actor)
		var phases := [0.0] if index != 3 else [0.0, 0.25, 0.5, 0.75, 1.0]
		var previous: PackedByteArray
		var changes := 0
		for phase in phases:
			if index == 3:
				actor.set_phase(phase)
			await process_frame
			await RenderingServer.frame_post_draw
			var capture := isolated.get_texture().get_image()
			var opaque := 0
			var partial := 0
			var farthest := 0.0
			for y in 128:
				for x in 128:
					var alpha: float = capture.get_pixel(x, y).a
					opaque += 1 if alpha > 0.99 else 0
					partial += 1 if alpha > 0.01 and alpha < 0.99 else 0
					if alpha > 0:
						farthest = maxf(farthest, Vector2(x + 0.5, y + 0.5).distance_to(actor.position))
			var passed := partial == 0 and capture.get_pixel(0, 0).a == 0
			passed = passed and (opaque > 1000 if index != 3 else (opaque == 0 if phase == 1 else opaque > 0 and farthest <= 15))
			if not passed:
				push_error("TEST FAIL: style group opacity/bounds %s phase %s" % [names[index], phase])
				quit(1)
				return
			reports.append({"asset": names[index], "phase": phase, "opaque": opaque, "partial_alpha": partial, "farthest_opaque_pixel": farthest, "passed": passed})
			var bytes := capture.get_data()
			changes += 1 if not previous.is_empty() and previous != bytes else 0
			previous = bytes
			var filename := "paper-style-%s-v1.png" % str(index)
			if index == 3:
				filename = "paper-impact-phase-%s-v1.png" % str(phase).replace(".", "_")
			if capture.save_png(DIR + filename) != OK:
				push_error("TEST FAIL: style isolated capture failed")
				quit(1)
				return
		if index == 3 and changes != 4:
			push_error("TEST FAIL: compact impact phase sequence does not change/clear")
			quit(1)
			return
		isolated.queue_free()
		await process_frame
	var file := FileAccess.open(DIR + "paper-style-opacity-v1.json", FileAccess.WRITE)
	if file == null:
		push_error("TEST FAIL: style evidence report could not open")
		quit(1)
		return
	file.store_string(JSON.stringify({"scope": "GPU original player/front and large/rest; effect five visual phases, not gameplay or all actions", "samples": reports}, "\t"))
	file.close()
	print("RENDER PASS: original native four-asset style group, %d opacity/bounds samples" % reports.size())
	quit(0)
