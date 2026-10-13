extends "SaltChapterTest.gd"
## Actual chapter/UI/store; controlled lethal fixture, NOT ordinary victory.
const Observer = preload("res://scripts/actors/RiftObserverBoss.gd")
const Cutter = preload("res://scripts/actors/SpaceCutterEnemy.gd")
const Elite = preload("res://scripts/actors/RiftEliteEnemy.gd")
func check(ok: bool,label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftChapterTest "+label)
func battle(chapter: Node,expected_faults: int) -> void:
	chapter.ui.proceed_button.pressed.emit()
	check(chapter.director.state==chapter.director.State.COMBAT and not paused,"actual sixth UI battle")
	check(chapter.map.rift_field.active and chapter.map.rift_field.get_children().filter(func(n): return n.enabled).size()==expected_faults,"actual fault pressure")
	chapter._toggle_pause(); await physics_frame; await physics_frame
	check(paused and chapter.map.rift_field.get_children().all(func(n): return n.state==n.State.INACTIVE),"pause retains fault danger")
	chapter.ui.resume_button.pressed.emit(); await physics_frame; await physics_frame
	check(not paused,"actual resume failed")
	chapter.director.set_process(false); chapter.player.set_physics_process(false)
	for _step in 120:
		chapter.director._process(0.25)
		if chapter.director.spawn_queue.is_empty() and chapter.director.active_portals.is_empty(): break
	var actors: Array = chapter.director.get_active_enemies().duplicate()
	check(not actors.is_empty(),"regional mixed encounter absent")
	for actor in actors:
		actor.set_physics_process(false)
		check((actor is Cutter or actor is Elite) and actor.get_visual_node().skeleton!=null and actor.should_show_health_bar(),"generic/raster/unlabelled actor")
		actor.take_damage(1e9,&"test")
	await process_frame; await process_frame
	chapter.director._process(0); chapter.director._process(3.1)
	check(paused and chapter.ui.settlement_screen.visible and not chapter.map.rift_field.active,"reward lacks UI or retains faults")
	chapter.ui.settlement_screen.offer_buttons[0].pressed.emit()
	check(chapter.growth.get_settlement_state().reward_claimed,"actual build reward missing")
	chapter.ui.settlement_screen.close_button.pressed.emit()
func run() -> void:
	var source := "res://scenes/campaign/rift_chapter.tscn"
	check(ResourceLoader.exists(source),"actual sixth chapter scene absent")
	if failures: quit(1); return
	var packed: PackedScene = load(source)
	var path := "user://rift_chapter_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak") and not DirAccess.dir_exists_absolute(path+".tmp"),"must not touch existing save")
	if failures: quit(1); return
	var locked = fixture(packed,path)
	check(locked.player==null and locked.ui.flow_description.text.contains("解锁") and not FileAccess.file_exists(path),"direct sixth scene bypasses unlock")
	await dispose(locked)
	var initial := Progress.new()
	for number in range(1,6): check(initial.record_boss_defeat(number),"sequential prerequisite fixture")
	check(Store.new(path).save_progress(initial),"isolated predecessor save")
	var chapter = fixture(packed,path,521)
	check(chapter.get_script().get_base_script()==load("res://scripts/campaign/ChapterRun.gd"),"sixth duplicates shared coordinator")
	check(chapter.map.map_seed==521 and chapter.director.rift_field==chapter.map.rift_field,"actual map/fault binding")
	check(chapter.ui.flow_title.text.contains("第6关") and chapter.ui.flow_description.text.contains("裂隙观测站") and chapter.ui.risk_button.text.contains("四区满载"),"sixth intro/risk wording")
	check(not chapter.save_clear(5) and not chapter.save_clear(6) and not chapter.save_clear(7),"forged early clear")
	await entrance(chapter); await battle(chapter,2); await battle(chapter,2)
	chapter.ui.risk_button.pressed.emit(); await battle(chapter,4)
	check(Support.claim_chapter_finale(chapter),"risk must traverse real finale UI before Boss")
	check(chapter.ui.flow_description.text.contains("窄束") and chapter.ui.flow_description.text.contains("探针") and chapter.ui.flow_description.text.contains("折射"),"actual three-action hint absent")
	chapter.ui.proceed_button.pressed.emit()
	var boss = chapter.director.get_active_boss()
	check(boss is Observer and boss.get_visual_node().skeleton.get_bone_count()==30 and chapter.ui.boss_health_bar.visible and not chapter.map.rift_field.active,"actual Boss/HUD or cooled field missing")
	var before := FileAccess.get_sha256(path); boss.died.emit(boss,60,&"test")
	check(not chapter.clear_saved and FileAccess.get_sha256(path)==before,"living forged death persists clear")
	for _frame in 360:
		if boss.entrance_resolved: break
		await process_frame
	check(DirAccess.make_dir_absolute(path+".tmp")==OK,"owned save-denial fixture")
	check(boss.take_damage(1e9,&"test"),"actual post-entrance death")
	await process_frame; await process_frame
	check(not chapter.clear_saved and not chapter.progress.has_cleared(6) and not chapter.progress.is_campaign_complete() and FileAccess.get_sha256(path)==before and chapter.ui.retry_save_button.visible,"save failure fabricates campaign completion or lacks retry")
	check(DirAccess.remove_absolute(path+".tmp")==OK,"owned empty denial directory cleanup")
	chapter.ui.retry_save_button.pressed.emit()
	var restored := Progress.new()
	check(chapter.clear_saved and Store.new(path).load_progress(restored)==Store.LoadResult.LOADED and restored.has_cleared(6) and restored.is_campaign_complete() and not restored.is_unlocked(7),"true sixth clear fails full completion or invents seventh")
	check(chapter.ui.flow_title.text.contains("第6关通关") and chapter.ui.flow_description.text.contains("六关探索已完成") and not chapter.ui.flow_description.text.contains("第7关"),"terminal UI lacks truthful campaign completion")
	var saved_hash := FileAccess.get_sha256(path)
	check(not chapter.save_clear(5) and not chapter.save_clear(6) and not chapter.save_clear(7) and FileAccess.get_sha256(path)==saved_hash,"duplicate/wrong clear changes save")
	chapter.ui.replay_button.pressed.emit(); await process_frame; await process_frame
	var replay = current_scene
	check(replay!=chapter and replay.get_script().resource_path.ends_with("RiftChapter.gd") and replay.run_seed!=521 and replay.progress.has_cleared(6),"replay loses chapter/seed/permanent completion")
	replay.player.health.damage(1e9,true)
	check(paused and replay.ui.flow_title.text.contains("失败") and FileAccess.get_sha256(path)==saved_hash,"death erases campaign completion")
	await dispose(replay)
	var supply = fixture(packed,path,733)
	await entrance(supply); await battle(supply,2); await battle(supply,2)
	supply.ui.supply_button.pressed.emit()
	check(Support.claim_chapter_finale(supply),"supply must traverse real finale UI before Boss")
	check(supply.director.route==&"supply" and supply.director.state==supply.director.State.BOSS_READY,"supply skips finale/adds encounter")
	supply.ui.proceed_button.pressed.emit(); var replay_boss = supply.director.get_active_boss()
	for _frame in 360:
		if replay_boss.entrance_resolved: break
		await process_frame
	check(replay_boss.take_damage(1e9,&"test"),"real replay Boss death")
	await process_frame; await process_frame
	check(supply.clear_saved and supply.progress.is_campaign_complete() and not supply.progress.is_unlocked(7) and FileAccess.get_sha256(path)==saved_hash,"replay rewrites save or invents seventh")
	supply.ui.return_button.pressed.emit(); await process_frame; await process_frame
	var returned = current_scene
	check(returned.get_script().resource_path=="res://scripts/Main.gd" and returned.campaign_store_path==path and returned.campaign_progress.has_cleared(6) and returned.campaign_progress.is_campaign_complete() and not returned._can_start_campaign_chapter(7),"Back loses actual permanent completion/path or creates seventh")
	await dispose(returned)
	check(DirAccess.remove_absolute(path)==OK,"owned isolated save cleanup")
	if FileAccess.file_exists(path+".bak"): check(DirAccess.remove_absolute(path+".bak")==OK,"owned isolated backup cleanup")
	if not failures: print("TEST PASS: RiftChapterTest %d"%assertions)
	quit(1 if failures else 0)
