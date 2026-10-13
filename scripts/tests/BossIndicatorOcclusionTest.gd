extends SceneTree
## Real Echo chapter/framing/Control geometry; controlled poses, not a normal run.
const Chapter = preload("res://scenes/campaign/echo_chapter.tscn")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Support = preload("TestSupport.gd")
var checks := 0
var failures := 0
var visible_samples := 0
var output := ""
var sources := {}
var captures := {}
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BossIndicatorOcclusionTest "+label)
func _initialize() -> void: call_deferred("run")
func complete_controlled_encounter(chapter: Node) -> void:
	# Accelerated lethal fixture, not ordinary play: traverse the real director
	# and reward UI, rather than editing settlement flags to unlock the Boss.
	chapter.ui.proceed_button.pressed.emit()
	check(chapter.director.state==chapter.director.State.COMBAT and not paused,"controlled encounter failed to start")
	for _step in 120:
		chapter.director._process(0.25)
		if chapter.director.spawn_queue.is_empty() and chapter.director.active_portals.is_empty(): break
	var enemies: Array = chapter.director.get_active_enemies().duplicate()
	check(not enemies.is_empty(),"controlled encounter spawned no real actors")
	for enemy in enemies:
		enemy.set_physics_process(false)
		enemy.take_damage(1e9,&"test")
	await process_frame; await process_frame
	chapter.director._process(0); chapter.director._process(3.1)
	check(chapter.director.state==chapter.director.State.REWARD and chapter.ui.settlement_screen.visible,"controlled encounter skipped actual reward")
	chapter.ui.settlement_screen.offer_buttons[0].pressed.emit()
	check(chapter.growth.get_settlement_state().reward_claimed,"controlled encounter reward not claimed")
	chapter.ui.settlement_screen.close_button.pressed.emit()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()==1 and args[0].is_valid_identifier() and DisplayServer.get_name()!="headless":
		output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
		check(not DirAccess.dir_exists_absolute(output),"fresh capture folder required")
		if failures: quit(1); return
		DirAccess.make_dir_recursive_absolute(output)
		for source in ["scripts/tests/BossIndicatorOcclusionTest.gd","scripts/ui/BossDirectionIndicator.gd","scripts/systems/BossCameraFraming.gd","scripts/campaign/EchoChapter.gd","scripts/campaign/ChapterRun.gd","scripts/campaign/ChapterRunDefinitions.gd","scripts/ui/ChapterRunUI.gd","scripts/actors/EchoBellPriestBoss.gd","scripts/components/NativeActorView.gd","scenes/actors/native/bell_priest_paper_v2.tscn","assets/art/actors/native/bell_priest_motion_v2.tres","scripts/world/EchoArenaLayout.gd"]:
			sources[source] = FileAccess.get_sha256("res://"+source)
	var path := "user://echo_indicator_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"),"owned save must be absent")
	if failures: quit(1); return
	var prerequisite := Progress.new()
	for chapter in range(1,5): check(prerequisite.record_boss_defeat(chapter),"sequential fixture")
	check(Store.new(path).save_progress(prerequisite),"fixture save failed")
	var before := FileAccess.get_sha256(path)
	var view := SubViewport.new(); view.size = Vector2i(1280,720); view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var chapter = Chapter.instantiate(); chapter.audio_enabled = false; chapter.campaign_store_path = path; chapter.run_seed = 2829959179
	view.add_child(chapter); await process_frame
	for _frame in 360:
		if not chapter.player.is_entrance_active(): break
		await process_frame
	check(not chapter.player.is_entrance_active(),"actual entrance never unlocks Boss start")
	chapter.player.set_physics_process(false); chapter.director.set_process(false)
	await complete_controlled_encounter(chapter)
	await complete_controlled_encounter(chapter)
	check(chapter.director.state==chapter.director.State.ROUTE,"actual route choice missing after two encounters")
	chapter.ui.supply_button.pressed.emit()
	check(chapter.director.state==chapter.director.State.REWARD and chapter.growth.get_settlement_state().get("stage_kind")=="boss_prep" and chapter.director.get_active_boss()==null,"framing fixture skipped actual finale reward gate")
	check(Support.claim_chapter_finale(chapter),"actual finale UI must be claimed/closed before Boss start")
	chapter.ui.proceed_button.pressed.emit()
	var boss = chapter.director.get_active_boss()
	check(boss!=null,"actual priest not started after entrance")
	if boss==null:
		Support.stop_audio(chapter.audio); paused = false; view.free(); await process_frame
		check(DirAccess.remove_absolute(path)==OK,"owned failed fixture save cleanup")
		quit(1); return
	boss.set_physics_process(false)
	boss.attack_director.advance(1.4); boss._update_entrance_reveal()
	boss._update_boss_motion(0)
	check(boss.get_visual_node().player.current_animation=="idle","post-entrance framing fixture retains entrance bones")
	# Accelerated kills did not consume real death-animation time. Let actual
	# detached visuals settle after the real Boss UI resumes the PAUSABLE tree;
	# do not manually free ghosts or render them as a still-living enemy crowd.
	for _frame in 120: await physics_frame
	check(get_nodes_in_group("native_death_tail").is_empty(),"controlled enemy death tails did not naturally settle")
	chapter.framing.set_process(false)
	for extent in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		view.size = extent; chapter.ui.apply_viewport_size(Vector2(extent))
		await process_frame; await process_frame
		for index in 3:
			boss.global_position = Vector2(-35.279922,-697.885742)
			chapter.player.global_position = Vector2(33.159142,-394.336548) if index==0 else boss.global_position+Vector2(0,400 if index==1 else 1200)
			for frame in 120:
				chapter.framing.step_framing(1.0/60.0)
				var cue: Control = chapter.ui.boss_direction_indicator
				if cue.visible:
					visible_samples += 1
					var rect: Rect2 = cue.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,cue.size)
					var actor: Rect2 = boss.get_visual_node().get_global_transform_with_canvas()*boss.get_visual_rect()
					check(chapter.framing.safe_screen_rect.encloses(rect),"cue leaves HUD-safe band")
					check(not rect.intersects(actor),"direction plate covers native Boss body/reserve %s/%d/%d"%[extent,index,frame])
					check(cue.direction.dot((actor.get_center()-rect.get_center()).normalized())>0.999,"relocated arrow does not point at actual Boss")
			if not output.is_empty():
				await RenderingServer.frame_post_draw
				var target := output+"%dx%d-pose%d.png"%[extent.x,extent.y,index]
				check(view.get_texture().get_image().save_png(target)==OK,"actual GPU capture failed")
				captures[target] = FileAccess.get_sha256(target)
	check(visible_samples>100,"fixture never exercised fallback indicator")
	check(FileAccess.get_sha256(path)==before,"framing changed progress")
	Support.stop_audio(chapter.audio); paused = false; view.free(); await process_frame
	check(DirAccess.remove_absolute(path)==OK,"owned save cleanup")
	if not output.is_empty():
		for source in sources: check(FileAccess.get_sha256("res://"+source)==sources[source],"source drift during capture")
		var report := FileAccess.open(output+"report.json",FileAccess.WRITE)
		report.store_string(JSON.stringify({"valid":failures==0,"checks":checks,"visible_samples":visible_samples,"captures":captures,"sources":sources,"scope":"Actual Echo chapter, native Boss, camera and indicator with controlled real-run/far poses at three resolutions. Original stats and collision unchanged; not normal victory, human playtest or performance."},"\t")); report.close()
	if not failures: print("TEST PASS: BossIndicatorOcclusionTest %d"%checks)
	quit(1 if failures else 0)
