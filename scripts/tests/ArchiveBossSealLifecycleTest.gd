extends "ArchiveBossSealTest.gd"
## Controlled actual-player sweep/immunity/reentrant callbacks; not normal input.
func run() -> void:
	var f := fixture(); var combat = f.combat
	check(combat.start_action(&"seal"),"sweep fixture cannot arm")
	var centers: Array = combat.seal_attack.centers.duplicate()
	f.target.position = Vector2(360,0); step(combat,combat.DURATIONS[&"seal"][0])
	check(f.target.attempts.is_empty(),"warning movement is incorrectly treated as active sweep")
	f.target.position = Vector2(120,0); step(combat,0.01)
	check(f.target.attempts==[[18.0,&"archive_seal"]] and f.target.health.current_health==82,"fast active crossing tunnels through actual small seals")
	step(combat,0.27)
	check(combat.action_stage==combat.Stage.RECOVERY and combat.seal_attack.centers.is_empty(),"sweep leaves damage zones")
	f.host.free(); await process_frame
	f = fixture(); combat = f.combat
	check(combat.start_action(&"seal"),"immunity fixture cannot arm")
	f.target.health.begin_invulnerability(10); step(combat,combat.DURATIONS[&"seal"][0])
	check(f.target.attempts==[[18.0,&"archive_seal"]] and f.target.health.current_health==100,"immune positive contact absent/damages")
	step(combat,0.01); step(combat,0.01)
	check(f.target.attempts.size()==1,"overlapping spots repeatedly try immune player")
	f.host.free(); await process_frame
	f = fixture(); combat = f.combat
	check(combat.start_action(&"seal"),"dynamic-wall fixture cannot arm")
	f.target.position = Vector2(240,0)
	var barrier := wall(f.host,centers[0],Vector2(2,2))
	var barrier_two := wall(f.host,centers[1],Vector2(2,2))
	await physics_frame; await physics_frame
	step(combat,combat.DURATIONS[&"seal"][0])
	check(f.target.attempts.is_empty(),"late terrain from-inside seal does not block damage")
	barrier.free(); barrier_two.free(); f.host.free(); await process_frame
	for callback in ["shutdown","boss-death","target-detach"]:
		f = fixture(); combat = f.combat
		check(combat.start_action(&"seal"),"reentrant fixture cannot arm "+callback)
		var owner = f.boss; var target = f.target; var host = f.host
		target.health.health_changed.connect(func(_current,_maximum):
			match callback:
				"shutdown": combat.shutdown()
				"boss-death": owner.take_damage(owner.health.current_health+1)
				"target-detach": host.remove_child(target)
		,CONNECT_ONE_SHOT)
		step(combat,combat.DURATIONS[&"seal"][0])
		check(not combat.is_attacking() and combat.seal_attack.centers.is_empty() and target.attempts.size()==1,"damage callback restarts/writes cancelled stage "+callback)
		await process_frame
		if is_instance_valid(target) and not target.is_inside_tree(): target.free()
		host.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveBossSealLifecycleTest %d" % checks)
	quit(1 if failures else 0)
