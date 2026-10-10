extends SceneTree
const MainScene = preload("res://scenes/Main.tscn")
const EnemySource = preload("res://scripts/actors/Enemy.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("CINDER PACK FAIL: " + label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(not FileAccess.file_exists("res://scripts/art/VerifyCinderRunnerPack.gd"),"pack sees workspace / author script")
	var main = MainScene.instantiate()
	main.audio_enabled = false
	main.campaign_store_path = "user://cinder_pack_%d/campaign.json"%OS.get_process_id()
	root.add_child(main)
	current_scene = main
	main.snapshot_store.save_path = "user://cinder_pack_%d/run.json"%OS.get_process_id()
	main.ui.start_screen.start_button.pressed.emit()
	var observed := false
	for frame in 900:
		for enemy in main.wave_director.active_enemies:
			if is_instance_valid(enemy) and enemy.kind == EnemySource.EnemyKind.DASHER:
				var view = enemy.native_visual
				check(view != null and enemy.static_visual == null,"packed runner still raster")
				if view != null:
					check(view.scene_file_path.ends_with("cinder_runner_paper_v1.tscn") and view.skeleton.get_bone_count() == 15,"packed rig missing")
					check(view.player.has_animation("attack") and view.player.has_animation("death") and enemy.should_show_health_bar(),"new clips/bar missing")
				observed = true
				break
		if observed:
			break
		await physics_frame
		await process_frame
	check(observed,"no natural runner in actual legacy wave")
	print("CINDER PACK %s: actual Main legacy wave, natural runner/15 bones/new clips/bar; not second chapter"%["FAIL" if failures else "PASS"])
	if failures:
		main.queue_free()
		await process_frame
		quit(1)
	else:
		main._request_close()
