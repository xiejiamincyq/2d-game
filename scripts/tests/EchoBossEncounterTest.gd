extends "EchoEncounterTest.gd"
## Actual chapter owner/Boss death. Accelerated fixture, NOT normal-run victory.
const Boss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
func advance_warning(combat: Node) -> void:
	var remaining: float = combat.DURATIONS[combat.action][0]
	while remaining>0.0000001:
		var step := minf(1.0/120.0,remaining)
		combat.advance(step); remaining -= step
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoBossEncounterTest "+label)
func run() -> void:
	var f := fixture(); var director = f.director
	check(director._boss_available(),"verified native priest is not bound to fifth encounter owner")
	if failures: f.host.free(); await process_frame; quit(1); return
	await tick(); await tick()
	await clear_encounter(f,2); await clear_encounter(f,2)
	var cleared_chapters: Array[int] = []; director.chapter_cleared.connect(func(chapter): cleared_chapters.append(chapter))
	check(director.choose_route(&"supply") and director.state==director.State.BOSS_READY,"real mandatory route cannot reach priest")
	check(director.begin_boss() and not director.begin_boss(),"exactly one actual priest must start")
	var boss = director.get_active_boss(); boss.set_physics_process(false)
	check(boss.get_script()==Boss and boss.get_visual_node().skeleton.get_bone_count()==26 and boss.tentacle_attack==null,"old/generic/raster Boss substituted")
	check(f.map.layout.is_position_walkable(boss.global_position,56) and boss.arena_navigation==f.map.layout,"native Boss body spawns in terrain")
	check(not f.map.echo_field.active and director.get_active_enemies()==[boss],"encounter clocks/debt survive into priest fight")
	boss.died.emit(boss,999,&"test")
	check(clears==0 and director.state==director.State.BOSS and not director.boss_defeat_pending,"living forged death grants clear")
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal()
	boss.take_damage(boss.health.max_health*0.31); combat.advance(0.65)
	check(combat.current_phase==2 and combat.start_action(&"crown"),"actual Health phase/native attack unavailable")
	advance_warning(combat); combat.advance(combat.CROWN_NOTES[0])
	check(director.projectile_parent.get_child_count()==2,"actual owner receives finite attack pair")
	boss.take_damage(boss.health.current_health+1)
	check(combat.get_state_name()=="DEATH" and combat.owned_projectiles.is_empty(),"true Boss death retains attack authority")
	await process_frame; await process_frame
	check(clears==1 and cleared_chapters==[5] and director.state==director.State.CLEARED and director.defeated_boss_instance>0 and not director.active,"true death fails to grant exactly fifth clear")
	check(director.projectile_parent.get_child_count()==0 and not director.begin_boss() and not director.finish_reward(),"terminal state retains danger or allows duplicate reward")
	f.host.free(); await process_frame
	var removed := fixture(); removed.director.spawn_queue.clear(); removed.director._prepare_boss()
	check(removed.director.begin_boss(),"departure fixture cannot begin actual Boss")
	removed.director.get_active_boss().queue_free(); await process_frame; await process_frame
	check(removed.director.state==removed.director.State.FAILED and clears==1,"living Boss departure fakes another clear")
	removed.host.free(); await process_frame
	if not failures: print("TEST PASS: EchoBossEncounterTest %d"%checks)
	quit(1 if failures else 0)
