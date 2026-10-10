extends SceneTree
const MainScene = preload("res://scenes/Main.tscn")
const EnemySource = preload("res://scripts/actors/Enemy.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("SPORELING PACK FAIL: " + label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(not FileAccess.file_exists("res://scripts/art/VerifySporelingPack.gd"), "pack includes author scripts / sees workspace")
	var main = MainScene.instantiate()
	main.audio_enabled = false
	main.campaign_store_path = "user://sporeling_pack_%d/campaign.json" % OS.get_process_id()
	root.add_child(main)
	current_scene = main
	main.ui.start_screen.regions_button.pressed.emit()
	main.ui.start_screen.launch_button.pressed.emit()
	await process_frame
	await process_frame
	var chapter = current_scene
	check(chapter.get_script().resource_path.ends_with("NurseryChapter.gd"), "real first chapter did not enter")
	while chapter.player.is_entrance_active():
		await process_frame
	chapter.ui.proceed_button.pressed.emit()
	var observed := false
	for frame in 480:
		for enemy in chapter.director.get_active_enemies():
			if enemy.kind == EnemySource.EnemyKind.SPITTER:
				var view = enemy.native_visual
				check(view != null and enemy.static_visual == null, "actual packed spitter still raster")
				check(view.scene_file_path.ends_with("sporeling_paper_v1.tscn") and view.skeleton.get_bone_count() == 14, "packed spore rig missing")
				check(view.player.has_animation("attack") and view.player.has_animation("death") and enemy.should_show_health_bar(), "packed clips/bar missing")
				observed = true
				break
		if observed:
			break
		await process_frame
	check(observed, "no natural spitter spawn observed")
	chapter._toggle_pause()
	chapter.ui.return_button.pressed.emit()
	await process_frame
	await process_frame
	var returned = current_scene
	check(returned.ui.start_screen.visible, "pack Back failed")
	print("SPORELING PACK %s: actual Main/chapter, natural spore enemy/14 bones/clips/bar and Back" % ["FAIL" if failures else "PASS"])
	returned._request_close()
