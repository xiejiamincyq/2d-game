extends SceneTree
## Isolated real-window mouse coordinate diagnosis, not a gameplay proof.
const Scene = preload("res://scenes/campaign/foundry_chapter.tscn")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Support = preload("../tests/TestSupport.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "user://foundry_cursor_probe_%d.json" % OS.get_process_id()
	if FileAccess.file_exists(path): quit(1); return
	var progress := Progress.new(); progress.record_boss_defeat(1)
	if not Store.new(path).save_progress(progress): quit(1); return
	var chapter = Scene.instantiate(); chapter.audio_enabled = false; chapter.campaign_store_path = path
	root.add_child(chapter)
	print("CURSOR WINDOW: position=%s size=%s screen=%s" % [str(root.position),str(root.size),str(DisplayServer.screen_get_size())])
	for frame in 180:
		if not chapter.player.is_entrance_active(): break
		await process_frame
	chapter.ui.proceed_button.pressed.emit(); chapter.director.set_process(false)
	for index in 16:
		var at := Vector2(440,360) if index%2==0 else Vector2(840,360)
		var before := root.get_mouse_position()
		Input.warp_mouse(at)
		await process_frame
		var warped := root.get_mouse_position()
		var motion := InputEventMouseMotion.new(); motion.position = at
		if index>=8: motion.global_position = at
		root.push_input(motion,true)
		await physics_frame; await process_frame
		print("CURSOR index=%d before=%s warped=%s pushed=%s world=%s transform=%s" % [index,str(before),str(warped),str(root.get_mouse_position()),str(chapter.player.get_global_mouse_position()),str(root.get_canvas_transform())])
	paused = false; Support.stop_audio(chapter.audio); chapter.free(); await process_frame
	DirAccess.remove_absolute(path)
	quit(0)
