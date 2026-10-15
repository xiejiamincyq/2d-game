extends SceneTree
## External actual-PCK GPU probe. Controlled Loop2 prerequisites, NOT victories.
const Registry=preload("res://scripts/campaign/ChapterSceneRegistry.gd")
const Journey=preload("res://scripts/systems/CampaignJourney.gd")
const Journal=preload("res://scripts/systems/CampaignJourneyStore.gd")
var checks:=0
var failures:=0
var output:=""
var captures: Array[Dictionary]=[]
var observations: Array[Dictionary]=[]
var view: SubViewport

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: VerifyEndlessPackedViews "+label)
func _initialize() -> void: call_deferred("run")
func release() -> void:
	for action in ["move_left","move_right","move_up","move_down","fire","dash_melee"]: Input.action_release(action)
func save_hashes() -> Dictionary:
	var result: Dictionary={}
	for path in ["user://five_minute_overdrive_campaign_v1.json","user://five_minute_overdrive_run_v1.json",Journal.DEFAULT_PATH]:
		for suffix in ["",".bak",".tmp"]: result[path+suffix]=FileAccess.get_sha256(path+suffix) if FileAccess.file_exists(path+suffix) else "absent"
	return result
func pointer(at: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=at; event.global_position=at
	view.push_input(event,true)
func click(button: Button) -> void:
	var at:=button.get_global_rect().get_center()
	check(button.is_visible_in_tree() and not button.disabled,"actual intro action unavailable")
	pointer(at)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=at; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		view.push_input(event,true)
	await process_frame
func capture(name: String) -> void:
	for frame in 16: await process_frame
	await RenderingServer.frame_post_draw
	var path:=output+name+".png"
	var pixels:=view.get_texture().get_image()
	check(not pixels.is_empty() and pixels.save_png(path)==OK,"actual packed GPU pixels "+name)
	captures.append({"file":path,"sha256":FileAccess.get_sha256(path),"width":pixels.get_width(),"height":pixels.get_height()})
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	check(args.size()==2 and args[0].is_absolute_path(),"explicit fresh evidence directory and PCK SHA required")
	check(DisplayServer.get_name()!="headless" and not ResourceLoader.exists("res://scripts/art/VerifyEndlessPackedViews.gd") and not ResourceLoader.exists("res://scripts/tests/fixtures/LegacyWaveMain.gd"),"GPU and actual isolated PCK required")
	if failures: quit(1); return
	output=args[0].replace("\\","/").simplify_path().trim_suffix("/")+"/"
	check(output.contains("/build/diagnostics/campaign-goal/") and not DirAccess.dir_exists_absolute(output),"refuse non-evidence or existing output")
	if failures: quit(1); return
	check(DirAccess.make_dir_recursive_absolute(output)==OK,"create owned pixel evidence directory")
	var before:=save_hashes()
	view=SubViewport.new(); view.size=Vector2i(1280,720); view.world_2d=World2D.new()
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view); view.notify_mouse_entered()
	var display:=TextureRect.new(); display.texture=view.get_texture()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(display)
	for chapter_number in range(1,7):
		await probe_chapter(chapter_number)
		if failures: break
	check(before==save_hashes(),"actual default campaign/snapshot/journey primary, backup and tmp changed")
	var report:={"passed":failures==0,"checks":checks,"pck_sha256":args[1],"captures":captures,"observations":observations,
		"adapter":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"default_saves_before":before,"default_saves_after":save_hashes(),
		"scope":"Actual compiled PCK, six controlled Loop2 prerequisite journals, actual chapter UI and ordinary movement/aim/fire with natural AI clocks. No post-spawn position, HP, damage or attack-clock writes. NOT six victories, natural predecessor chain, human/OS input, performance or isolated-alpha proof. Actors are retired only after capture."}
	var file:=FileAccess.open(output+"report.json",FileAccess.WRITE)
	check(file!=null,"write bounded package-view report")
	if file!=null: file.store_string(JSON.stringify(report,"\t")); file.close()
	if failures==0: print("TEST PASS: VerifyEndlessPackedViews %d"%checks)
	quit(1 if failures else 0)
