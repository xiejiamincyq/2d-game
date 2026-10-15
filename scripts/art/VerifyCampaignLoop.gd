extends SceneTree
## Actual second-loop coordinator, controlled UI states; no claimed Boss victory.
const Registry=preload("res://scripts/campaign/ChapterSceneRegistry.gd")
const Journey=preload("res://scripts/systems/CampaignJourney.gd")
const Journal=preload("res://scripts/systems/CampaignJourneyStore.gd")
const Store=preload("res://scripts/systems/CampaignProgressStore.gd")
const Support=preload("res://scripts/tests/TestSupport.gd")
const OUTPUT="res://build/diagnostics/campaign-goal/loop-gpu-v3"
var checks:=0
var failures:=0
var captures: Array[Dictionary]=[]
var sources: Dictionary={}
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: VerifyCampaignLoop "+label)
func hash_of(path: String) -> String: return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(DisplayServer.get_name()!="headless","real renderer required")
	check(not DirAccess.dir_exists_absolute(OUTPUT),"preserve previous captures")
	if failures: quit(1); return
	check(DirAccess.make_dir_recursive_absolute(OUTPUT)==OK,"new evidence folder")
	var protected: Dictionary={}
	for base in [Store.DEFAULT_PATH,Journal.DEFAULT_PATH]:
		for suffix in ["",".bak",".tmp"]: protected[base+suffix]=hash_of(base+suffix)
	for path in ["scripts/art/VerifyCampaignLoop.gd","scripts/campaign/ChapterRun.gd","scripts/campaign/ChapterRunDefinitions.gd","scripts/systems/CampaignLoopRules.gd","scripts/systems/ChapterEncounterDirector.gd","scripts/ui/ChapterRunUI.gd","scripts/ui/GameUI.gd"]: sources[path]=hash_of("res://"+path)
	for extent in [Vector2i(960,540),Vector2i(1280,720)]:
		for chapter in [1,4,6]: await sample(chapter,extent)
	for path in protected: check(hash_of(path)==protected[path],"default main/backup/tmp unchanged")
	for path in sources: check(hash_of("res://"+path)==sources[path],"source unchanged")
	var report:=FileAccess.open(OUTPUT.path_join("report.json"),FileAccess.WRITE)
	check(report!=null,"report writer")
	if report!=null:
		report.store_string(JSON.stringify({"valid":failures==0,"checks":checks,"renderer":RenderingServer.get_video_adapter_name(),"arguments":OS.get_cmdline_args(),"sources":sources,"captures":captures,"limits":["Actual isolated Loop2 ChapterRun; combat clocks controlled.","Sixth settlement is an explicit component preview, not Boss victory.","Not natural play, final EXE, two-loop chain or FPS acceptance."]},"\t")); report.close()
	if failures==0: print("TEST PASS: VerifyCampaignLoop %d"%checks)
	quit(1 if failures else 0)
func sample(chapter: int,extent: Vector2i) -> void:
	paused=false
	var path:="user://loop_gpu_%d_%d.json"%[OS.get_process_id(),Time.get_ticks_usec()]
	var journal:=Journal.new(path+".journey"); var journey:=Journey.new()
	check(journal.load_journey(journey)==Journal.LoadResult.MISSING,"unique owned checkpoint")
	check(journey.restore_state({"version":1,"cleared_stage":6+chapter-1,"coins":37,"inherited_counts":{}}) and journal.save_journey(journey),"Loop2 fixture saved")
	var view:=SubViewport.new(); view.size=extent; view.world_2d=World2D.new(); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var scene: Node=Registry.instantiate_chapter(chapter)
	scene.campaign_store_path=path; scene.audio_enabled=false; scene.run_seed=521; view.add_child(scene)
	scene.director.set_process(false); scene.player.set_physics_process(false)
	check(scene.run_loop==2 and scene.director.run_loop==2,"real coordinator/difficulty loop")
	if chapter==6:
		var choices: Array[Dictionary]=[]
		scene.ui.present_chapter_clear(6,choices,37,true)
		scene.ui.flow_title.text=scene._location_label()+"通关 · 已保存"
		check(not scene.ui.next_button.visible and scene.ui.flow_description.text.contains("下一轮"),"sixth two-button next-loop rule")
	# Compare after actual draw frames, not merely CPU process turns.
	for frame in 16:
		await process_frame
		await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var bounds:=Rect2(Vector2(8,8),Vector2(extent)-Vector2(16,16))
	check(bounds.encloses(scene.ui.flow_panel.get_global_rect()),"flow frame fits actual viewport")
	check(scene.ui.flow_panel.get_global_rect().encloses(scene.ui.flow_description.get_global_rect()),"loop description does not overflow panel")
	for control in [scene.ui.proceed_button,scene.ui.replay_button,scene.ui.return_button]:
		if control.is_visible_in_tree(): check(bounds.encloses(control.get_global_rect()),"required action stays on-screen")
	var file:=OUTPUT.path_join("chapter%d-%dx%d.png"%[chapter,extent.x,extent.y])
	var pixels:=view.get_texture().get_image()
	check(pixels!=null and pixels.get_size()==extent and pixels.save_png(file)==OK,"real capture saved")
	captures.append({"path":file,"sha256":hash_of(file),"chapter":chapter,"loop":2,"title":scene.ui.flow_title.text,"description":scene.ui.flow_description.text,"title_rect":str(scene.ui.flow_title.get_global_rect())})
	Support.stop_audio(scene.audio); view.free(); paused=false; await process_frame
	for suffix in [".journey",".journey.bak",".journey.tmp"]:
		if FileAccess.file_exists(path+suffix): check(DirAccess.remove_absolute(path+suffix)==OK,"only owned GPU checkpoint removed")
