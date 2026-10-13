extends "ArchiveBossSealTest.gd"
## Actual native Actor, finite phase requests and reentrant cancellation; not a win.
func run() -> void:
	var f := fixture(); var combat = f.combat
	check(not combat.start_action(&"brood"),"brood available during first phase")
	combat.set_health_phase(2); step(combat,0.65)
	check(combat.start_action(&"brood"),"actual independent brood action unavailable")
	if failures: f.host.free(); await process_frame; quit(1); return
	var requests: Array = []
	f.boss.reinforcements_requested.connect(func(owner,count): requests.append([owner.get_instance_id(),count]))
	check(f.boss.should_show_attack_marker() and f.boss.get_visual_node().player.current_animation=="brood_warning","native short brood warning absent")
	step(combat,combat.DURATIONS[&"brood"][0]-0.001)
	check(requests.is_empty(),"brood releases before configured warning")
	step(combat,0.001)
	check(requests==[[f.boss.get_instance_id(),2]] and combat.action_stage==combat.Stage.ACTIVE,"phase2 finite actual Boss request wrong")
	check(f.boss.get_visual_node().player.current_animation=="brood_attack" and not f.boss.should_show_attack_marker(),"native release mismatch")
	step(combat,0.36); step(combat,0.70)
	check(not combat.is_attacking() and not combat.start_action(&"brood"),"phase2 can repeat reinforcements indefinitely")
	combat.set_health_phase(3); step(combat,0.65)
	check(combat.start_action(&"brood"),"phase3 brood absent")
	step(combat,combat.DURATIONS[&"brood"][0]); step(combat,0.36); step(combat,0.70)
	check(requests==[[f.boss.get_instance_id(),2],[f.boss.get_instance_id(),3]] and not combat.start_action(&"brood"),"absolute 2+3 phase budget wrong")
	f.host.free(); await process_frame
	# Unreleased cancellation may retry; release consumes its phase before callbacks.
	for mode in ["pause","stealth","shutdown","boss-death","target-detach"]:
		f = fixture(); combat = f.combat; combat.set_health_phase(2); step(combat,0.65)
		requests = []
		f.boss.reinforcements_requested.connect(func(_owner,count): requests.append(count))
		check(combat.start_action(&"brood"),"cancel fixture cannot arm "+mode)
		match mode:
			"pause": paused = true; await process_frame; await process_frame; paused = false
			"stealth": combat.set_target_hidden(true)
			"shutdown": combat.shutdown()
			"boss-death": f.boss.take_damage(f.boss.health.current_health+1)
			"target-detach": f.host.remove_child(f.target)
		check(not combat.is_attacking() and requests.is_empty(),"cancelled brood births "+mode)
		await process_frame
		if is_instance_valid(f.target) and not f.target.is_inside_tree(): f.target.free()
		f.host.free(); await process_frame
	f = fixture(); combat = f.combat; combat.set_health_phase(2); step(combat,0.65)
	var reentrant_requests: Array = []
	f.boss.reinforcements_requested.connect(func(_owner,count):
		reentrant_requests.append(count); combat.cancel_action()
		check(not combat.start_action(&"brood"),"release callback consumes no phase budget")
	)
	check(combat.start_action(&"brood"),"reentrant fixture cannot arm")
	step(combat,combat.DURATIONS[&"brood"][0])
	check(reentrant_requests==[2] and not combat.is_attacking(),"callback restarts cancelled action/duplicate brood")
	f.host.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveBossBroodTest %d" % checks)
	quit(1 if failures else 0)
