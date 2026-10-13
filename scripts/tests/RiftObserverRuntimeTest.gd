extends SceneTree
## Ordinary real physics/input, production UI/camera. Phase/death inspection is controlled, NOT victory.
const Map = preload("res://scenes/world/rift_observatory.tscn")
const Actor = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const Interface = preload("res://scripts/ui/GameUI.gd")
const Framing = preload("res://scripts/systems/BossCameraFraming.gd")
var checks := 0
var failures := 0
var output := ""
var captures: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var sources := {}
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverRuntimeTest "+label)
func release() -> void:
	for action in ["move_left","move_right","move_up","move_down","fire","dash_melee"]: Input.action_release(action)
func save_frame(view: SubViewport,name: String,boss: Node,framing: Node) -> void:
	if output.is_empty(): return
	var pixels := view.get_texture().get_image()
	check(not pixels.is_empty() and pixels.save_png(output+name)==OK,"actual GPU "+name)
	captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name),"state":boss.get_attack_director().get_state_name(),"action":String(boss.get_attack_director().action),"clip":boss.get_visual_node().player.current_animation,"zoom":framing.camera.zoom.x,"both_fit":framing.both_fit,"boss_position":[boss.position.x,boss.position.y]})
func capture(view: SubViewport,name: String,boss: Node,framing: Node) -> void:
	await process_frame
	if not output.is_empty(): await RenderingServer.frame_post_draw
	save_frame(view,name,boss,framing)
