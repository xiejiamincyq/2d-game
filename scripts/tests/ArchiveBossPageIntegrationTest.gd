extends SceneTree
## Actual Boss/Player/resources; controlled clock and target moves are lifecycle fixtures.
const SOURCE := "res://scripts/actors/ArchiveArchivistBoss.gd"
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveBossPageIntegrationTest "+label)
func _initialize() -> void: call_deferred("run")
func step(combat: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"actual archivist combat actor absent")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := Player.new(); player.position = Vector2(240,0); host.add_child(player); player.set_physics_process(false)
	var boss = load(SOURCE).new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000)
	boss.setup(4,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director()
	check(boss.tentacle_attack==null and combat.get_script().resource_path.ends_with("SporeArchivistAttackDirector.gd"),"legacy tentacle/another Boss clock reused")
	check(boss.get_visual_node().scene_file_path.ends_with("spore_archivist_paper_v2.tscn") and boss.get_visual_node().skeleton.get_bone_count()==27,"actual actor not new native archivist")
	check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1,"physical root scaled/translucent")
	var health_before: float = boss.health.current_health
	boss.take_damage(20)
	check(boss.health.current_health==health_before and not combat.start_action(&"page"),"entrance damage/attack bypass")
	combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	check(boss.entrance_resolved and boss.process_mode==Node.PROCESS_MODE_PAUSABLE,"entrance cannot finish")
	check(combat.start_action(&"page") and boss.should_show_attack_marker(),"short page warning absent")
	check(boss.get_visual_node().player.current_animation=="page_warning","warning ignores actual clip")
	var locked: Vector2 = combat.locked_direction
	step(combat,combat.DURATIONS[&"page"][0]-0.001)
	check(shots.get_child_count()==0 and combat.action_stage==combat.Stage.WARNING,"page born before warning")
	player.position = Vector2(240,90)
	step(combat,0.001)
	check(combat.action_stage==combat.Stage.ACTIVE and shots.get_child_count()==1 and not boss.should_show_attack_marker(),"one-shot release timing/head marker")
	var page = shots.get_child(0); page.set_physics_process(false)
	check(page.velocity.is_equal_approx(locked*420) and combat.locked_direction==locked,"leaf retargets moving player")
	check(page.global_position.is_equal_approx(boss.get_safe_page_origin()) and page.source_actor_id==boss.get_instance_id(),"not current native book socket/source")
	check(boss.get_visual_node().player.current_animation=="page_attack","release ignores actual clip")
	boss.take_damage(30)
	check(boss.health.current_health==health_before-30 and boss.get_visual_node().player.current_animation=="page_attack","hit cancels authoritative attack pose")
	step(combat,0.40)
	check(combat.action_stage==combat.Stage.RECOVERY and shots.get_child_count()==1 and boss.get_visual_node().player.current_animation=="page_recovery","recovery repeats/replaces page")
	step(combat,0.52)
	check(not combat.is_attacking() and combat.owned_projectiles.size()==1,"normal recovery erases in-flight leaf")
	combat.advance(500)
	check(combat.action_stage==combat.Stage.IDLE and not combat.is_attacking() and not boss.should_show_attack_marker() and shots.get_child_count()==1 and combat.owned_projectiles==[page] and not page.is_queued_for_deletion(),"hitch overlaps new warning/shot with still-live prior page")
	combat.cancel_action()
	check(combat.owned_projectiles.is_empty() and page.is_queued_for_deletion() and not page.visible,"cancel leaves live flying page")
	await process_frame
	check(shots.get_child_count()==0,"cancelled page node leaks")
	check(not combat.start_action(&"unknown") and not combat.start_action(&"brood"),"unknown/phase1 brood attacks silently accepted")
	check(combat.start_action(&"page"),"pause fixture cannot arm")
	paused = true; await process_frame; await process_frame
	check(not combat.is_attacking() and not boss.should_show_attack_marker() and boss.get_visual_node().player.current_animation!="page_warning","pause retains head/pose/action")
	paused = false; step(combat,0.01)
	check(combat.attack_gap>1,"resume attacks without a safe gap")
	check(combat.start_action(&"page"),"stealth fixture cannot arm")
	step(combat,combat.DURATIONS[&"page"][0]); combat.set_target_hidden(true)
	check(not combat.is_attacking() and combat.owned_projectiles.is_empty(),"stealth leaves leaf")
	await process_frame; combat.set_target_hidden(false)
	boss.take_damage(health_before*0.8)
	check(combat.get_state_name()=="TRANSITION_1","large health drop skips first transition")
	step(combat,0.65)
	check(combat.get_state_name()=="TRANSITION_2" and combat.current_phase==2,"large health drop skips second phase")
	step(combat,0.65)
	check(combat.current_phase==3,"third phase absent")
	shots.child_entered_tree.connect(func(_node): combat.shutdown(),CONNECT_ONE_SHOT)
	check(combat.start_action(&"page"),"reentrant birth fixture cannot arm")
	step(combat,combat.DURATIONS[&"page"][0])
	check(combat.get_state_name()=="DEATH" and combat.owned_projectiles.is_empty(),"child-entered callback appends page after shutdown")
	await process_frame; check(shots.get_child_count()==0,"reentrant birth leaf survives")
	var deaths: Array = []; boss.died.connect(func(_b,_coins,_source): deaths.append(true))
	boss.take_damage(boss.health.current_health+1)
	check(boss.death_resolved and deaths==[true] and not combat.start_action(&"page"),"terminal death can restart")
	await process_frame; host.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveBossPageIntegrationTest %d" % checks)
	quit(1 if failures else 0)
