extends SceneTree
## Real chapter/UI/store transactions with accelerated fixture combat, not a
## normal-input balance/visual acceptance or a real user's campaign save.
const Support = preload("TestSupport.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
var assertions := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: FoundryChapterTest " + message)
func _initialize() -> void: call_deferred("_run")
func _fixture(packed: PackedScene, path: String, seed_value := 733) -> Node:
	var chapter = packed.instantiate()
	chapter.audio_enabled = false
	chapter.campaign_store_path = path
	chapter.run_seed = seed_value
	root.add_child(chapter)
	current_scene = chapter
	return chapter
func _dispose(chapter: Node) -> void:
	paused = false
	Support.stop_audio(chapter.audio)
	chapter.free()
	await process_frame
func _wait_entrance(chapter: Node) -> void:
	for frame in 360:
		if not chapter.player.is_entrance_active(): break
		await process_frame
	check(not chapter.ui.proceed_button.disabled, "natural entrance never enabled entry")
func _battle(chapter: Node) -> void:
	chapter.ui.proceed_button.pressed.emit()
	check(chapter.director.state == chapter.director.State.COMBAT and not paused, "real UI did not start encounter")
	check(chapter.map.heat_field.active, "combat did not activate heat field")
	chapter._toggle_pause()
	var frozen: Array=Support.trap_field_snapshot(chapter.map.heat_field)
	await physics_frame
	await physics_frame
	await process_frame
	check(paused and Support.trap_field_snapshot(chapter.map.heat_field)==frozen, "real pause must freeze plate stage/clock/HP")
	chapter.ui.resume_button.pressed.emit()
	await physics_frame
	await physics_frame
	await process_frame
	check(not paused and chapter.map.heat_field.get_children().all(func(plate): return plate.stage==plate.Stage.READY and is_zero_approx(plate.elapsed)), "resume must not trigger an unstepped plate")
	chapter.director.set_process(false)
	chapter.player.set_physics_process(false)
	for step in 120:
		chapter.director._process(0.25)
		if chapter.director.spawn_queue.is_empty() and chapter.director.active_portals.is_empty(): break
	var enemies: Array = chapter.director.get_active_enemies().duplicate()
	check(not enemies.is_empty(), "actual encounter has no real regional enemies")
	for enemy in enemies:
		check(enemy.get_script().resource_path in ["res://scripts/actors/Enemy.gd", "res://scripts/actors/EmberSparkEnemy.gd"] and enemy.get_visual_node().skeleton != null, "wrong regional enemy family")
		enemy.take_damage(1e9, &"test")
	await process_frame
	await process_frame
	chapter.director._process(0)
	chapter.director._process(3.1)
	check(paused and chapter.ui.settlement_screen.visible, "clear failed to present actual build rewards")
	check(not chapter.map.heat_field.active, "heat remained armed in reward modal")
	check(not chapter.ui.settlement_screen.title_label.text.contains("波次"), "chapter reward still uses wave wording")
	chapter.ui.settlement_screen.offer_buttons[0].pressed.emit()
	check(chapter.growth.get_settlement_state().reward_claimed, "UI did not grant real build")
	chapter.ui.settlement_screen.close_button.pressed.emit()
func _run() -> void:
	var scene_path := "res://scenes/campaign/foundry_chapter.tscn"
	check(ResourceLoader.exists(scene_path), "second chapter playable scene absent")
	if failures > 0:
		quit(1)
		return
	var packed: PackedScene = load(scene_path)
	var path := "user://foundry_chapter_%d.json" % OS.get_process_id()
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"), "test must not touch existing save")
	if failures > 0:
		quit(1)
		return
	var locked = _fixture(packed, path)
	check(locked.player == null and locked.ui.flow_description.text.contains("解锁"), "direct scene bypasses sequential unlock")
	check(not FileAccess.file_exists(path), "locked scene wrote save")
	await _dispose(locked)
	var initial := Progress.new()
	check(initial.record_boss_defeat(1) and Store.new(path).save_progress(initial), "isolated first-clear fixture could not be prepared")
	var chapter = _fixture(packed, path)
	check(chapter.get_script().get_base_script() == load("res://scripts/campaign/ChapterRun.gd"), "second chapter duplicated common flow")
	check(chapter.map.map_seed == 733 and chapter.player is CharacterBody2D, "actual foundry map/player absent")
	check(chapter.director.heat_field == chapter.map.heat_field, "actual map heat owner not bound")
	check(chapter.ui.flow_title.text.contains("第2关") and chapter.ui.flow_description.text.contains("余烬铸坊"), "foundry intro uses first-chapter text")
	check(chapter.ui.wave_label.text.contains("第2关") and not chapter.ui.wave_label.text.contains("波次"), "second intro HUD still uses old wave placeholders")
	check(chapter.ui.risk_button.text.contains("过热工位") and not chapter.ui.risk_button.text.contains("根巢"), "foundry risk caption stale")
	check(not chapter.save_clear(1) and not chapter.save_clear(2), "early/wrong-chapter forged clear accepted")
	await _wait_entrance(chapter)
	await _battle(chapter)
	check(chapter.director.encounter_index == 1, "first reward did not continue to second encounter")
	await _battle(chapter)
	check(chapter.ui.risk_button.visible and chapter.ui.supply_button.visible, "route modal absent")
	chapter.ui.risk_button.pressed.emit()
	check(chapter.director.route == &"risk" and chapter.director.encounter_index == 2, "risk skipped extra encounter")
	await _battle(chapter)
	check(Support.claim_chapter_finale(chapter), "risk must pass real finale UI before Boss")
	check(chapter.ui.proceed_button.visible and not chapter.ui.proceed_button.text.contains("过渡"), "Boss button still transitional")
	check(chapter.ui.flow_description.text.contains("短扇喷") and chapter.ui.flow_description.text.contains("冲撞") and chapter.ui.flow_description.text.contains("热喷口"), "Boss prep missing actual attacks")
	chapter.ui.proceed_button.pressed.emit()
	var boss = chapter.director.get_active_boss()
	check(boss != null and chapter.ui.boss_health_bar.visible, "Boss ownership/HUD absent")
	check(chapter.ui.wave_label.text.contains("第2关") and chapter.ui.wave_label.text.contains("炉心督工"), "Boss HUD names wrong chapter")
	check(boss.get_visual_node().skeleton.get_bone_count() == 23, "actual native Furnace rig bypassed")
	check(not chapter.map.heat_field.active, "encounter heat improperly continues during Boss fight")
	chapter._toggle_pause()
	check(paused and chapter.ui.resume_button.visible, "Boss pause broken")
	chapter.ui.resume_button.pressed.emit()
	check(not paused, "Boss resume broken")
	var previous_hash := FileAccess.get_sha256(path)
	boss.died.emit(boss, 60, &"test")
	check(not chapter.clear_saved and FileAccess.get_sha256(path) == previous_hash, "live Boss signal persisted false clear")
	for frame in 360:
		if boss.entrance_resolved: break
		await process_frame
	check(DirAccess.make_dir_absolute(path + ".journey.tmp") == OK, "save-denial fixture could not reserve owned tmp")
	check(boss.take_damage(1e9, &"test"), "actual post-entrance damage did not defeat Boss")
	check(chapter.ui.stats_label.text.begins_with("击杀 %d " % chapter.kills), "terminal kill HUD relies on a future unpaused frame")
	await process_frame
	await process_frame
	check(not chapter.clear_saved and not chapter.progress.has_cleared(2) and FileAccess.get_sha256(path) == previous_hash, "failed write exposed permanent second clear")
	check(chapter.ui.retry_save_button.visible, "save error has no retry")
	check(DirAccess.remove_absolute(path + ".journey.tmp") == OK, "owned empty tmp fixture removal failed")
	chapter.ui.retry_save_button.pressed.emit()
	check(Support.claim_chapter_carry(chapter), "earned ordinary inheritance UI required")
	check(chapter.clear_saved and paused and chapter.ui.flow_title.text.contains("第2关通关"), "real Boss clear not saved/shown")
	var restored := Progress.new()
	check(Support.restore_journey_progress(path, restored) and restored.has_cleared(2) and restored.is_unlocked(3), "second clear failed permanent third unlock")
	var clear_hash := FileAccess.get_sha256(path)
	check(not chapter.save_clear(1) and not chapter.save_clear(2) and not chapter.save_clear(3), "repeated/wrong callback accepted")
	check(FileAccess.get_sha256(path) == clear_hash, "duplicate callback rewrote committed save")
	chapter.audio.set_bgm_volume(0.37)
	chapter.audio.set_bgm_muted(true)
	chapter.ui.replay_button.pressed.emit()
	await process_frame
	await process_frame
	var replay = current_scene
	check(replay != chapter and replay.get_script().resource_path.ends_with("FoundryChapter.gd"), "replay switched to first chapter")
	check(replay.run_seed != 733 and replay.progress.has_cleared(2), "replay reused seed or lost clear")
	check(is_equal_approx(replay.audio.bgm_volume_linear, 0.37) and replay.audio.bgm_muted, "replay lost audio settings")
	replay.player.health.damage(1e9, true)
	check(paused and replay.ui.flow_title.text.contains("失败") and FileAccess.get_sha256(path) == clear_hash, "death erased unlock or lacks terminal modal")
	await _dispose(replay)
	# The other route, already-cleared replay and return to the actual menu.
	var supply = _fixture(packed, path, 521)
	await _wait_entrance(supply)
	await _battle(supply)
	await _battle(supply)
	supply.ui.supply_button.pressed.emit()
	check(Support.claim_chapter_finale(supply), "supply must pass real finale UI before Boss")
	check(supply.director.route == &"supply" and supply.director.state == supply.director.State.BOSS_READY, "supply route did not reach Boss after finale")
	supply.ui.proceed_button.pressed.emit()
	var replay_boss = supply.director.get_active_boss()
	for frame in 360:
		if replay_boss.entrance_resolved: break
		await process_frame
	check(replay_boss.take_damage(1e9, &"test"), "actual replay Boss did not die")
	await process_frame
	await process_frame
	check(supply.clear_saved and not supply.progress.is_unlocked(4) and FileAccess.get_sha256(path) == clear_hash, "replay advanced extra gate or rewrote permanent save")
	supply.ui.return_button.pressed.emit()
	await process_frame
	await process_frame
	var returned = current_scene
	check(returned.get_script().resource_path == "res://scripts/Main.gd" and returned.campaign_progress.has_cleared(2), "Back did not load actual Main with permanent progress")
	check(returned._can_start_campaign_chapter(3) and not returned._can_start_campaign_chapter(4), "actual second clear cannot launch completed third policy or opens future fourth")
	await _dispose(returned)
	check(DirAccess.remove_absolute(path) == OK, "owned isolated save cleanup failed")
	check(Support.cleanup_journey_fixture(path), "owned journey fixture cleanup failed")
	if FileAccess.file_exists(path + ".bak"): check(DirAccess.remove_absolute(path + ".bak") == OK, "owned isolated backup cleanup failed")
	if failures == 0: print("TEST PASS: FoundryChapterTest %d" % assertions)
	quit(1 if failures > 0 else 0)
