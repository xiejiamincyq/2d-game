extends SceneTree
## Real Actor/Health/owner events; cancellation must never fake victory or rearm.
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverLifecycleTest "+label)
func step(combat: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
func geometry_count(combat: Node) -> int:
	var count := 1 if combat.beam.armed else 0
	for probe in combat.probes:
		if probe.armed: count += 1
	for fragment in combat.refract.fragments:
		if fragment.armed: count += 1
	return count
func run() -> void:
	for kind in [&"beam",&"probes",&"refract"]:
		for mode in [&"pause",&"target_death",&"target_exit",&"target_queue",&"shots_exit",&"shots_queue",&"boss_death",&"boss_exit",&"boss_queue",&"stealth",&"hitch",&"phase_rearm",&"death_rearm",&"damage_cancel"]:
			var host := Node2D.new(); root.add_child(host)
			var shots := Node2D.new(); host.add_child(shots)
			var player := PlayerScript.new(); player.position = Vector2(240,0); host.add_child(player); player.set_physics_process(false)
			var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(6,shots,player); host.add_child(boss); boss.set_physics_process(false)
			var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
			var deaths := [0]; boss.died.connect(func(_actor,_coins,_source): deaths[0] += 1)
			var rearm: Array = []
			check(combat.start_action(kind),"actual lifecycle cannot start %s/%s"%[kind,mode]); step(combat,combat.DURATIONS[kind][0])
			if kind!=&"beam": step(combat,0.12)
			check(geometry_count(combat)>0,"fixture has no true born geometry %s/%s"%[kind,mode])
			if mode in [&"phase_rearm",&"death_rearm"]:
				combat.combat_cue.connect(func(cue):
					if cue in [&"boss_transition",&"boss_death"]: rearm.append(combat.start_action(kind))
				,CONNECT_ONE_SHOT)
			match mode:
				&"pause": paused = true; await process_frame; await process_frame
				&"target_death": player.health.damage(1000,true)
				&"target_exit": host.remove_child(player)
				&"target_queue": player.queue_free(); combat.advance(0.01)
				&"shots_exit": host.remove_child(shots)
				&"shots_queue": shots.queue_free(); combat.advance(0.01)
				&"boss_death",&"death_rearm": boss.take_damage(boss.health.current_health+1)
				&"boss_exit": host.remove_child(boss)
				&"boss_queue": boss.queue_free(); combat.advance(0.01)
				&"stealth": player._activate_assassin_stealth(); combat.advance(0.01)
				&"hitch": combat.advance(0.1)
				&"phase_rearm": boss.take_damage(boss.health.max_health*0.31)
				&"damage_cancel":
					player.health.health_changed.connect(func(_current,_maximum):
						combat.set_target_hidden(true); rearm.append(combat.start_action(kind))
					,CONNECT_ONE_SHOT)
					step(combat,0.01 if kind==&"beam" else (0.14 if kind==&"probes" else 0.48))
			check(not combat.is_attacking() and geometry_count(combat)==0,"event retains attack authority %s/%s"%[kind,mode])
			check(not boss.should_show_attack_marker() and deaths[0]==(1 if mode in [&"boss_death",&"death_rearm"] else 0),"cancellation fakes victory or keeps cue %s/%s"%[kind,mode])
			if mode in [&"phase_rearm",&"death_rearm",&"damage_cancel"]: check(rearm==[false],"synchronous lifecycle callback rearms %s/%s"%[kind,mode])
			if mode==&"damage_cancel": check(player.health.current_health==(64 if kind==&"beam" else (73 if kind==&"probes" else 76)),"Health callback repeats or loses the one actual hit")
			paused = false
			if is_instance_valid(player) and not player.is_inside_tree(): player.free()
			if is_instance_valid(shots) and not shots.is_inside_tree(): shots.free()
			if is_instance_valid(boss) and not boss.is_inside_tree(): boss.free()
			host.free(); await process_frame; await process_frame
	if not failures: print("TEST PASS: RiftObserverLifecycleTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
