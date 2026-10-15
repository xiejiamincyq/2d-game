extends "SaltChapterTest.gd"
## Actual chapter/UI/store; accelerated lethal fixture, NOT ordinary victory.
const ActualBoss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Sentinel = preload("res://scripts/actors/EchoSentinelEnemy.gd")
const Shade = preload("res://scripts/actors/CirclingShadeEnemy.gd")
func check(ok: bool,label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoChapterTest "+label)
func battle(chapter: Node,expected_beats: int) -> void:
	chapter.ui.proceed_button.pressed.emit()
	check(chapter.director.state==chapter.director.State.COMBAT and not paused,"actual fifth UI battle")
	check(chapter.map.echo_field.active and chapter.map.echo_field.get_children().filter(func(n): return n.enabled).size()==expected_beats,"actual beat pressure")
	chapter._toggle_pause()
	var frozen: Array=Support.trap_field_snapshot(chapter.map.echo_field)
	await physics_frame; await physics_frame
	check(paused and Support.trap_field_snapshot(chapter.map.echo_field)==frozen,"pause must freeze plate stage/clock/HP")
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
		check((actor is Sentinel or actor is Shade) and actor.get_visual_node().skeleton!=null and actor.should_show_health_bar(),"generic/raster/unlabelled actor")
		actor.take_damage(1e9,&"test")
	await process_frame; await process_frame
	chapter.director._process(0); chapter.director._process(3.1)
	check(paused and chapter.ui.settlement_screen.visible and not chapter.map.echo_field.active,"reward lacks UI or retains clocks")
	chapter.ui.settlement_screen.offer_buttons[0].pressed.emit()
	check(chapter.growth.get_settlement_state().reward_claimed,"actual build reward missing")
	chapter.ui.settlement_screen.close_button.pressed.emit()
func run() -> void:
	var source := "res://scenes/campaign/echo_chapter.tscn"
	check(ResourceLoader.exists(source),"actual fifth chapter scene absent")
	if failures: quit(1); return
	var packed: PackedScene = load(source)
	var path := "user://echo_chapter_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"),"must not touch existing save")
	if failures: quit(1); return
	var locked = fixture(packed,path)
	check(locked.player==null and locked.ui.flow_description.text.contains("解锁") and not FileAccess.file_exists(path),"direct fifth scene bypasses unlock")
	await dispose(locked)
	var initial := Progress.new()
	for chapter in range(1,5): check(initial.record_boss_defeat(chapter),"sequential predecessor fixture")
	check(Store.new(path).save_progress(initial),"isolated predecessor save")
	var chapter = fixture(packed,path,521)
	check(chapter.get_script().get_base_script()==load("res://scripts/campaign/ChapterRun.gd"),"fifth duplicates shared chapter coordinator")
	check(chapter.map.map_seed==521 and chapter.director.echo_field==chapter.map.echo_field,"actual map/clock binding")
	check(chapter.ui.flow_title.text.contains("第5关") and chapter.ui.flow_description.text.contains("回声墓庭") and chapter.ui.risk_button.text.contains("四钟余拍"),"fifth intro/risk wording")
	check(not chapter.save_clear(4) and not chapter.save_clear(5),"forged early clear")
	await entrance(chapter); await battle(chapter,2); await battle(chapter,2)
	chapter.ui.risk_button.pressed.emit(); await battle(chapter,4)
	check(Support.claim_chapter_finale(chapter),"risk must traverse real finale UI before Boss")
	check(chapter.ui.flow_description.text.contains("钟槌") and chapter.ui.flow_description.text.contains("双坠") and chapter.ui.flow_description.text.contains("冠钟"),"actual three-action hint absent")
	chapter.ui.proceed_button.pressed.emit()
	var boss = chapter.director.get_active_boss()
	check(boss is ActualBoss and boss.get_visual_node().skeleton.get_bone_count()==26 and chapter.ui.boss_health_bar.visible and not chapter.map.echo_field.active,"actual Boss/HUD or cooled clock missing")
	var before := FileAccess.get_sha256(path); boss.died.emit(boss,60,&"test")
	check(not chapter.clear_saved and FileAccess.get_sha256(path)==before,"living forged death persisted clear")
	for _frame in 360:
		if boss.entrance_resolved: break
		await process_frame
	check(DirAccess.make_dir_absolute(path+".journey.tmp")==OK,"owned save-denial fixture")
	check(boss.take_damage(1e9,&"test"),"actual post-entrance death")
	await process_frame; await process_frame
	check(not chapter.clear_saved and not chapter.progress.has_cleared(5) and FileAccess.get_sha256(path)==before and chapter.ui.retry_save_button.visible,"save failure exposes fake unlock or lacks retry")
	check(DirAccess.remove_absolute(path+".journey.tmp")==OK,"owned empty denial directory cleanup")
	chapter.ui.retry_save_button.pressed.emit()
	check(Support.claim_chapter_carry(chapter),"real carry choice finalizes clear")
	var restored := Progress.new()
	check(chapter.clear_saved and Support.restore_journey_progress(path,restored) and restored.has_cleared(5) and restored.is_unlocked(6) and not restored.is_unlocked(7) and not restored.is_campaign_complete(),"true fifth clear fails adjacent save or fabricates sixth clear")
	var saved_hash := FileAccess.get_sha256(path)
	check(not chapter.save_clear(4) and not chapter.save_clear(5) and not chapter.save_clear(6) and FileAccess.get_sha256(path)==saved_hash,"duplicate/wrong clear changes save")
	chapter.ui.replay_button.pressed.emit(); await process_frame; await process_frame
	var replay = current_scene
	check(replay!=chapter and replay.get_script().resource_path.ends_with("EchoChapter.gd") and replay.run_seed!=521 and replay.progress.has_cleared(5),"replay loses chapter/seed/progress")
	replay.player.health.damage(1e9,true)
	check(paused and replay.ui.flow_title.text.contains("失败") and FileAccess.get_sha256(path)==saved_hash,"death erased permanent unlock")
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
	check(supply.clear_saved and supply.progress.is_unlocked(6) and not supply.progress.is_unlocked(7) and FileAccess.get_sha256(path)==saved_hash,"replay skips or rewrites gate")
	await dispose(supply)
	check(DirAccess.remove_absolute(path)==OK,"owned isolated save cleanup")
	check(Support.cleanup_journey_fixture(path),"owned journey fixture cleanup")
	if FileAccess.file_exists(path+".bak"): check(DirAccess.remove_absolute(path+".bak")==OK,"owned isolated backup cleanup")
	if not failures: print("TEST PASS: EchoChapterTest %d"%assertions)
	quit(1 if failures else 0)