func run_case(sign_value: int) -> void:
	release()
	var view := SubViewport.new(); view.size = Vector2i(1280,720); view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var host := Node2D.new(); view.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := PlayerScript.new(); player.world_bounds = map.layout.world_bounds; player.position = map.layout.BOSS_CENTER+Vector2(sign_value*240,0); host.add_child(player)
	map.layout.occlusion_target = player
	var shots := Node2D.new(); host.add_child(shots)
	var boss := Actor.new(); boss.world_bounds = map.layout.world_bounds; boss.position = map.layout.BOSS_CENTER; boss.arena_navigation = map.layout; boss.setup(6,shots,player); host.add_child(boss)
	var ui := Interface.new(); view.add_child(ui); ui.hide_start_screen(); ui.show_boss_health(boss,boss.get_display_name(),boss.health.max_health)
	ui.set_health(100,100); ui.set_boss_health(boss.health.current_health,boss.health.max_health,1)
	ui.set_shield(player.shield,player.max_shield); player.shield_changed.connect(ui.set_shield)
	check(ui.shield_value_label.text=="护盾 %d / %d"%[int(player.shield),int(player.max_shield)],"test HUD shield differs from actual Player")
	player.health.health_changed.connect(ui.set_health); boss.health_changed.connect(ui.set_boss_health)
	var camera := Camera2D.new(); player.add_child(camera)
	var framing := Framing.new(); host.add_child(framing); framing.setup(camera,player,ui,map.layout.world_bounds); framing.track_boss(boss); framing.set_combat_state(true,false)
	var combat = boss.get_attack_director(); var seen: Array[StringName] = []; var taken := {}; var serial := -1; var moves := 0; var pointers := 0; var completed := false
	var started := Time.get_ticks_msec(); var strafe := Vector2.ZERO
	while Time.get_ticks_msec()-started<18000 and player.health.current_health>0:
		if combat.action_serial!=serial and combat.action_stage==combat.Stage.WARNING:
			serial = combat.action_serial; seen.append(combat.action); strafe = combat.locked_direction.orthogonal()*sign_value
		var direction: Vector2 = Vector2.ZERO
		if combat.action_stage in [combat.Stage.WARNING,combat.Stage.ACTIVE]:
			if combat.action_elapsed>=0.15 or combat.action_stage==combat.Stage.ACTIVE: direction = strafe
		else: direction = map.layout.get_navigation_direction(player.position,boss.position+Vector2(sign_value*240,0),player.get_body_radius())
		release()
		for axis in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
			if axis[1]>0: Input.action_press(axis[0],axis[1])
		var mouse := InputEventMouseMotion.new(); mouse.position = boss.get_global_transform_with_canvas().origin; view.push_input(mouse); pointers += 1
		check(player.get_global_mouse_position().distance_to(boss.global_position)<1,"engine pointer differs from real Boss")
		var before := player.position; await physics_frame; await process_frame
		if player.position.distance_to(before)>0.01: moves += 1
		if not output.is_empty(): await RenderingServer.frame_post_draw
		check(map.layout.is_position_walkable(player.position,player.get_body_radius()),"ordinary Player embeds terrain")
		check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1,"physical Boss root scales/rotates/fades")
		var kind := String(combat.action)
		if combat.action_stage==combat.Stage.WARNING and combat.action_elapsed>=0.15 and not taken.has(kind+"warning"):
			check(boss.should_show_attack_marker(),"automatic head mark missing"); taken[kind+"warning"] = true; save_frame(view,"%s-warning-%s.png"%[kind,sign_value],boss,framing)
		var live: bool = combat.beam.armed if kind=="beam" else (combat.probes.any(func(p): return p.armed and p.age>=0.04) if kind=="probes" else combat.refract.fragments.any(func(p): return p.armed and p.age>=0.035))
		if combat.action_stage==combat.Stage.ACTIVE and live and not taken.has(kind+"active"):
			taken[kind+"active"] = true; save_frame(view,"%s-active-%s.png"%[kind,sign_value],boss,framing)
		if taken.size()==6 and not combat.is_attacking(): completed = true; break
	release()
	check(completed and seen==[&"beam",&"probes",&"refract"] and moves>50 and pointers>100,"continuous automatic three-action cycle/input missing: "+str(seen)+" "+str(taken))
	check(player.health.current_health>0 and player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9) and player.shield==0,"ordinary Player died or statistics changed")
	check(framing.active and framing.safe_screen_rect.has_area() and ui.boss_health_bar.visible,"production UI/framing not active")
	cases.append({"facing":sign_value,"moves":moves,"pointers":pointers,"health":player.health.current_health,"seen":seen,"seconds":(Time.get_ticks_msec()-started)/1000.0})
	if failures: framing.reset_framing(); view.free(); await process_frame; return
	# Controlled inspection only below; ordinary movement above never teleports or grants immunity.
	for _frame in range(360):
		if combat.is_attacking(): break
		await physics_frame
	check(combat.is_attacking(),"bounded pause fixture never enters an automatic attack")
	paused = true; await process_frame; await process_frame
	check(not combat.is_attacking() and not boss.should_show_attack_marker(),"pause retains attack/head warning")
	await capture(view,"paused-%s.png"%sign_value,boss,framing); paused = false
	boss.take_damage(1); await capture(view,"hit-%s.png"%sign_value,boss,framing)
	boss.take_damage(boss.health.max_health*0.31)
	for _frame in range(180):
		if combat.current_phase>=2: break
		await physics_frame
	await capture(view,"phase2-%s.png"%sign_value,boss,framing)
	check(boss.get_phase()==2 and combat.current_phase==2,"real Health phase2 missing")
	boss.take_damage(boss.health.max_health*0.36)
	for _frame in range(180):
		if combat.current_phase>=3: break
		await physics_frame
	await capture(view,"phase3-%s.png"%sign_value,boss,framing)
	check(boss.get_phase()==3 and combat.current_phase==3,"real Health phase3 missing")
	for size in [Vector2i(960,540),Vector2i(1920,1080)]:
		view.size = size
		for _frame in range(20): await physics_frame; await process_frame
		check(ui.status_viewport_size==Vector2(size) and framing.safe_screen_rect.has_area() and camera.zoom.x>=0.8,"resized production UI/camera invalid")
		await capture(view,"size%s-%s.png"%[size.x,sign_value],boss,framing)
	var visual := boss.get_visual_node(); var deaths := [0]; boss.died.connect(func(_actor,_coins,_source): deaths[0] += 1)
	boss.take_damage(boss.health.current_health+1)
	check(deaths[0]==1 and visual.player.current_animation=="death" and not combat.is_attacking(),"actual native death does not terminate")
	var corpse_at := visual.global_transform; var torso_at: Transform2D = visual.skeleton.get_node("Torso").transform
	for _frame in range(90):
		if not is_instance_valid(visual) or visual.player.current_animation_position>=0.55: break
		await physics_frame; await process_frame
	check(is_instance_valid(visual) and visual.player.current_animation_position>=0.4,"death capture is only the initial standing pose")
	if not is_instance_valid(visual): framing.reset_framing(); view.free(); await process_frame; return
	check(visual.global_transform==corpse_at and visual.skeleton.get_node("Torso").transform!=torso_at and visual.player.current_animation=="death","natural native corpse fails to articulate independently of root")
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		var pixels := view.get_texture().get_image(); var name := "death-%s.png"%sign_value
		check(pixels.save_png(output+name)==OK,"actual death pixels"); captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name),"controlled_damage":true,"natural_animation":true,"clip":"death","animation_time":visual.player.current_animation_position})
	for _frame in range(120):
		if not is_instance_valid(visual): break
		await physics_frame; await process_frame
	check(not is_instance_valid(boss) and not is_instance_valid(visual) and shots.get_child_count()==0 and deaths[0]==1,"natural native corpse/Actor or geometry leaks")
	framing.reset_framing(); view.free(); await process_frame; await process_frame
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()>1 or (args.size()==1 and not args[0].is_valid_identifier()): quit(1); return
	if args.size()==1:
		output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
		check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh actual GPU directory required")
		if failures: quit(1); return
		DirAccess.make_dir_recursive_absolute(output)
		for path in ["scripts/tests/RiftObserverRuntimeTest.gd","scripts/tests/RiftObserverAutomaticCycleTest.gd","scripts/tests/RiftObserverLifecycleTest.gd","scripts/tests/RiftObserverIntegrationTest.gd","scripts/actors/RiftObserverBoss.gd","scripts/actors/OverseerBoss.gd","scripts/actors/Player.gd","scripts/components/RiftObserverAttackDirector.gd","scripts/components/RiftObserverBeam.gd","scripts/components/RiftObserverProbe.gd","scripts/components/RiftObserverCircleFlight.gd","scripts/components/RiftObserverFragment.gd","scripts/components/RiftObserverRefractVolley.gd","scripts/components/NativeRiftObserverMotion.gd","scripts/components/NativeBossMotion.gd","scripts/components/NativeActorView.gd","scripts/components/NativePlayerMotion.gd","scripts/components/NativePlayerView.gd","scripts/components/HealthComponent.gd","scripts/components/NativeProjectileOriginSafety.gd","scripts/systems/BossCameraFraming.gd","scripts/systems/CombatView.gd","scripts/ui/GameUI.gd","scripts/ui/BossHealthBar.gd","scripts/ui/BossDirectionIndicator.gd","scripts/effects/EnemyWorldStatus.gd","scripts/world/RiftMap.gd","scripts/world/RiftArenaLayout.gd","scripts/world/RiftFloor.gd","scripts/world/RiftObstacle.gd","scripts/world/RiftField.gd","scripts/world/TerrainSweep.gd","scenes/world/rift_observatory.tscn","scenes/actors/native/rift_observer_paper_v2.tscn","assets/art/actors/native/rift_observer_motion_v2.tres","scenes/actors/native/player_paper_v1.tscn","themes/MintFarmTheme.tres"]:
			sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"source SHA "+path)
	for sign_value in [1,-1]:
		await run_case(sign_value)
		if failures: break
	release()
	if not output.is_empty():
		check(captures.size()==26,"complete mirrored natural/lifecycle/resize GPU captures")
		var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify({"passed":failures==0,"renderer":RenderingServer.get_video_adapter_name(),"sources":sources,"captures":captures,"cases":cases,"checks":checks,"failures":failures,"scope":"ordinary continuous physics/automatic cycle; controlled phase/death inspection, NOT chapter victory"},"\t")); file.close()
	if not failures: print("TEST PASS: RiftObserverRuntimeTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
