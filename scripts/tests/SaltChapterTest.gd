extends SceneTree
## Actual chapter/UI/store, accelerated damage fixture; not natural victory.
const Support = preload("TestSupport.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
var assertions := 0
var failures := 0
func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("TEST FAIL: SaltChapterTest "+message)
func _initialize() -> void: call_deferred("run")
func fixture(packed: PackedScene,path: String,seed_value := 733) -> Node:
	var chapter = packed.instantiate(); chapter.audio_enabled = false
	chapter.campaign_store_path = path; chapter.run_seed = seed_value
	root.add_child(chapter); current_scene = chapter
	return chapter
func dispose(chapter: Node) -> void:
	paused = false; Support.stop_audio(chapter.audio); chapter.free(); await process_frame
func entrance(chapter: Node) -> void:
	for _frame in 360:
		if not chapter.player.is_entrance_active(): break
		await process_frame
	check(not chapter.ui.proceed_button.disabled,"entrance never enables start")
func battle(chapter: Node,expected_bands: int) -> void:
	chapter.ui.proceed_button.pressed.emit()
	check(chapter.director.state==chapter.director.State.COMBAT and not paused,"actual UI cannot begin encounter")
	check(chapter.map.tidal_field.active and chapter.map.tidal_field.get_children().filter(func(band): return band.enabled).size()==expected_bands,"wrong actual tide pressure")
	chapter._toggle_pause(); await physics_frame; await physics_frame; await process_frame
	check(paused and chapter.map.tidal_field.get_children().all(func(band): return band.state==band.State.INACTIVE),"pause leaves tide danger")
	chapter.ui.resume_button.pressed.emit(); await physics_frame; await physics_frame; await process_frame
	check(not paused,"real resume failed")
	chapter.director.set_process(false); chapter.player.set_physics_process(false)
	for _step in 120:
		chapter.director._process(0.25)
		if chapter.director.spawn_queue.is_empty() and chapter.director.active_portals.is_empty(): break
	var enemies: Array = chapter.director.get_active_enemies().duplicate()
	check(not enemies.is_empty(),"no actual salt enemies")
	for enemy in enemies:
		check(enemy.kind in [enemy.EnemyKind.SCRAPPER,enemy.EnemyKind.MARKSMAN] and enemy.get_visual_node().skeleton!=null,"foreign or raster enemy")
		enemy.take_damage(1e9,&"test")
	await process_frame; await process_frame
	chapter.director._process(0); chapter.director._process(3.1)
	check(paused and chapter.ui.settlement_screen.visible and not chapter.map.tidal_field.active,"reward lacks UI or retains tide")
	chapter.ui.settlement_screen.offer_buttons[0].pressed.emit()
	check(chapter.growth.get_settlement_state().reward_claimed,"actual build reward not granted")
	chapter.ui.settlement_screen.close_button.pressed.emit()
func run() -> void:
	var source := "res://scenes/campaign/salt_chapter.tscn"
	check(ResourceLoader.exists(source),"actual third chapter scene absent")
	if failures: quit(1); return
	var packed: PackedScene = load(source)
	var path := "user://salt_chapter_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"),"must not touch existing save")
	if failures: quit(1); return
	var locked = fixture(packed,path)
	check(locked.player==null and locked.ui.flow_description.text.contains("解锁") and not FileAccess.file_exists(path),"direct scene bypasses sequential unlock")
	await dispose(locked)
	var initial := Progress.new()
	check(initial.record_boss_defeat(1) and initial.record_boss_defeat(2) and Store.new(path).save_progress(initial),"isolated predecessor fixture failed")
	var chapter = fixture(packed,path)
	check(chapter.get_script().get_base_script()==load("res://scripts/campaign/ChapterRun.gd"),"salt duplicated common chapter flow")
	check(chapter.map.map_seed==733 and chapter.director.tidal_field==chapter.map.tidal_field,"actual salt map/field not bound")
	check(chapter.ui.flow_title.text.contains("第3关") and chapter.ui.flow_description.text.contains("盐蚀水道") and chapter.ui.wave_label.text.contains("第3关"),"chapter wording wrong")
	check(chapter.ui.risk_button.text.contains("四堤涨潮") and not chapter.ui.risk_button.text.contains("过热"),"risk wording wrong")
	check(not chapter.save_clear(2) and not chapter.save_clear(3),"forged early clear accepted")
	await entrance(chapter); await battle(chapter,2); await battle(chapter,2)
	chapter.ui.risk_button.pressed.emit()
	check(chapter.director.route==&"risk" and chapter.director.encounter_index==2,"risk skips extra battle")
	await battle(chapter,4)
	check(Support.claim_chapter_finale(chapter),"risk must traverse real finale UI before Boss")
	check(chapter.ui.flow_description.text.contains("空心环潮") and chapter.ui.flow_description.text.contains("侧钳") and chapter.ui.flow_description.text.contains("盐壳"),"prep missing actual attacks")
	chapter.ui.proceed_button.pressed.emit()
	var boss = chapter.director.get_active_boss()
	check(boss!=null and boss.get_script().resource_path=="res://scripts/actors/SaltTideBoss.gd" and boss.get_visual_node().skeleton.get_bone_count()==25 and chapter.ui.boss_health_bar.visible,"actual tide Boss/HUD absent")
	check(not chapter.map.tidal_field.active and chapter.ui.wave_label.text.contains("潮壳"),"Boss retains encounter tide or wrong name")
	var before := FileAccess.get_sha256(path)
	boss.died.emit(boss,60,&"test")
	check(not chapter.clear_saved and FileAccess.get_sha256(path)==before,"live forged Boss signal persisted clear")
	for _frame in 360:
		if boss.entrance_resolved: break
		await process_frame
	check(DirAccess.make_dir_absolute(path+".tmp")==OK,"owned save-denial fixture unavailable")
	check(boss.take_damage(1e9,&"test"),"actual post-entrance fatal damage refused")
	await process_frame; await process_frame
	check(not chapter.clear_saved and not chapter.progress.has_cleared(3) and FileAccess.get_sha256(path)==before and chapter.ui.retry_save_button.visible,"failed save exposes false unlock or no retry")
	check(DirAccess.remove_absolute(path+".tmp")==OK,"owned empty tmp cleanup failed")
	chapter.ui.retry_save_button.pressed.emit()
	check(chapter.clear_saved and paused and chapter.ui.flow_title.text.contains("第3关通关"),"actual clear not saved/shown")
	var restored := Progress.new()
	check(Store.new(path).load_progress(restored)==Store.LoadResult.LOADED and restored.has_cleared(3) and restored.is_unlocked(4) and not restored.is_unlocked(5),"real third clear doesn't unlock only fourth")
	var saved_hash := FileAccess.get_sha256(path)
	check(not chapter.save_clear(2) and not chapter.save_clear(3) and not chapter.save_clear(4) and FileAccess.get_sha256(path)==saved_hash,"duplicate/wrong callback changes progress")
	check(chapter.ui.stats_label.text.begins_with("击杀 %d "%chapter.kills),"terminal kill HUD stale")
	chapter.ui.replay_button.pressed.emit(); await process_frame; await process_frame
	var replay = current_scene
	check(replay!=chapter and replay.get_script().resource_path.ends_with("SaltChapter.gd") and replay.run_seed!=733 and replay.progress.has_cleared(3),"replay wrong chapter/seed/progress")
	replay.player.health.damage(1e9,true)
	check(paused and replay.ui.flow_title.text.contains("失败") and FileAccess.get_sha256(path)==saved_hash,"death erases unlock")
	await dispose(replay)
	var supply = fixture(packed,path,521)
	await entrance(supply); await battle(supply,2); await battle(supply,2)
	supply.ui.supply_button.pressed.emit()
	check(Support.claim_chapter_finale(supply),"supply must traverse real finale UI before Boss")
	check(supply.director.route==&"supply" and supply.director.state==supply.director.State.BOSS_READY,"supply doesn't reach Boss after finale")
	supply.ui.proceed_button.pressed.emit()
	var replay_boss = supply.director.get_active_boss()
	for _frame in 360:
		if replay_boss.entrance_resolved: break
		await process_frame
	check(replay_boss.take_damage(1e9,&"test"),"actual replay Boss damage refused")
	await process_frame; await process_frame
	check(supply.clear_saved and supply.progress.is_unlocked(4) and not supply.progress.is_unlocked(5) and FileAccess.get_sha256(path)==saved_hash,"replay skips gate or rewrites save")
	supply.ui.return_button.pressed.emit(); await process_frame; await process_frame
	var returned = current_scene
	check(returned.get_script().resource_path=="res://scripts/Main.gd" and returned.campaign_progress.has_cleared(3) and returned._can_start_campaign_chapter(4) and not returned._can_start_campaign_chapter(5),"Back loses third/fourth progress or launches unbuilt fifth")
	await dispose(returned)
	check(DirAccess.remove_absolute(path)==OK,"owned isolated save cleanup failed")
	if FileAccess.file_exists(path+".bak"): check(DirAccess.remove_absolute(path+".bak")==OK,"owned backup cleanup failed")
	if not failures: print("TEST PASS: SaltChapterTest %d"%assertions)
	quit(1 if failures else 0)
