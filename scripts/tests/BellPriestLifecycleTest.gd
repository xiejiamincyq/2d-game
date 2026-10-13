extends SceneTree
## Real health/owner/pause/stealth events and synchronous child-birth callbacks.
const Boss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BellPriestLifecycleTest "+label)
func _initialize() -> void: call_deferred("run")
func advance_warning(combat: Node,seconds: float = -1.0) -> void:
	var remaining: float = combat.DURATIONS[combat.action][0] if seconds<0 else seconds
	while remaining>0.0000001:
		var step := minf(1.0/120.0,remaining)
		combat.advance(step)
		remaining -= step

func run() -> void:
	for kind in [&"bell",&"pendant",&"crown"]:
		for mode in ["pause","target_death","target_exit","target_queue","shots_exit","shots_queue","boss_death","boss_exit","boss_queue","stealth","birth_pause","birth_stealth","birth_target_queue","birth_shots_queue","birth_cancel","cancel_rearm","phase_rearm"]:
			if kind==&"bell" and (mode.begins_with("birth_") or mode.ends_with("_rearm")): continue
			var host := Node2D.new(); root.add_child(host)
			var shots := Node2D.new(); host.add_child(shots)
			var player := Player.new(); player.position = Vector2(130,0); host.add_child(player); player.set_physics_process(false)
			var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(5,shots,player); host.add_child(boss); boss.set_physics_process(false)
			var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
			var deaths: Array = []; boss.died.connect(func(_b,_coins,_source): deaths.append(true))
			var rearm_calls: Array = []
			check(combat.start_action(kind),"cannot arm %s/%s"%[kind,mode])
			if mode.begins_with("birth_"):
				shots.child_entered_tree.connect(func(_shot):
					match mode:
						"birth_pause": paused = true
						"birth_stealth": player._activate_assassin_stealth()
						"birth_target_queue": player.queue_free()
						"birth_shots_queue": shots.queue_free()
						"birth_cancel": _shot.cancel()
				,CONNECT_ONE_SHOT)
			advance_warning(combat)
			combat.advance(0.10 if kind==&"pendant" else 0.08)
			if mode.ends_with("_rearm"):
				shots.get_child(0).visibility_changed.connect(func(): rearm_calls.append(combat.start_action(&"bell")),CONNECT_ONE_SHOT)
			if not mode.begins_with("birth_"):
				match mode:
					"pause": paused = true; combat.advance(0.01)
					# Controlled death event, independent of a preceding strike's immunity.
					"target_death": player.health.damage(1000,true)
					"target_exit": host.remove_child(player)
					"target_queue": player.queue_free(); combat.advance(0.01)
					"shots_exit": host.remove_child(shots)
					"shots_queue": shots.queue_free(); combat.advance(0.01)
					"boss_death": boss.take_damage(boss.health.current_health+1)
					"boss_exit": host.remove_child(boss)
					"boss_queue": boss.queue_free(); combat.advance(0.01)
					"stealth": player._activate_assassin_stealth(); combat.advance(0.01)
					"cancel_rearm": combat.cancel_action()
					"phase_rearm": boss.take_damage(boss.health.max_health*0.31)
			if mode.ends_with("_rearm"): check(rearm_calls==[false],"cleanup callback can start another attack %s/%s"%[kind,mode])
			check(not combat.is_attacking() and not combat.strike.armed and combat.owned_projectiles.is_empty(),"event leaves active authority/owned shots %s/%s"%[kind,mode])
			check(not boss.should_show_attack_marker() and deaths.size()==(1 if mode=="boss_death" else 0),"cancellation fakes victory/retains cue %s/%s"%[kind,mode])
			if is_instance_valid(shots):
				for shot in shots.get_children(): check(shot.is_queued_for_deletion() and not shot.visible,"cancelled newborn remains live %s/%s"%[kind,mode])
			paused = false
			await process_frame; await process_frame
			if is_instance_valid(shots): check(shots.get_child_count()==0,"late frame keeps shot %s/%s"%[kind,mode])
			if is_instance_valid(player) and not player.is_inside_tree(): player.free()
			if is_instance_valid(shots) and not shots.is_inside_tree(): shots.free()
			if is_instance_valid(boss) and not boss.is_inside_tree(): boss.free()
			host.free(); await process_frame
	if not failures: print("TEST PASS: BellPriestLifecycleTest %d"%checks)
	quit(1 if failures else 0)
