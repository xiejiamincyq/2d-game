extends SceneTree
const Actor = preload("res://scenes/actors/native/cinder_runner_paper_v1.tscn")
const OUT := "res://build/diagnostics/campaign-goal/cinder-resource-v1/"
const CLIPS := ["idle", "walk", "warning", "attack", "hit", "death"]
var failed := false
func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("CINDER GPU FAIL: " + label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(DisplayServer.get_name() != "headless" and not DirAccess.dir_exists_absolute(OUT), "requires GPU and new output")
	if failed:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var sources := {}
	for path in ["scripts/art/RenderCinderRunnerResource.gd", "scenes/actors/native/cinder_runner_paper_v1.tscn", "assets/art/actors/native/cinder_runner_motion_v1.tres", "scripts/components/NativeActorView.gd", "scenes/art/technical/CinderRunnerDraft.gd", "scenes/art/technical/CinderRunnerShapes.gd"]:
		sources[path] = FileAccess.get_sha256("res://" + path)
		check(sources[path].length() == 64, "missing source hash " + path)
	if failed:
		quit(1)
		return
	var tiny := SubViewport.new()
	tiny.size = Vector2i(128,128)
	tiny.transparent_bg = true
	tiny.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(tiny)
	var sheet := SubViewport.new()
	sheet.size = Vector2i(1280,660)
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)
	var background := ColorRect.new()
	background.color = Color("304138")
	background.size = sheet.size
	sheet.add_child(background)
	var samples: Array[Dictionary] = []
	for column in CLIPS.size():
		var clip: String = CLIPS[column]
		var title := Label.new()
		title.text = clip
		title.position = Vector2(column * 200 + 70, 12)
		title.add_theme_font_size_override("font_size", 20)
		sheet.add_child(title)
		var actor = Actor.instantiate()
		tiny.add_child(actor)
		actor.position = Vector2(64,76)
		var length: float = actor.player.get_animation(clip).length
		for row in 3:
			var phase: float = [0.0,0.4,0.85][row]
			actor.sample_clip(clip, length * phase)
			await process_frame
			await RenderingServer.frame_post_draw
			var bitmap := tiny.get_texture().get_image()
			var opaque := 0
			var partial := 0
			var edge := 0
			for y in 128:
				for x in 128:
					var a := bitmap.get_pixel(x,y).a
					opaque += 1 if a >= 0.99 else 0
					partial += 1 if a > 0.01 and a < 0.99 else 0
					edge += 1 if a > 0.01 and (x == 0 or y == 0 or x == 127 or y == 127) else 0
			check(opaque > 700 and partial == 0 and edge == 0, "tiny body translucent/clipped " + clip)
			samples.append({"clip":clip,"phase":phase,"opaque_pixels":opaque,"partial_pixels":partial,"edge_pixels":edge})
			var preview = Actor.instantiate()
			sheet.add_child(preview)
			preview.position = Vector2(column * 200 + 120, 150 + row * 180)
			preview.scale = Vector2.ONE * 2
			preview.sample_clip(clip, length * phase)
		actor.free()
	await process_frame
	await RenderingServer.frame_post_draw
	check(sheet.get_texture().get_image().save_png(OUT + "poses.png") == OK, "preview write failed")
	# A separate real native gait sequence proves changing frames, not one pose.
	var moving = Actor.instantiate()
	tiny.add_child(moving)
	moving.position = Vector2(64,76)
	var changed := 0
	var previous := PackedByteArray()
	for frame in 60:
		moving.sample_clip("walk", frame / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := tiny.get_texture().get_image().get_data()
		changed += 1 if frame > 0 and pixels != previous else 0
		previous = pixels
	check(changed >= 50, "gait sequence is static")
	for path in sources:
		check(FileAccess.get_sha256("res://" + path) == sources[path], "source changed during preview")
	var report := {"passed":not failed,"samples":samples,"gait_frames":60,"adjacent_pixel_changes":changed,"sources":sources,"scope":"Original new editable forge runner resource, 18 GPU poses at native scale and 2x labeled review sheet; continuous 60-frame gait. Not actual combat or human acceptance."}
	var file := FileAccess.open(OUT + "report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	tiny.free()
	sheet.free()
	await process_frame
	print("CINDER GPU %s: 18 opaque poses, 60 gait frames/%d changes" % ["FAIL" if failed else "PASS",changed])
	quit(1 if failed else 0)
