extends SceneTree
## Real native Actor / real Player health, controlled synchronous damage callback.
## Position changes only arrange the ACTIVE interval; not a play/dodge claim.
const Boss = preload("res://scripts/actors/NurseryVineBoss.gd")
class Target extends "res://scripts/actors/Player.gd":
	var damage_calls: Array[float] = []
	var on_damage := Callable()
	func take_damage(amount: float,source: StringName = &"") -> bool:
		damage_calls.append(amount)
		var accepted := super.take_damage(amount,source)
		if on_damage.is_valid(): on_damage.call()
		return accepted
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VineRootReentryTest " + label)
func _initialize() -> void: call_deferred("run")
func advance_warning(combat: Node) -> void:
	# Vine's while-boundary is strict >= (not epsilon-clamped): cross it by
	# one microsecond so floating addition cannot leave a false WARNING fixture.
	var remaining: float = combat.DURATIONS[combat.action][0]+0.000001
	var serial: int = combat.action_serial
	while remaining>0.0000001:
		var step := minf(1.0/120.0,remaining)
		combat.advance(step); remaining -= step
		if combat.action_serial!=serial: return # Do not let the fixture advance a replacement.
func run() -> void:
	for mode in ["normal", "roots_to_roots", "roots_to_lash", "lash_to_roots"]:
		var host := Node2D.new(); root.add_child(host)
		var shots := Node2D.new(); host.add_child(shots)
		var player := Target.new(); player.position = Vector2(200,0)
		player.world_bounds = Rect2(-1000,-1000,2000,2000)
		host.add_child(player); player.set_physics_process(false)
		var boss := Boss.new(); boss.world_bounds = player.world_bounds
		boss.setup(1,shots,player); host.add_child(boss); boss.set_physics_process(false)
		var combat = boss.get_attack_director()
		combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
		var old_action: StringName = &"lash" if mode=="lash_to_roots" else &"roots"
		var replacement: StringName = &"lash" if mode=="roots_to_lash" else &"roots"
		var snapshot := {}
		if mode!="normal":
			player.on_damage = func():
				player.on_damage = Callable() # One reentry, not recursive test scripting.
				combat.cancel_action()
				check(combat.start_action(replacement),"replacement not admitted " + mode)
				snapshot.merge({"serial":combat.action_serial,"action":combat.action,
					"elapsed":combat.action_elapsed,"centers":combat.root_centers.duplicate(),
					"gap":combat.attack_gap,"hits":player.damage_calls.size(),
					"origin":combat.locked_origin,"direction":combat.locked_direction})
		check(combat.start_action(old_action),"original warning not admitted " + mode)
		if not combat.is_attacking(): host.free(); await process_frame; continue
		if old_action==&"roots":
			# The original locked marks stay at x=200; wait off-mark so the
			# callback belongs to an old ACTIVE step, not warning completion.
			player.position = Vector2(350,0)
			advance_warning(combat)
			check(combat.action_stage==combat.Stage.ACTIVE and player.damage_calls.is_empty(),
				"controlled root ACTIVE setup already hit " + mode)
			player.position = Vector2(200,0)
			combat.advance(0.30)
		else:
			advance_warning(combat)
		if mode=="normal":
			check(player.damage_calls==[60.0] and player.health.current_health==40,
				"normal actual root no longer attempts exactly one 60 damage")
			combat.advance(0.5)
			check(player.damage_calls==[60.0] and player.health.current_health==40,
				"normal root repeats damage in later stagger/recovery")
		else:
			check(not snapshot.is_empty(),"real damage callback never ran " + mode)
			if not snapshot.is_empty():
				check(combat.action_serial==snapshot.serial and combat.action==snapshot.action
					and combat.action_stage==combat.Stage.WARNING,
					"old step replaced new action/state " + mode)
				check(combat.action_elapsed==snapshot.elapsed,
					"old ACTIVE delta entered replacement WARNING %s elapsed=%s expected=%s" % [mode,combat.action_elapsed,snapshot.elapsed])
				check(combat.root_centers==snapshot.centers and combat.locked_origin==snapshot.origin
					and combat.locked_direction==snapshot.direction,
					"old interval changed replacement geometry " + mode)
				check(combat.attack_gap==snapshot.gap and player.damage_calls.size()==snapshot.hits,
					"old interval changed new gap or delivered extra damage " + mode)
				check(player.damage_calls==[54.0 if old_action==&"lash" else 60.0]
					and player.health.current_health==(46 if old_action==&"lash" else 40),
					"real original damage control changed " + mode)
		print("ROOT REENTRY CASE: %s elapsed=%s hits=%s" % [mode,combat.action_elapsed,player.damage_calls])
		host.free(); await process_frame
	await phase_callback_shutdown()
	if not failures: print("TEST PASS: VineRootReentryTest %d; real 60-damage root control, three synchronous replacements and actual phase-signal shutdown" % checks)
	else: print("ROOT REENTRY RESULT: %s failures / %s checks" % [failures,checks])
	quit(1 if failures else 0)

func phase_callback_shutdown() -> void:
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := Target.new(); player.position = Vector2(200,0); host.add_child(player)
	player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000)
	boss.setup(1,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director()
	combat.advance(1.4); boss._update_entrance_reveal()
	var phases: Array[int] = []; var summons: Array[int] = []; var cues: Array[StringName] = []
	combat.phase_changed.connect(func(phase):
		phases.append(phase)
		if phase==2: combat.shutdown())
	combat.reinforcements_requested.connect(func(count): summons.append(count))
	combat.combat_cue.connect(func(cue): cues.append(cue))
	combat.set_health_phase(3)
	check(combat.get_state_name()=="TRANSITION_1" and summons==[6], "real requested phase-three transition not started")
	combat.advance(combat.TRANSITION_SECONDS)
	check(phases==[2] and combat.get_state_name()=="DEATH" and not combat.is_attacking(),
		"phase_changed(2) shutdown resurrected as " + combat.get_state_name())
	check(summons==[6] and cues==[&"boss_transition",&"boss_death"],
		"terminal phase callback emitted second reinforcement/transition")
	combat.advance(combat.TRANSITION_SECONDS)
	check(combat.get_state_name()=="DEATH" and phases==[2] and not combat.start_action(&"roots"),
		"terminal callback subsequently admitted phase three or attack")
	print("PHASE SHUTDOWN CASE: state=%s phases=%s summons=%s cues=%s" % [combat.get_state_name(),phases,summons,cues])
	host.free(); await process_frame
