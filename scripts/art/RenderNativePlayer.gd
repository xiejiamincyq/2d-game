extends SceneTree
## Native GPU visual review only; no claims about Main integration/human play.
const Actor = preload("res://scenes/actors/native/player_paper_v1.tscn")
const CLIPS := ["idle", "walk", "shoot", "dash", "hit", "death", "entrance"]
const DIRECTIONS := [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
const OUT := "res://build/diagnostics/campaign-goal/player-native-v1/"
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("TEST FAIL: RenderNativePlayer " + message)

func _initialize() -> void:
	call_deferred("_run")

func label(parent: Node, words: String, at: Vector2, size := 16) -> void:
	var item := Label.new()
	item.text = words
	item.position = at
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", Color("e4d5b6"))
	parent.add_child(item)

func _run() -> void:
	check(DisplayServer.get_name() != "headless" and not DirAccess.dir_exists_absolute(OUT), "requires native GPU and fresh output")
	if failures:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 920)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = Color("35463b")
	viewport.add_child(background)
	label(viewport, "ORIGINAL PAPER RANGER / FOUR NATIVE VIEWS / NEW ACTIONS", Vector2(24, 18), 23)
	label(viewport, "2.2x detail + 1.3x gameplay scale | hand-bone firearm | resource preview, NOT Main acceptance", Vector2(24, 53))
	var actors: Array[Node2D] = []
	for row in 4:
		label(viewport, ["FRONT", "BACK", "LEFT", "RIGHT"][row], Vector2(14, 108 + row * 198))
		for column in CLIPS.size():
			var at := Vector2(103 + column * 173, 222 + row * 198)
			label(viewport, CLIPS[column], at + Vector2(-28, 28))
			for detail in [true, false]:
				var actor = Actor.instantiate()
				actor.position = at + Vector2(-21 if detail else 45, 0)
				actor.scale = Vector2.ONE * (2.2 if detail else 1.3)
				viewport.add_child(actor)
				actor.set_aim(DIRECTIONS[row])
				actor.sample_clip(CLIPS[column], 0.07 if CLIPS[column] in ["shoot", "dash"] else 0.18)
				actors.append(actor)
	await process_frame
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(OUT + "contact.png") == OK, "contact save failed")
	var changed := 0
	var previous := 0
	for frame in 60:
		for index in actors.size():
			actors[index].sample_clip(CLIPS[(index / 2) % 7], frame / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var capture := viewport.get_texture().get_image()
		var current := hash(capture.get_data())
		changed += 1 if frame > 0 and current != previous else 0
		previous = current
		check(capture.save_png(OUT + "frame_%03d.png" % frame) == OK, "motion frame save failed")
	check(changed >= 55, "native actions look static")
	viewport.free()
	var alpha := SubViewport.new()
	alpha.size = Vector2i(192, 192)
	alpha.transparent_bg = true
	alpha.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(alpha)
	var samples: Array[Dictionary] = []
	for direction in DIRECTIONS:
		for clip in CLIPS:
			var actor = Actor.instantiate()
			actor.position = Vector2(96, 116)
			actor.scale = Vector2.ONE * 1.3
			alpha.add_child(actor)
			actor.set_aim(direction)
			for phase in [0.0, 0.5, 1.0]:
				var animator: AnimationPlayer = actor.get_node(actor.facing + "/AnimationPlayer")
				actor.sample_clip(clip, animator.get_animation(clip).length * phase)
				await process_frame
				await RenderingServer.frame_post_draw
				var image := alpha.get_texture().get_image()
				var opaque := 0
				var translucent := 0
				for y in image.get_height():
					for x in image.get_width():
						var a := image.get_pixel(x, y).a
						opaque += 1 if a > 0.999 else 0
						translucent += 1 if a > 0.001 and a < 0.999 else 0
				check(opaque > 500 and translucent == 0, "empty/translucent player " + actor.facing + "/" + clip)
				samples.append({"view": actor.facing, "clip": clip, "phase": phase, "opaque": opaque, "translucent": translucent})
			actor.free()
	alpha.free()
	await process_frame
	var file := FileAccess.open(OUT + "report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"valid": failures == 0, "scope": "Native GPU resource-only four-view seven-action review; not gameplay", "frames": 60, "adjacent_pixel_changes": changed, "alpha_samples": samples}, "\t"))
	file.close()
	if failures == 0:
		print("RENDER PASS: NativePlayer four views, seven actions, %d/59 moving frames, %d opaque samples" % [changed, samples.size()])
	quit(1 if failures else 0)
