extends SceneTree
func advance_warning(clock, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 1.0/120.0)
		clock.advance(step)
		remaining = maxf(0.0, remaining-step)
const SOURCE := "res://scripts/actors/FoundryFurnaceBoss.gd"
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: FurnaceForemanIntegrationTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"actual native furnace actor absent")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := Player.new(); player.position = Vector2(180,0); host.add_child(player); player.set_physics_process(false)
	var boss = load(SOURCE).new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000)
	boss.setup(2,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director()
	check(boss.tentacle_attack==null and boss.get_node_or_null("TentacleAttack")==null and combat.get_script().resource_path.ends_with("FurnaceForemanAttackDirector.gd"),"old combat nodes survive migration")
	check(boss.get_visual_node().scene_file_path.ends_with("furnace_foreman_paper_v2.tscn") and boss.get_visual_node().skeleton.get_bone_count()==23,"actor not new native furnace")
	check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1,"root is scaled/translucent")
	var health_before: float = boss.health.current_health
	boss.take_damage(20)
	check(boss.health.current_health==health_before,"entrance loses immunity")
	combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	check(boss.entrance_resolved and boss.process_mode==Node.PROCESS_MODE_PAUSABLE,"entrance leaves always-clock actor")
	for kind in [&"jet",&"ram",&"vents"]:
		check(combat.start_action(kind),"action cannot start "+str(kind))
		boss._update_boss_motion(0)
		check(boss.get_visual_node().player.current_animation==str(kind)+"_warning","warning adapter wrong")
		advance_warning(combat,combat.DURATIONS[kind][0]*0.5); boss._update_boss_motion(0)
		var view = boss.get_visual_node()
		var warning_clip := str(kind)+"_warning"
		var actual_pose: Array[Transform2D] = []
		for index in view.skeleton.get_bone_count(): actual_pose.append(view.skeleton.get_bone(index).transform)
		view.sample_clip(warning_clip,view.player.get_animation(warning_clip).length*0.5)
		for index in actual_pose.size():
			check(actual_pose[index].is_equal_approx(view.skeleton.get_bone(index).transform),"warning bones do not follow normalized authoritative time "+str(kind))
		advance_warning(combat,combat.DURATIONS[kind][0]*0.5); boss._update_boss_motion(0)
		check(boss.get_visual_node().player.current_animation==str(kind)+"_attack","active adapter wrong")
		check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1,"attack drives physical pose")
		combat.advance(combat.DURATIONS[kind][1]); boss._update_boss_motion(0)
		check(boss.get_visual_node().player.current_animation==str(kind)+"_recovery","recovery adapter wrong")
		combat.cancel_action(); boss._update_boss_motion(0)
		check(boss.get_visual_node().player.current_animation=="idle","cancel leaves active pose")
		boss.position = Vector2.ZERO
	boss._update_visual_facing(Vector2(-180,0)); boss._update_boss_motion(0)
	var socket: Node2D = boss.get_visual_node().get_node("Facing/Skeleton2D/Torso/Chest/VentR/VentOrigin")
	check(boss.get_safe_heat_origin().is_equal_approx(socket.global_position),"left emitter not actual mirrored socket")
	boss._update_visual_facing(player.position); boss._update_boss_motion(0)
	check(combat.start_action(&"jet"),"hit priority fixture absent")
	boss.take_damage(30)
	check(boss.health.current_health==health_before-30 and boss.get_visual_node().player.current_animation=="jet_warning","hit interrupts authoritative combat pose")
	combat.set_target_hidden(true); boss._update_boss_motion(0)
	check(not combat.is_attacking(),"hidden target leaves dangerous attack")
	combat.set_target_hidden(false)
	check(combat.start_action(&"vents"),"death fixture absent")
	var deaths: Array = []; boss.died.connect(func(_b,_coins,_source): deaths.append(true))
	boss.take_damage(boss.health.current_health+1)
	check(boss.death_resolved and deaths==[true] and combat.get_state_name()=="DEATH" and combat.vent_centers.is_empty(),"death leaves hazards or repeats death")
	var corpse: Node2D
	for child in host.get_children():
		if child.name=="NativeFurnaceForeman": corpse = child
	check(corpse!=null and corpse.player.current_animation=="death" and corpse.process_mode==Node.PROCESS_MODE_PAUSABLE,"native terminal corpse missing")
	await process_frame; host.free(); await process_frame
	if not failures: print("TEST PASS: FurnaceForemanIntegrationTest %d"%checks)
	quit(1 if failures else 0)
