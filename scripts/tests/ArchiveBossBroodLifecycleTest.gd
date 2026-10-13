extends "ArchiveBossBroodBirthTest.gd"
## Actual native births interrupted by synchronous tree callbacks, not a playthrough.
func boss_fixture() -> Dictionary:
	var f := fixture(521)
	f.player.position = Vector2(240,-672)
	f.director.spawn_queue.clear(); f.director._prepare_boss()
	check(f.director.begin_boss(),"actual Boss boundary")
	f.boss = f.director.get_active_boss(); f.combat = f.boss.get_attack_director()
	f.boss.set_physics_process(false); f.combat.advance(1.4); f.boss._update_entrance_reveal()
	f.boss.take_damage(f.boss.BASE_MAX_HEALTH*0.4); step(f.combat,0.65)
	return f
func run() -> void:
	for mode in ["pause","cancel","boss-death","player-death","stealth","enemies-queued"]:
		var f := boss_fixture(); var director = f.director
		var enemies = f.boss.get_parent(); var entries := [0]
		director._on_boss_reinforcements_requested(f.boss,2)
		check(director.reinforcements_committed==0 and director.get_active_enemies().size()==1,"forged pre-release birth "+mode)
		enemies.child_entered_tree.connect(func(actor: Node):
			entries[0] += 1
			if actor.has_method("set_physics_process"): actor.set_physics_process(false)
			match mode:
				"pause": paused = true
				"cancel": f.combat.cancel_action()
				"boss-death": f.boss.take_damage(f.boss.health.current_health+1)
				"player-death": f.player.health.damage(100,true)
				"stealth": f.player.stealth_remaining = 1
				"enemies-queued": enemies.queue_free()
		,CONNECT_ONE_SHOT)
		check(f.combat.start_action(&"brood"),"cannot arm reentry "+mode)
		step(f.combat,f.combat.DURATIONS[&"brood"][0])
		paused = false
		check(entries[0]==1 and director.reinforcements_committed==2,"reentry creates additional/unreserved mother "+mode)
		check(director.get_active_enemies().size()<=1 and enemies.get_children().filter(func(a): return a is CharacterBody2D and a!=f.boss and not a.is_queued_for_deletion()).is_empty(),"late mother appended after cancellation "+mode)
		await process_frame; await process_frame
		if is_instance_valid(enemies) and not enemies.is_inside_tree(): enemies.free()
		f.host.free(); await process_frame
	# A real terrain collider surrounds the whole source. No fallback birth beyond it.
	var f := boss_fixture()
	var barrier := StaticBody2D.new(); barrier.position = f.boss.global_position
	var collider := CollisionShape2D.new(); var rect := RectangleShape2D.new(); rect.size = Vector2(500,500)
	collider.shape = rect; barrier.add_child(collider); f.host.add_child(barrier)
	await physics_frame; await physics_frame
	check(f.combat.start_action(&"brood"),"blocked-source cast cannot show warning")
	step(f.combat,f.combat.DURATIONS[&"brood"][0])
	check(f.director.reinforcements_committed==2 and f.director.get_active_enemies().size()==1,"blocked source births through terrain/refunds budget")
	check(f.director.active_portals.is_empty() and f.director.pending_births.is_empty(),"failed safe batch leaves retry debt")
	f.combat.cancel_action(); check(not f.combat.start_action(&"brood"),"blocked phase repeats indefinitely")
	f.host.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveBossBroodLifecycleTest %d"%checks)
	quit(1 if failures else 0)
