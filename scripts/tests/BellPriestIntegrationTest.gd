extends SceneTree
## Real native actor/Health/entrance/clock; controlled lifecycle, not chapter victory.
const SOURCE := "res://scripts/actors/EchoBellPriestBoss.gd"
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BellPriestIntegrationTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"actual priest Actor/unique combat clock missing")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := Player.new(); player.position = Vector2(260,0); host.add_child(player); player.set_physics_process(false)
	var boss = load(SOURCE).new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000)
	boss.setup(5,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director()
	check(boss.tentacle_attack==null and combat.get_script().resource_path.ends_with("BellPriestAttackDirector.gd"),"foreign/duplicate combat authority")
	check(boss.get_visual_node().scene_file_path.ends_with("bell_priest_paper_v2.tscn") and boss.get_visual_node().skeleton.get_bone_count()==26,"new native anatomy not actual Actor")
	check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1 and is_equal_approx(boss.body_radius,56),"physical root/hitbox/opacity changed")
	var full: float = boss.health.current_health
	check(full>0 and full==boss.health.max_health and boss.is_in_group(&"bosses"),"actual Health/groups absent")
	boss.take_damage(10)
	check(boss.health.current_health==full and not combat.start_action(&"bell") and not combat.start_action(&"pendant") and not combat.start_action(&"crown"),"entrance damage/attack bypass")
	combat.advance(1.39); boss._update_entrance_reveal()
	check(not boss.entrance_resolved and combat.is_movement_locked(),"entrance skipped")
	combat.advance(0.01); boss._update_entrance_reveal()
	check(boss.entrance_resolved and combat.current_phase==1 and boss.process_mode==Node.PROCESS_MODE_PAUSABLE,"entrance never resolves")
	check(not combat.start_action(&"unknown"),"unimplemented action accepted")
	var at: Transform2D = boss.global_transform; var before: float = combat.state_elapsed
	for delta in [-1.0,0.0,NAN,INF]: combat.advance(delta)
	check(combat.state_elapsed==before and boss.global_transform==at,"invalid delta/clock moves physical root")
	var top: float = boss.get_attack_marker_top()
	var head: Vector2 = boss.get_visual_node().skeleton.get_node("Torso/Head/Crown/RecallOrigin").global_position
	check(absf(top-(head.y-boss.global_position.y))<30,"head marker anchored to inflated camera rectangle")
	boss.take_damage(full*0.8)
	check(boss.health.current_health<full*0.35 and combat.get_state_name()=="TRANSITION_1","real Health threshold transition absent")
	combat.advance(0.65)
	check(combat.current_phase==2 and combat.get_state_name()=="TRANSITION_2","large damage skips phase2 transition")
	combat.advance(0.65)
	check(combat.current_phase==3 and combat.get_state_name()=="PHASE_3","phase3 not reached")
	var deaths: Array = []; boss.died.connect(func(_b,_coins,_source): deaths.append(true))
	boss.take_damage(boss.health.current_health+1)
	check(boss.death_resolved and deaths==[true] and combat.get_state_name()=="DEATH" and not combat.start_action(&"bell"),"death callback can restart/duplicate")
	await process_frame; host.free(); await process_frame
	if not failures: print("TEST PASS: BellPriestIntegrationTest %d"%checks)
	quit(1 if failures else 0)
