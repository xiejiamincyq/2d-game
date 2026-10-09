extends SceneTree

const Sample = preload("res://scenes/art/technical/NativeMonsterSample.tscn")
const SIZE := Vector2i(1280, 720)
const OUTPUT := "res://docs/art/previews/campaign/native-monster-technical-v3.png"
const MOTION := "res://build/diagnostics/campaign-goal/native-monster-motion-v3"
const CLIPS := ["idle", "walk", "warning", "attack", "hit", "death"]
var actors: Array[Node2D] = []

func new_actor() -> Node2D:
	return Sample.instantiate()

func output_path() -> String:
	return OUTPUT

func motion_path() -> String:
	return MOTION

func subtitle() -> String:
	return "CC0 Kenney cutouts - 12 real joints - new animation keys - no old game sprites"

func enlargement() -> float:
	return 2.5

func first_row_y() -> float:
	return 230.0

func clip_label_y() -> float:
	return -146.0

func sample_name() -> String:
	return "NativeMonsterSample"

func label(parent: Node, text: String, at: Vector2, size: int) -> void:
	var item := Label.new()
	item.text = text
	item.position = at
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", Color("26352b"))
	parent.add_child(item)

func _initialize() -> void:
	await process_frame
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(SIZE)
	background.color = Color("dfd6bd")
	viewport.add_child(background)
	label(viewport, "NATIVE BONES / TECHNICAL SAMPLE / NOT FINAL ART", Vector2(28, 18), 26)
	label(viewport, subtitle(), Vector2(28, 55), 16)
	for index in CLIPS.size():
		var column := index % 3
		var row := index / 3
		var center := Vector2(215 + column * 420, first_row_y() + row * 300)
		label(viewport, CLIPS[index].to_upper(), center + Vector2(-95, clip_label_y()), 20)
		for enlarged in [true, false]:
			var actor = new_actor()
			actor.position = center + (Vector2(-45, 0) if enlarged else Vector2(95, -5))
			actor.scale = Vector2.ONE * (enlargement() if enlarged else 1.0)
			viewport.add_child(actor)
			actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			actor.play_clip(CLIPS[index])
			actors.append(actor)
		label(viewport, "%.1fx joints" % enlargement(), center + Vector2(-90, 70), 13)
		label(viewport, "actual size", center + Vector2(54, 70), 13)
	# Contact sheet is a mid-pose comparison. Motion below uses real clip seconds.
	for index in actors.size():
		var actor = actors[index]
		var clip: String = CLIPS[index / 2]
		actor.player.seek(actor.player.get_animation(clip).length * 0.4, true)
	await process_frame
	await RenderingServer.frame_post_draw
	var sheet := viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path()).get_base_dir())
	if sheet == null or sheet.is_empty() or sheet.save_png(ProjectSettings.globalize_path(output_path())) != OK:
		push_error("TEST FAIL: Native monster contact sheet save failed")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(motion_path()))
	var different_frames := 0
	var previous_hash := 0
	for frame in 60:
		for index in actors.size():
			var actor = actors[index]
			var clip: String = CLIPS[index / 2]
			var length: float = actor.player.get_animation(clip).length
			# Actual seconds at 60Hz, not normalized slow-motion warnings/attacks.
			actor.reset_sample()
			actor.play_clip(clip)
			var seconds := float(frame) / 60.0
			var sample_time := fmod(seconds, length) if clip in ["idle", "walk"] else minf(seconds, length)
			actor.player.seek(sample_time, true)
		await process_frame
		await RenderingServer.frame_post_draw
		var capture := viewport.get_texture().get_image()
		if capture == null or capture.is_empty() or capture.get_size() != SIZE:
			push_error("TEST FAIL: Native monster render is empty")
			quit(1)
			return
		var frame_hash := hash(capture.get_data())
		if frame > 0 and frame_hash != previous_hash:
			different_frames += 1
		previous_hash = frame_hash
		var destination := ProjectSettings.globalize_path(motion_path().path_join("frame_%03d.png" % frame))
		if capture.save_png(destination) != OK:
			push_error("TEST FAIL: Native monster motion frame save failed")
			quit(1)
			return
	if different_frames < 55:
		push_error("TEST FAIL: Native monster render is static")
		quit(1)
		return
	viewport.queue_free()
	await process_frame
	print("RENDER PASS: %s 60 frames, %d adjacent pixel changes, %dx%d" % [sample_name(), different_frames, SIZE.x, SIZE.y])
	quit(0)
