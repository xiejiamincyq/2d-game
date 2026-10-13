extends SceneTree
## Real legacy Boss health/API with controlled director time, not normal play.
const Boss = preload("res://scripts/actors/OverseerBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BossPhaseShutdownTest "+label)
func _initialize() -> void: call_deferred("run")
func fixture() -> Dictionary:
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := Player.new(); player.position = Vector2(230,0); host.add_child(player)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1400,-900,2800,1800)
	boss.setup(6,shots,player); host.add_child(boss)
	var combat = boss.get_attack_director()
	combat.advance(combat.ENTRANCE_SECONDS); boss._update_entrance_reveal()
	check(boss.entrance_resolved and boss.health.current_health==10800 and boss.body_radius==56 and boss.scale==Vector2.ONE and boss.is_physics_processing(),"ordinary entered Boss defaults altered")
	check(player.health.current_health==100 and player.shield==0 and player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9),"ordinary Player defaults altered")
	return {"host":host,"shots":shots,"player":player,"boss":boss,"combat":combat}
func has_live_attack(f: Dictionary) -> bool:
	return f.boss.get_tentacle_attack().is_attacking() or f.combat.get_pattern().is_pattern_active()
func normal_phases() -> void:
	var f := fixture(); var combat = f.combat
	var phases: Array[int] = []; var requests: Array[int] = []
	combat.phase_changed.connect(func(phase: int): phases.append(phase))
	combat.reinforcements_requested.connect(func(count: int): requests.append(count))
	f.boss.take_damage(f.boss.BASE_MAX_HEALTH*0.31)
	check(is_equal_approx(f.boss.health.current_health,7452) and combat.get_state_name()=="TRANSITION_1" and requests==[6],"real 70-percent threshold does not request first transition")
	combat.advance(combat.TRANSITION_SECONDS)
	check(combat.get_state_name()=="PHASE_2" and phases==[2] and requests==[6],"normal phase-two callback/transition broken")
	f.boss.take_damage(f.boss.BASE_MAX_HEALTH*0.36)
	check(is_equal_approx(f.boss.health.current_health,3564) and combat.get_state_name()=="TRANSITION_2" and requests==[6,8],"real 35-percent threshold does not request second transition")
	combat.advance(combat.TRANSITION_SECONDS)
	check(combat.get_state_name()=="PHASE_3" and phases==[2,3] and requests==[6,8],"normal third phase is skipped/duplicated")
	combat.advance(combat.INITIAL_ATTACK_DELAY_SECONDS+0.01)
	check(has_live_attack(f) and combat.get_last_attack_class()==&"melee","normal non-cancelled phase cannot resume genuine attack")
	f.host.free(); await process_frame
func phase_callback_shutdown(cancel_at: int) -> void:
	var f := fixture(); var combat = f.combat
	var phases: Array[int] = []; var requests: Array[int] = []; var inside: Array[String] = []
	var ledger := {"terminal":false,"cues_after":[]}
	combat.combat_cue.connect(func(cue: StringName):
		if ledger.terminal: ledger.cues_after.append(cue))
	combat.reinforcements_requested.connect(func(count: int): requests.append(count))
	combat.phase_changed.connect(func(phase: int):
		phases.append(phase)
		if phase==cancel_at:
			combat.shutdown(); inside.append(combat.get_state_name()); ledger.terminal = true)
	# This accepted health event legitimately requests phase 3 before phase 2.
	f.boss.take_damage(f.boss.BASE_MAX_HEALTH*0.70)
	check(is_equal_approx(f.boss.health.current_health,3240) and combat.get_state_name()=="TRANSITION_1" and combat.requested_phase==3,"real high damage does not enter skipped-threshold fixture")
	combat.advance(combat.TRANSITION_SECONDS)
	if cancel_at==3: combat.advance(combat.TRANSITION_SECONDS)
	var expected_phases: Array = [2] if cancel_at==2 else [2,3]
	var expected_requests: Array = [6] if cancel_at==2 else [6,8]
	check(inside==["DEATH"] and combat.get_state_name()=="DEATH","phase%s callback shutdown overwritten on return: inside%s state%s" % [cancel_at,inside,combat.get_state_name()])
	check(phases==expected_phases and requests==expected_requests,"phase%s terminal callback emits extra phase/reinforcement: phases%s requests%s" % [cancel_at,phases,requests])
	check(ledger.cues_after.is_empty(),"phase%s callback emits combat cues after shutdown: %s" % [cancel_at,ledger.cues_after])
	for _step in range(3): combat.advance(combat.TRANSITION_SECONDS+combat.INITIAL_ATTACK_DELAY_SECONDS+0.01)
	check(combat.get_state_name()=="DEATH" and not has_live_attack(f) and f.shots.get_child_count()==0,"phase%s cancelled director restarts real attack" % cancel_at)
	check(phases==expected_phases and requests==expected_requests and ledger.cues_after.is_empty(),"phase%s later advance resurrects phases/reinforcement/cues" % cancel_at)
	check(not f.boss.death_resolved and is_equal_approx(f.boss.health.current_health,3240) and f.player.health.current_health==100,"terminal clock test fabricates actor/player death")
	f.host.free(); await process_frame
