extends "ArchiveEncounterTest.gd"
## Real map/factory/bones/health-triggered brood. Controlled lifecycle, not a win.
const Boss = preload("res://scripts/actors/ArchiveArchivistBoss.gd")
func step(combat: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
func run() -> void:
	var f := fixture(521); var director = f.director
	f.player.position = Vector2(240,-672)
	director.spawn_queue.clear(); director._prepare_boss()
	check(director.begin_boss(),"actual archive Boss unavailable")
	if failures: f.host.free(); await process_frame; quit(1); return
	var boss = director.get_active_boss(); var combat = boss.get_attack_director()
	check(boss is Boss,"actual Archivist substituted")
	boss.set_physics_process(false); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	boss.take_damage(boss.BASE_MAX_HEALTH*0.4); step(combat,0.65)
	check(combat.current_phase==2 and combat.start_action(&"brood"),"real health cannot enter brood phase")
	step(combat,combat.DURATIONS[&"brood"][0]-0.001)
	check(director.get_active_enemies().size()==1,"mother bodies born before warning")
	step(combat,0.001)
	check(director.get_active_enemies().size()==3 and director.reinforcements_committed==2,"phase2 actual finite factory birth absent")
	for actor in director.get_active_enemies(): actor.set_physics_process(false)
	check(director.active_portals.is_empty() and director.portal_spawn_queues.is_empty(),"generic periodic portal system reused")
	boss.take_damage(boss.BASE_MAX_HEALTH*0.35); step(combat,0.65)
	check(combat.current_phase==3 and combat.start_action(&"brood"),"real health cannot enter third phase")
	step(combat,combat.DURATIONS[&"brood"][0])
	var actors: Array[Node] = director.get_active_enemies().duplicate(); actors.erase(boss)
	check(actors.size()==5 and director.reinforcements_committed==5,"absolute five-mother budget wrong")
	var motes := 0; var planters := 0
	for actor in actors:
		actor.set_physics_process(false)
		check(f.map.layout.is_position_walkable(actor.global_position,16) and actor.global_position.distance_to(f.player.global_position)>=100,"unsafe/sudden contact birth")
		check(actor.global_position.distance_to(boss.global_position)>77 and actor.scale==Vector2.ONE and actor.modulate.a==1 and actor.should_show_health_bar(),"overlapping/non-native/translucent mother")
		if actor is Mote: motes += 1; check(actor.native_visual.skeleton.get_bone_count()==16 and not actor.is_fragment,"wrong native Mote")
		elif actor is Planter: planters += 1; check(actor.native_visual.skeleton.get_bone_count()==20,"wrong native Planter")
		else: check(false,"generic enemy substituted")
	check(motes==3 and planters==2,"global mother sequence permits too many splits")
	for index in actors.size():
		for other in range(index+1,actors.size()):
			check(actors[index].global_position.distance_to(actors[other].global_position)>=76,"birth silhouettes/head bars overlap despite collision clearance")
	director._on_boss_reinforcements_requested(boss,999)
	check(director.get_active_enemies().size()==6 and director.reinforcements_committed==5,"reentrant/forged request escapes budget")
	for actor in actors:
		if actor is Mote: actor.take_damage(actor.health.current_health+1)
	check(director.pending_births.size()<=6,"more than six fragments reserved")
	await process_frame; await process_frame
	var survivors: Array[Node] = director.get_active_enemies().duplicate(); survivors.erase(boss)
	check(survivors.size()<=8 and survivors.size()==planters+6 and director.pending_births.is_empty(),"fragment/live capacity escapes finite bound")
	for actor in survivors: actor.set_physics_process(false)
	combat.cancel_action(); combat.advance(100)
	check(director.reinforcements_committed==5 and combat.action!=&"brood","natural loop emits new mothers after exhausted phase")
	f.host.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveBossBroodBirthTest %d" % checks)
	quit(1 if failures else 0)
