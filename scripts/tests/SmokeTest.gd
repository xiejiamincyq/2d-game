extends SceneTree
## Product smoke: real tent -> chapter -> encounter reward -> tent.
## Combat damage/collection clocks are controlled, not a natural victory claim.
const MainScene=preload("res://scenes/Main.tscn")
const Main=preload("res://scripts/Main.gd")
const Support=preload("TestSupport.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: SmokeTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path:="user://campaign_smoke_%d_%d.json"%[OS.get_process_id(),Time.get_ticks_usec()]
	var tent: Node=MainScene.instantiate(); tent.audio_enabled=false; tent.campaign_store_path=path
	root.add_child(tent); current_scene=tent
	check(tent.get_script()==Main and tent.ui.start_screen.visible and tent.get_node_or_null("World")==null,"product boots to tent, not retired arena")
	check(not tent.has_method("_start_run") and not tent.ui.aim_reticle.visible,"legacy entry or active reticle remains")
	tent.ui.start_button.pressed.emit()
	await process_frame; await process_frame
	var chapter: Node=current_scene
	check(chapter!=tent and chapter.has_method("_chapter_number"),"actual primary did not enter chapter")
	if chapter==tent:
		Support.stop_audio(tent.audio); tent.free(); quit(1); return
	check(chapter._chapter_number()==1 and chapter.run_loop==1,"fresh journal skipped first chapter/loop")
	check(chapter.map.process_mode==Node.PROCESS_MODE_PAUSABLE and chapter.player.process_mode in [Node.PROCESS_MODE_INHERIT,Node.PROCESS_MODE_PAUSABLE],"actual combat tree is not pausable")
	check(chapter.player.health.max_health==100 and chapter.player.shield==20 and chapter.growth.coins==0,"actual fresh player has wrong base resources")
	chapter.player.advance_entrance(chapter.player.get_entrance_duration()+0.01)
	await process_frame
	check(chapter.director.state==chapter.director.State.INTRO and paused,"entrance did not retain intro gate")
	chapter.ui.proceed_button.pressed.emit()
	check(chapter.director.state==chapter.director.State.COMBAT and not paused and not chapter.ui.flow_root.visible,"real proceed did not resume combat")
	chapter.ui.pause_button.pressed.emit()
	check(chapter.manually_paused and paused and chapter.ui.resume_button.visible and not chapter.player.can_process(),"manual pause did not freeze actual player/state/UI")
	check(chapter.ui.flow_description.text.contains("金币") and chapter.ui.flow_description.text.contains("继承"),"actual pause does not explain current journey checkpoint retention")
	chapter.ui.resume_button.pressed.emit()
	check(not chapter.manually_paused and not paused,"manual resume did not restore combat")
	chapter.director.set_process(false); chapter.player.set_physics_process(false)
	for step in 80:
		chapter.director._process(0.2)
		for actor in chapter.director.get_active_enemies(): actor.set_physics_process(false)
		if chapter.director.spawn_queue.is_empty() and chapter.director.active_portals.is_empty(): break
	check(not chapter.director.get_active_enemies().is_empty(),"actual portal actors absent")
	for actor in chapter.director.get_active_enemies().duplicate(): actor.take_damage(1e9,&"test")
	await process_frame; await process_frame; await physics_frame
	for pickup in chapter.pickups.get_children():
		if pickup is CoinPickup: pickup._physics_process(10)
	chapter.director._process(0); chapter.director._process(3.1)
	check(paused and chapter.ui.settlement_screen.visible and chapter.director.state==chapter.director.State.REWARD,"real deaths did not open actual encounter reward")
	check(chapter.growth.coins>0 and chapter.kills>0,"actual combat rewards/stats absent")
	var balance: int=chapter.growth.coins
	var claim: Dictionary={}
	for button in chapter.ui.settlement_screen.offer_buttons:
		if button.visible and not button.disabled:
			button.pressed.emit()
			claim=chapter.growth.get_settlement_state()
			break
	check(not claim.is_empty() and claim.reward_claimed and chapter.growth.coins==balance,"free choice did not grant reward or charged coins")
	chapter.ui.settlement_screen.close_button.pressed.emit()
	check(paused and chapter.director.state==chapter.director.State.INTRO and chapter.director.encounter_index==1,"reward completion did not prepare next encounter")
	check(not chapter.director.has_method("prepare_next_wave"),"product still exposes old wave progression")
	chapter.ui.return_button.pressed.emit()
	await process_frame; await process_frame
	var returned: Node=current_scene
	check(returned!=chapter and returned.get_script()==Main and returned.ui.start_screen.visible,"Back did not reach product tent")
	check(returned.campaign_session.journey.get_build().coins==balance and returned.campaign_session.journey.get_entry().chapter==1,"aborted encounter lost balance or falsely cleared chapter")
	Support.stop_audio(returned.audio); returned.free(); paused=false; await process_frame
	check(Support.cleanup_journey_fixture(path),"owned journal cleanup")
	check(not FileAccess.file_exists(path),"smoke fabricated permanent unlock file")
	if failures==0: print("TEST PASS: SmokeTest %d"%checks)
	quit(1 if failures else 0)
