extends SceneTree

const Support = preload("res://scripts/tests/TestSupport.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NurseryChapterTest " + message)

func _initialize() -> void:
	call_deferred("_run")

func _fixture(scene: PackedScene, path: String) -> Node:
	var chapter = scene.instantiate()
	chapter.campaign_store_path = path
	chapter.audio_enabled = false
	chapter.run_seed = 521
	root.add_child(chapter)
	return chapter

func _battle(chapter: Node) -> void:
	chapter.ui.proceed_button.pressed.emit()
	check(chapter.director.state == chapter.director.State.COMBAT and not paused, "UI did not start actual combat")
	# Real actors/health/transactions, accelerated fixture damage and spawn clocks;
	# this test is NOT ordinary-input gameplay or visual acceptance.
	chapter.director.set_process(false)
	chapter.player.set_physics_process(false)
	for step in 100:
		chapter.director._process(0.25)
		if chapter.director.spawn_queue.is_empty() and chapter.director.active_portals.is_empty():
			break
	check(not chapter.director.get_active_enemies().is_empty(), "UI encounter created no real enemies")
	for enemy in chapter.director.get_active_enemies().duplicate():
		enemy.take_damage(1e9, &"test")
	if chapter.director.encounter_index == 0:
		check(chapter.player.overdrive_active, "real rapid kills lost existing overdrive gameplay in chapter")
	check(chapter.player.overdrive_active == chapter.overdrive_active, "player and chapter overdrive desynchronized")
	await process_frame
	await process_frame
	chapter.director._process(0)
	chapter.director._process(3.1)
	check(paused and chapter.ui.settlement_screen.visible, "real clear did not present paused build rewards")
	check(not chapter.ui.settlement_screen.title_label.text.contains("波次"), "chapter still calls encounters waves")
	chapter.ui.settlement_screen.offer_buttons[0].pressed.emit()
	check(chapter.growth.get_settlement_state().reward_claimed, "UI reward did not affect real build")
	chapter.ui.settlement_screen.close_button.pressed.emit()

func _dispose(chapter: Node) -> void:
	paused = false
	Support.stop_audio(chapter.audio)
	chapter.free()
	await process_frame

func _run() -> void:
	var scene_path := "res://scenes/campaign/nursery_chapter.tscn"
	check(FileAccess.file_exists(scene_path), "actual chapter scene absent")
	if failures > 0:
		quit(1)
		return
	var packed = load(scene_path)
	var path := "user://nursery_chapter_%d.json" % OS.get_process_id()
	check(not FileAccess.file_exists(path), "test must not touch existing progress")
	var chapter = _fixture(packed, path)
	check(chapter.map.map_seed == 521 and chapter.player is CharacterBody2D, "real map/player not assembled")
	check(chapter.ui.flow_panel.visible and chapter.ui.proceed_button.disabled, "entry skips natural entrance or hides intro")
	check(not chapter.save_clear(1) and not FileAccess.file_exists(path), "forged early clear persisted unlock")
	for frame in 360:
		if not chapter.player.is_entrance_active():
			break
		await process_frame
	check(not chapter.ui.proceed_button.disabled, "natural entrance never enabled chapter UI")
	await _battle(chapter)
	check(chapter.director.encounter_index == 1 and chapter.ui.flow_panel.visible, "reward UI failed to prepare next encounter")
	await _battle(chapter)
	check(chapter.ui.supply_button.visible and chapter.ui.risk_button.visible, "actual route choices absent")
	chapter.ui.supply_button.pressed.emit()
	check(chapter.director.route == &"supply" and chapter.ui.proceed_button.visible, "UI route did not reach Boss prep")
	check(chapter.ui.flow_description.text.contains("旧资源"), "transitional Boss masquerades as new art")
	chapter.ui.proceed_button.pressed.emit()
	var boss = chapter.director.get_active_boss()
	check(boss != null and chapter.ui.boss_health_bar.visible, "UI did not spawn/show actual Boss")
	check(chapter.ui.wave_label.text.contains("首领"), "Boss HUD still reports the completed spore encounter")
	chapter._toggle_pause()
	check(paused and chapter.ui.resume_button.visible, "combat pause UI broken")
	chapter.ui.resume_button.pressed.emit()
	check(not paused and not chapter.ui.flow_root.visible and not chapter.ui.flow_panel.is_visible_in_tree(), "resume does not restore combat")
	chapter._toggle_pause()
	var pause_key := InputEventKey.new()
	pause_key.pressed = true
	pause_key.keycode = KEY_SPACE
	chapter.ui._unhandled_input(pause_key)
	check(not paused, "documented Space resume fails on chapter pause overlay")
	boss.died.emit(boss, 60, &"test")
	check(not chapter.clear_saved and not FileAccess.file_exists(path), "live Boss signal saved chapter")
	for frame in 360:
		if boss.entrance_resolved:
			break
		await process_frame
	# A real filesystem denial at the .tmp boundary; no mocked store outcome.
	check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "save-failure fixture could not reserve its own temporary path")
	check(boss.take_damage(1e9, &"test"), "natural post-entrance Boss damage failed")
	await process_frame
	await process_frame
	check(not chapter.clear_saved and not chapter.progress.has_cleared(1) and not FileAccess.file_exists(path), "failed write still exposed permanent unlock")
	check(chapter.ui.retry_save_button.visible and chapter.ui.flow_title.text.contains("保存失败"), "actual save failure has no retry feedback")
	check(DirAccess.remove_absolute(path + ".tmp") == OK, "owned empty failure fixture removal failed")
	chapter.ui.retry_save_button.pressed.emit()
	check(chapter.clear_saved and paused and chapter.ui.flow_title.text.contains("通关"), "real accepted Boss clear not saved/shown")
	var restored := Progress.new()
	check(Store.new(path).load_progress(restored) == Store.LoadResult.LOADED and restored.is_unlocked(2), "fresh progress load lost chapter unlock")
	var hash_before := FileAccess.get_sha256(path)
	check(not chapter.save_clear(2) and not chapter.save_clear(1), "clear callback replay or wrong chapter accepted")
	check(FileAccess.get_sha256(path) == hash_before, "duplicate callback changed committed progress")
	await _dispose(chapter)
	var replay = _fixture(packed, path)
	check(replay.progress.has_cleared(1) and replay.director.state == replay.director.State.INTRO, "replay lost permanent clear or failed to start fresh")
	replay.player.health.damage(1e9, true)
	check(replay.ui.flow_title.text.contains("失败") and paused, "actual death lacks result screen")
	check(FileAccess.get_sha256(path) == hash_before, "death erased permanent progress")
	await _dispose(replay)
	DirAccess.remove_absolute(path)
	var corrupt_path := path + ".corrupt"
	var file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("invalid campaign")
	file.close()
	var bad_hash := FileAccess.get_sha256(corrupt_path)
	var corrupt = _fixture(packed, corrupt_path)
	check(corrupt.player == null and corrupt.ui.flow_description.text.contains("存档"), "corrupt chapter load silently starts gameplay")
	check(not corrupt.save_clear(1) and FileAccess.get_sha256(corrupt_path) == bad_hash, "corrupt progress overwritten")
	await _dispose(corrupt)
	DirAccess.remove_absolute(corrupt_path)
	if failures == 0:
		print("TEST PASS: NurseryChapterTest %d" % assertions)
	quit(1 if failures > 0 else 0)