func probe_chapter(number: int) -> void:
	release(); paused=false
	var path:="user://endless_pck_gpu_%d_%d_c%d.json"%[OS.get_process_id(),Time.get_ticks_usec(),number]
	var journal_path:=path+".journey"
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(journal_path),"unique controlled prerequisite fixture")
	var journey:=Journey.new()
	check(journey.restore_state({"version":1,"cleared_stage":6+number-1,"coins":0,"inherited_counts":{},"pending_clear":{}}),"explicit controlled Loop2 prerequisite, not a victory")
	var store:=Journal.new(journal_path)
	check(store.load_journey(Journey.new())==Journal.LoadResult.MISSING and store.save_journey(journey),"owned controlled journal written")
	var chapter: Node=Registry.instantiate_chapter(number)
	chapter.campaign_store_path=path; chapter.audio_enabled=false; chapter.run_seed=521
	view.add_child(chapter)
	var deadline:=Time.get_ticks_msec()+8000
	while chapter.ui.proceed_button.disabled and Time.get_ticks_msec()<deadline: await process_frame
	check(chapter.run_loop==2 and chapter.player.health.max_health==90+number*10 and chapter.player.shield==20,"packed controlled Loop2 actual chapter base stats")
	await capture("c%d_intro"%number)
	await click(chapter.ui.proceed_button)
	# The real spawn guard requires a neutral PHYSICS observation, not merely
	# releasing/repressing actions within one script callback. Never clear it
	# by assigning player state: wait with all controls genuinely released.
	release()
	var guard_before: bool=chapter.player.spawn_input_guard_active
	for neutral in 4:
		await physics_frame; await process_frame
	check(not chapter.player.spawn_input_guard_active,"real neutral physics releases spawn input guard "+str(number))
	var moves:=0
	var shots:=[0]
	chapter.player.fired.connect(func(_shot): shots[0]+=1)
	var peak:=0
	var live_captured:=false
	for step in 600:
		release()
		if chapter.director.state!=chapter.director.State.COMBAT: break
		var position: Vector2=chapter.player.global_position
		var goal:=Vector2.from_angle(float(step)/90.0)
		var direction:=Vector2.ZERO
		for turn in 8:
			var candidate:=goal.rotated(turn*PI/4)
			if chapter.map.layout.is_position_walkable(position+candidate*24,chapter.player.get_body_radius()) and chapter.map.layout.is_position_walkable(position+candidate*48,chapter.player.get_body_radius()): direction=candidate; break
		for axis in [["move_right",direction.x],["move_left",-direction.x],["move_down",direction.y],["move_up",-direction.y]]:
			if axis[1]>0: Input.action_press(axis[0],axis[1])
		var aim:=position+Vector2.RIGHT*300
		var nearest:=INF
		var marked:=false
		var actors: Array=chapter.director.get_active_enemies()
		for actor in actors:
			var distance: float=position.distance_squared_to(actor.global_position)
			if distance<nearest: nearest=distance; aim=actor.global_position
			marked=marked or actor.should_show_attack_marker()
		pointer((view.get_canvas_transform()*aim).clamp(Vector2.ONE,Vector2(view.size)-Vector2.ONE))
		Input.action_press("fire")
		await physics_frame; await process_frame
		moves+=1 if chapter.player.global_position.distance_to(position)>0.01 else 0
		peak=maxi(peak,actors.size())
		if not live_captured and step>120 and actors.size()>=4 and marked:
			await capture("c%d_live"%number); live_captured=true
		release()
	if not live_captured: await capture("c%d_live"%number)
	check(moves>20 and shots[0]>5 and peak>=4,"ordinary packed movement/fire/population observed "+str(number))
	observations.append({"chapter":number,"loop":chapter.run_loop,"controlled_prerequisites":true,"spawn_guard_before_neutral":guard_before,"spawn_guard_after_neutral":chapter.player.spawn_input_guard_active,"moves":moves,"shots":shots[0],"enemy_peak":peak,"final_health":chapter.player.health.current_health,"state":chapter.director.State.keys()[chapter.director.state]})
	# Controlled cancellation after evidence; never make a death/victory claim.
	chapter.director._fail("封装视图检查结束")
	chapter.audio.begin_shutdown()
	while not chapter.audio.is_shutdown_complete(): await process_frame
	chapter.free(); paused=false
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(journal_path+suffix): check(DirAccess.remove_absolute(journal_path+suffix)==OK,"owned controlled journal cleanup")
	check(not FileAccess.file_exists(path),"visual probe invented permanent legacy progress")