func reinforcement_callback_shutdown() -> void:
	var f := fixture(); var combat = f.combat
	var phases: Array[int] = []; var requests: Array[int] = []; var inside: Array[String] = []
	var ledger := {"terminal":false,"cues_after":[]}
	combat.phase_changed.connect(func(phase: int): phases.append(phase))
	combat.combat_cue.connect(func(cue: StringName):
		if ledger.terminal: ledger.cues_after.append(cue))
	combat.reinforcements_requested.connect(func(count: int):
		requests.append(count); combat.shutdown(); inside.append(combat.get_state_name()); ledger.terminal = true)
	f.boss.take_damage(f.boss.BASE_MAX_HEALTH*0.31)
	check(inside==["DEATH"] and combat.get_state_name()=="DEATH" and requests==[6],"reinforcement callback does not retain terminal shutdown")
	check(ledger.cues_after.is_empty(),"reinforcement callback shutdown followed by transition cue: %s" % [ledger.cues_after])
	for _step in range(3): combat.advance(combat.TRANSITION_SECONDS+combat.INITIAL_ATTACK_DELAY_SECONDS+0.01)
	check(combat.get_state_name()=="DEATH" and phases.is_empty() and requests==[6] and ledger.cues_after.is_empty() and not has_live_attack(f) and f.shots.get_child_count()==0,"reinforcement-cancelled director continues transition/attack")
	check(not f.boss.death_resolved and is_equal_approx(f.boss.health.current_health,7452),"reinforcement fixture mutates/kills actor instead of terminating director")
	f.host.free(); await process_frame
func pattern_callback_shutdown(mode: String) -> void:
	var f := fixture(); var combat = f.combat; var pattern = combat.get_pattern()
	f.player.position = Vector2(500,0) if mode=="finished_small" else Vector2(230,0)
	check(pattern.start_pattern(pattern.AIMED_FAN),"real pattern API rejected " + mode)
	var ledger := {"calls":0,"inside_state":"","inside_elapsed":-1.0}
	var cancel = func():
		if ledger.calls>0: return # shutdown.clear() legitimately emits cancelled too.
		ledger.calls += 1
		combat.shutdown()
		ledger.inside_state = combat.get_state_name(); ledger.inside_elapsed = combat.state_elapsed
	if mode=="finished_small":
		pattern.pattern_finished.connect(func(_kind): cancel.call())
		var plan: Array = pattern.get_active_plan()
		var last_seconds: float = plan[-1].time
		# Controlled pattern clock reaches the last event using its public API;
		# the Director's final small step must observe the synchronous shutdown.
		pattern.advance(last_seconds-1.0/120.0)
		check(pattern.is_pattern_active() and pattern.get_total_spawned()>0,
			"ordinary finite pattern did not reach pre-completion fixture")
	else:
		pattern.pattern_cancelled.connect(cancel)
	var step := 1.1 if mode=="cancelled_controlled_hitch" else (1.0/120.0 if mode=="finished_small" else 0.016)
	combat.advance(step)
	check(ledger.calls==1 and ledger.inside_state=="DEATH" and ledger.inside_elapsed==0.0,
		"real pattern signal did not synchronously terminate Director " + mode)
	check(combat.get_state_name()=="DEATH" and combat.state_elapsed==0.0,
		"old pattern step advanced terminal clock %s elapsed=%s" % [mode,combat.state_elapsed])
	check(not has_live_attack(f),"old pattern step started a new attack after shutdown " + mode)
	# The 1.1s case is deliberately an API-controlled hitch, NOT a natural
	# frame/performance claim. Small-step cases independently guard the clock.
	print("PATTERN SHUTDOWN CASE: %s controlled_step=%s state=%s elapsed=%s live_attack=%s" % [
		mode,step,combat.get_state_name(),combat.state_elapsed,has_live_attack(f)])
	await process_frame; await process_frame
	check(f.shots.get_child_count()==0 and not f.boss.death_resolved and f.player.health.current_health==100,
		"pattern shutdown leaked shots or fabricated health/death " + mode)
	f.host.free(); await process_frame
func run() -> void:
	await normal_phases()
	await phase_callback_shutdown(2); await phase_callback_shutdown(3)
	await reinforcement_callback_shutdown()
	await pattern_callback_shutdown("cancelled_small")
	await pattern_callback_shutdown("finished_small")
	await pattern_callback_shutdown("cancelled_controlled_hitch")
	if not failures: print("TEST PASS: BossPhaseShutdownTest %d" % checks)
	print("PHASE SHUTDOWN SUMMARY: checks%d failures%d" % [checks,failures])
	quit(1 if failures else 0)
