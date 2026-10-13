extends SceneTree
## Actual Owner/Player/Health with controlled director samples, not natural play.
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverProbeAttackTest "+label)
func step(combat: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
func run() -> void:
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := PlayerScript.new(); player.position = Vector2(240,0); host.add_child(player); player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(6,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director()
	check(not combat.start_action(&"probes"),"actual entrance cannot be bypassed")
	combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	check(combat.start_action(&"probes"),"actual paired probes missing from unique director")
	if failures: host.free(); await process_frame; quit(1); return
	combat.cancel_action()
	check(combat.probe_canvas.get_parent()==combat and combat.probe_canvas.get_script()==null and not combat.probe_canvas.is_processing() and not combat.probe_canvas.is_physics_processing() and not combat.probe_canvas.z_as_relative and combat.probe_canvas.z_index==22 and combat.z_index==-1,"visual-only projectile layer changes beam layer or adds another clock")
	await physics_frame
	for rate in [30,60,120]:
		for facing in [-1,1]:
			player.position = Vector2(240*facing,0); player.health.current_health = 100; player.health.invulnerable_time = 0
			check(combat.start_action(&"probes"),"implemented pair starts")
			var locked_target := player.global_position
			var locked_direction: Vector2 = combat.locked_direction
			var landings: PackedVector2Array = combat.probe_landings.duplicate()
			check(landings.size()==2 and landings[0].is_equal_approx(locked_target-locked_direction.orthogonal()*18) and landings[1].is_equal_approx(locked_target+locked_direction.orthogonal()*18),"warning locks two distinct original points")
			check(boss.should_show_attack_marker() and boss.get_visual_node().player.current_animation=="probes_warning" and not combat.probes[0].armed and not combat.probes[1].armed,"warning has locked range but no damage entities")
			# Move after the lock: this controlled fixture proves no retargeting.
			player.position += Vector2(0,100)
			step(combat,combat.DURATIONS[&"probes"][0])
			check(combat.action_stage==combat.Stage.ACTIVE and player.health.current_health==100 and not boss.should_show_attack_marker() and not combat.probes[0].armed and not combat.probes[1].armed,"active starts without early births")
			var root_at := boss.global_transform
			var births := [0,0]; var origins := PackedVector2Array([Vector2.INF,Vector2.INF])
			var iterations := 0
			while combat.action_stage==combat.Stage.ACTIVE and iterations<80:
				combat.advance(1.0/rate); iterations += 1
				check(combat.probe_landings==landings and combat.locked_direction==locked_direction and boss.global_transform==root_at,"motion cannot track points or move physical root")
				for index in range(2):
					var probe: RefCounted = combat.probes[index]
					if combat.probe_released[index] and births[index]==0:
						births[index] += 1; origins[index] = combat.probe_origins[index]
						var socket: StringName = &"probes_left" if index==0 else &"probes_right"
						check(probe.armed and probe.age==0 and probe.position==origins[index] and origins[index].is_equal_approx(boss.get_action_origin(socket,6)),"birth uses actual sampled sensor before any hit")
						check(combat.probe_births[index]>=combat.PROBE_RELEASES[index] and combat.probe_births[index]<combat.PROBE_RELEASES[index]+1.0/rate+0.00001,"single clock release quantization")
					if probe.armed:
						check(probe.origin==origins[index] and probe.landing==landings[index],"already released probe not reanchored")
				check(player.health.current_health==100,"fixed pair tracks moved target")
			check(iterations<80 and births==[1,1] and combat.action_stage==combat.Stage.RECOVERY and not combat.probes[0].armed and not combat.probes[1].armed,"exactly two finite original births")
			check(boss.get_visual_node().player.current_animation=="probes_recovery","recovery pose disconnected")
			step(combat,0.52); check(not combat.is_attacking(),"recovery never closes")
	# A target within centre range need not be within both articulated sensor paths.
	# Preserve the long-diagonal natural-run finding; no clamp or fallback spawn.
	for facing in [-1,1]:
		player.position = Vector2(200*facing,200); player.health.current_health = 100; player.health.invulnerable_time = 0
		check(combat.start_action(&"probes"),"long diagonal starts with strict actual path limits")
		step(combat,combat.DURATIONS[&"probes"][0]); step(combat,0.11)
		var actual_distance: float = combat.probe_origins[0].distance_to(combat.probe_landings[0])
		print("OBSERVER LONG DIAGONAL: facing%s left_path%s radius6 limit360"%[facing,actual_distance])
		check(actual_distance>360 and combat.probe_released[0] and not combat.probes[0].armed,"overlong left path was clamped/substituted or failed for another reason")
		step(combat,0.16)
		check(combat.probe_released[1] and combat.probes[1].armed and combat.probes[1].origin==combat.probe_origins[1],"legal right path silently lost or reused left origin")
		step(combat,0.29)
		check(player.health.current_health==73 and not combat.probes[0].armed,"legal right path does not damage exactly once")
		combat.advance(1.0/120); step(combat,0.52)
	# Real stationary target gets exactly one pair-wide hit despite removed immunity.
	player.position = Vector2(240,0); player.health.current_health = 100; player.health.invulnerable_time = 0
	check(combat.start_action(&"probes"),"stationary pair starts")
	step(combat,combat.DURATIONS[&"probes"][0])
	var events := [0]
	var on_damage := func(_current: float,_max: float) -> void: events[0] += 1
	player.health.health_changed.connect(on_damage)
	step(combat,0.24)
	check(player.health.current_health==73 and events[0]==1 and combat.probe_attempt.attempted,"actual first probe damage missing")
	player.health.invulnerable_time = 0; step(combat,0.32)
	check(player.health.current_health==73 and events[0]==1 and combat.action_stage==combat.Stage.ACTIVE,"right probe repeats damage or closing frame lost")
	combat.advance(1.0/120); check(combat.action_stage==combat.Stage.RECOVERY and not combat.probes[0].armed and not combat.probes[1].armed,"active ends without residual geometry")
	player.health.health_changed.disconnect(on_damage); step(combat,0.52)
	for scenario in ["hitch","hidden","pause","phase"]:
		player.health.current_health = 100; player.health.invulnerable_time = 0
		check(combat.start_action(&"probes"),scenario+" starts")
		step(combat,combat.DURATIONS[&"probes"][0]); step(combat,0.11)
		check(combat.probes[0].armed and not combat.probes[1].armed,scenario+" cancels actual live left probe")
		if scenario=="hitch": combat.advance(0.1)
		elif scenario=="hidden": combat.set_target_hidden(true)
		elif scenario=="pause": paused = true; await process_frame; await process_frame; paused = false
		else: combat.set_health_phase(2)
		check(not combat.is_attacking() and not combat.probes[0].armed and not combat.probes[1].armed and not boss.should_show_attack_marker() and player.health.current_health==100,scenario+" leaves authority/hidden damage")
		if scenario=="hidden": combat.set_target_hidden(false)
		if scenario=="phase": step(combat,0.65)
		combat.advance(0.01); combat.attack_gap = 99
	# Cancellation during Health is synchronous; later reentry cannot create right.
	player.health.current_health = 100; player.health.invulnerable_time = 0
	check(combat.start_action(&"probes"),"reentrant cancellation starts")
	step(combat,combat.DURATIONS[&"probes"][0])
	var on_cancel := func(_current: float,_max: float) -> void: combat.set_target_hidden(true); combat.advance(0.03)
	player.health.health_changed.connect(on_cancel); step(combat,0.24)
	check(player.health.current_health==73 and not combat.is_attacking() and not combat.probes[0].armed and not combat.probes[1].armed,"damage callback resurrects attack or pair")
	player.health.health_changed.disconnect(on_cancel); combat.set_target_hidden(false)
	check(not combat.start_action(&"unknown"),"unknown attacks silently admitted")
	check(combat.start_action(&"refract"),"verified refract unavailable"); combat.cancel_action()
	check(combat.start_action(&"probes"),"owner death fixture starts")
	step(combat,combat.DURATIONS[&"probes"][0]); step(combat,0.11); boss.take_damage(boss.health.current_health+1)
	check(combat.state==combat.State.DEATH and not combat.is_attacking() and not combat.probes[0].armed and not combat.probes[1].armed,"actual owner Health death leaves probes")
	host.free(); await process_frame
	if not failures: print("TEST PASS: RiftObserverProbeAttackTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
