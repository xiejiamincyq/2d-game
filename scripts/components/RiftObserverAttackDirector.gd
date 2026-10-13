extends Node2D
## Observer-only combat authority. Unfinished actions are never silently substituted.
signal phase_changed(phase: int)
signal combat_cue(cue: StringName)
enum State { ENTRANCE,PHASE_1,TRANSITION_1,PHASE_2,TRANSITION_2,PHASE_3,DEATH }
enum Stage { IDLE,WARNING,ACTIVE,RECOVERY }
const ENTRANCE_SECONDS := 1.4
const TRANSITION_SECONDS := 0.65
const MAX_ATTACK_STEP := 1.0/15.0
const ACTION_ORDER := [&"beam",&"probes",&"refract"]
const DURATIONS := {&"beam":[0.50,0.12,0.45],&"probes":[0.45,0.56,0.52],&"refract":[0.45,0.60,0.60]}
const Escape = preload("res://scripts/components/BossEscapeGate.gd")
const Beam = preload("res://scripts/components/RiftObserverBeam.gd")
const Probe = preload("res://scripts/components/RiftObserverProbe.gd")
const RefractVolley = preload("res://scripts/components/RiftObserverRefractVolley.gd")
const PROBE_RELEASES := [0.1008,0.2576]
var beam: RefCounted = Beam.new()
var preview_beam: RefCounted = Beam.new()
var preview_paths: Array[Vector2] = []
var escape_route := {}
var refract: RefCounted = RefractVolley.new()
var probes: Array[RefCounted] = [Probe.new(),Probe.new()]
var probe_landings := PackedVector2Array([Vector2.ZERO,Vector2.ZERO])
var probe_origins := PackedVector2Array([Vector2.INF,Vector2.INF])
var probe_released := [false,false]
var probe_births := [0.0,0.0]
var probe_attempt := {"attempted":false}
var probe_canvas: Node2D
var boss: CharacterBody2D
var target_player: Node2D
var projectile_parent: Node2D
var linked_health: Node
var owner_health: Node
var state := State.ENTRANCE
var current_phase := 0
var requested_phase := 1
var state_elapsed := 0.0
var attack_gap := 0.65
var next_action_index := 0
var action: StringName = &""
var action_stage := Stage.IDLE
var action_elapsed := 0.0
var action_serial := 0
var locked_origin := Vector2.ZERO
var locked_direction := Vector2.RIGHT
var previous_target := Vector2.ZERO
var target_hidden := false
var pause_cancelled := false
var cancelling := false
func configure(actor: CharacterBody2D,target: Node2D,shots: Node2D) -> void:
	boss = actor; target_player = target; projectile_parent = shots
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_as_relative = false; z_index = -1; show_behind_parent = true
	probe_canvas = Node2D.new(); probe_canvas.name = "ProbeVisual"
	probe_canvas.z_as_relative = false; probe_canvas.z_index = 22
	probe_canvas.draw.connect(_draw_probes); add_child(probe_canvas)
	if is_instance_valid(target):
		target.tree_exiting.connect(_target_departed); linked_health = target.get("health")
		if is_instance_valid(linked_health): linked_health.connect("died",_target_departed)
	if is_instance_valid(shots): shots.tree_exiting.connect(shutdown)
	if is_instance_valid(actor):
		actor.tree_exiting.connect(shutdown); owner_health = actor.get("health")
		if is_instance_valid(owner_health): owner_health.connect("died",shutdown)
func get_state_name() -> String: return State.keys()[state]
func is_attacking() -> bool: return action_stage!=Stage.IDLE
func is_movement_locked() -> bool: return state in [State.ENTRANCE,State.TRANSITION_1,State.TRANSITION_2,State.DEATH] or is_attacking()
func get_last_attack_class() -> StringName: return &"ranged"
func _owners_available() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(boss) and boss.is_inside_tree() and not boss.is_queued_for_deletion() and not boss.death_resolved and is_instance_valid(owner_health) and owner_health.current_health>0 and is_instance_valid(projectile_parent) and projectile_parent.is_inside_tree() and not projectile_parent.is_queued_for_deletion()
func _target_alive() -> bool:
	return is_instance_valid(target_player) and target_player.is_inside_tree() and not target_player.is_queued_for_deletion() and is_instance_valid(linked_health) and linked_health.current_health>0 and not target_player.is_stealthed()
func _sample_motion() -> void:
	if is_instance_valid(boss) and boss.is_inside_tree(): boss._update_boss_motion(0)
func _target_departed() -> void:
	target_hidden = true; cancel_action(); attack_gap = maxf(attack_gap,1.1)
func _process(_delta: float) -> void:
	if get_tree().paused and not pause_cancelled:
		pause_cancelled = true; cancel_action(); attack_gap = maxf(attack_gap,1.1)
func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0 or state==State.DEATH: return
	if get_tree().paused: _process(0); return
	pause_cancelled = false
	if not _owners_available(): shutdown(); return
	if not _target_alive(): _target_departed(); return
	state_elapsed += delta
	if state==State.ENTRANCE:
		if state_elapsed>=ENTRANCE_SECONDS: _enter_phase(1)
		return
	if state in [State.TRANSITION_1,State.TRANSITION_2]:
		if state_elapsed>=TRANSITION_SECONDS: _enter_phase(current_phase+1)
		return
	if target_hidden: return
	if action_stage==Stage.WARNING and not Escape.route_still_clear(boss,target_player,escape_route): cancel_action(); attack_gap = 0.2; return
	if not is_attacking():
		attack_gap = maxf(0,attack_gap-delta)
		if attack_gap<=0:
			_start_next_action()
		return
	if delta>MAX_ATTACK_STEP: cancel_action(); attack_gap = maxf(attack_gap,1.1); return
	var serial := action_serial; var before := action_elapsed
	var duration: float = DURATIONS[action][action_stage-1]
	if action_stage==Stage.ACTIVE and before>=duration-0.000001:
		# Keep the closing damage frame visible; next tick closes without a hit.
		action_stage = Stage.RECOVERY; action_elapsed = 0; _cancel_geometry()
		previous_target = target_player.global_position; _sample_motion(); _redraw_geometry(); return
	action_elapsed = minf(duration,action_elapsed+delta); _sample_motion()
	if serial!=action_serial or state==State.DEATH: return
	if action_stage==Stage.ACTIVE:
		# No warning or post-active part of a movement step can cause a hit.
		var last := minf(action_elapsed,duration)
		var target_end := previous_target.lerp(target_player.global_position,clampf((last-before)/delta,0,1))
		match action:
			&"beam": beam.resolve_hit(previous_target,target_end)
			&"probes": _advance_probes(before,last,previous_target,target_end,serial)
			&"refract": refract.advance(self,before,last,previous_target,target_end,serial)
		if serial!=action_serial or state==State.DEATH: return
		if action==&"beam" and not beam.armed: cancel_action(); attack_gap = maxf(attack_gap,1.1); return
	previous_target = target_player.global_position
	if action_elapsed>=duration-0.000001:
		if action_stage==Stage.WARNING:
			action_elapsed = 0; action_stage = Stage.ACTIVE; _sample_motion()
			# Actual articulated socket at release, never a centre or prior-rest fake.
			if action==&"beam":
				locked_origin = boss.get_action_origin(&"beam",Beam.RADIUS)
				if not locked_origin.is_equal_approx(preview_beam.origin): cancel_action(); attack_gap = 1.1; return
				if not beam.arm(boss,target_player,locked_origin,locked_direction): cancel_action(); attack_gap = maxf(attack_gap,1.1); return
		elif action_stage==Stage.RECOVERY: cancel_action(); attack_gap = 1.1 if current_phase<3 else 0.85
	_redraw_geometry()
func _start_next_action() -> void:
	if boss.global_position.distance_to(target_player.global_position)>340:
		attack_gap = 0.2; return
	for _attempt in ACTION_ORDER.size():
		var kind: StringName = ACTION_ORDER[next_action_index]
		next_action_index = (next_action_index+1)%ACTION_ORDER.size()
		if start_action(kind): return
		if state==State.DEATH or target_hidden: return
	# Invalid articulated birth skips this slot, never a same-frame infinite retry.
	attack_gap = 0.2
func start_action(kind: StringName) -> bool:
	if cancelling or kind not in DURATIONS or state not in [State.PHASE_1,State.PHASE_2,State.PHASE_3] or is_attacking() or get_tree().paused or target_hidden or not _target_alive() or not _owners_available() or not boss.entrance_resolved: return false
	boss._update_visual_facing(target_player.global_position)
	action = kind; action_stage = Stage.WARNING; action_elapsed = 0; action_serial += 1; _sample_motion()
	if not _lock_action(kind): cancel_action(); return false
	if kind==&"beam":
		var origin := _predict_socket(&"beam",Beam.RADIUS,0,false)
		if not preview_beam.arm(boss,target_player,origin,locked_direction): cancel_action(); return false
		var danger := func(at: Vector2,_age: float) -> bool:
			return Escape.segment_danger(at,preview_beam.origin,preview_beam.tip,Beam.RADIUS+target_player.get_body_radius())
		if not Escape.has_route(boss,target_player,DURATIONS[kind][0],DURATIONS[kind][1],boss.world_bounds,danger,escape_route): cancel_action(); return false
	elif kind==&"probes":
		for index in 2:
			var origin := _predict_socket(&"probes_left" if index==0 else &"probes_right",Probe.RADIUS,PROBE_RELEASES[index],true)
			if not origin.is_finite(): cancel_action(); return false
			preview_paths.append(origin)
			preview_paths.append(probe_landings[index])
	elif kind==&"refract":
		for batch in 3:
			var origin := _predict_socket(&"refract",RefractVolley.Fragment.RADIUS,RefractVolley.RELEASES[batch],true)
			if not origin.is_finite(): cancel_action(); return false
			for angle in RefractVolley.ANGLES[batch]:
				preview_paths.append(origin); preview_paths.append(origin+locked_direction.rotated(angle)*refract.path_length)
	if kind!=&"beam":
		var danger := func(at: Vector2,age: float) -> bool:
			for index in range(0,preview_paths.size(),2):
				var release: float = PROBE_RELEASES[index/2] if kind==&"probes" else RefractVolley.RELEASES[index/6]
				var travel := age-release
				var flight: float = Probe.FLIGHT_SECONDS if kind==&"probes" else RefractVolley.Fragment.FLIGHT_SECONDS
				var life: float = Probe.LIFE_SECONDS if kind==&"probes" else RefractVolley.Fragment.LIFE_SECONDS
				if travel<0 or travel>life: continue
				var point := preview_paths[index].lerp(preview_paths[index+1],clampf(travel/flight,0,1))
				# Fast sampled flight plus <=1/15 release-pose uncertainty.
				if at.distance_to(point)<=14+target_player.get_body_radius()+18: return true
			return false
		if not Escape.has_route(boss,target_player,DURATIONS[kind][0],DURATIONS[kind][1],boss.world_bounds,danger,escape_route): cancel_action(); return false
	previous_target = target_player.global_position; boss.velocity = Vector2.ZERO
	combat_cue.emit(&"boss_barrage"); _redraw_geometry(); return true
func _lock_action(kind: StringName) -> bool:
	locked_origin = boss.get_action_origin(&"refract",RefractVolley.Fragment.RADIUS,true) if kind==&"refract" else boss.get_action_origin(&"beam",Beam.RADIUS)
	if not locked_origin.is_finite(): return false
	locked_direction = locked_origin.direction_to(target_player.global_position)
	if locked_direction.is_zero_approx(): locked_direction = Vector2.RIGHT
	if kind==&"probes":
		var side := locked_direction.orthogonal()*18
		probe_landings = PackedVector2Array([target_player.global_position-side,target_player.global_position+side])
		probe_origins = PackedVector2Array([Vector2.INF,Vector2.INF]); probe_released = [false,false]; probe_births = [0.0,0.0]
		probe_attempt = {"attempted":false}
	elif kind==&"refract": return refract.begin(locked_direction,locked_origin.distance_to(target_player.global_position))
	return true
func _predict_socket(socket: StringName,radius: float,age: float,clamp_socket: bool) -> Vector2:
	var previous_stage := action_stage; var previous_elapsed := action_elapsed
	action_stage = Stage.ACTIVE; action_elapsed = age; _sample_motion()
	var origin: Vector2 = boss.get_action_origin(socket,radius,clamp_socket)
	action_stage = previous_stage; action_elapsed = previous_elapsed; _sample_motion()
	return origin
func _advance_probes(before: float,after: float,from_player: Vector2,to_player: Vector2,serial: int) -> void:
	for index in range(2):
		if probe_released[index]:
			probes[index].resolve_hit(maxf(0,before-probe_births[index]),maxf(0,after-probe_births[index]),from_player,to_player)
		elif after>=PROBE_RELEASES[index]:
			# Birth belongs to the current sampled frame, never retroactive catchup.
			probe_released[index] = true; probe_births[index] = after
			var socket: StringName = &"probes_left" if index==0 else &"probes_right"
			probe_origins[index] = boss.get_action_origin(socket,Probe.RADIUS,true)
			if probe_origins[index].distance_to(preview_paths[index*2])>8: cancel_action(); attack_gap = 1.1; return
			probes[index].arm(boss,target_player,probe_origins[index],probe_landings[index],probe_attempt)
		if serial!=action_serial or state==State.DEATH: return
func _cancel_geometry() -> void:
	escape_route.clear()
	beam.cancel()
	preview_beam.cancel(); preview_paths.clear()
	for probe in probes: probe.cancel()
	refract.cancel()
func cancel_action() -> void:
	if cancelling: return
	cancelling = true; action_serial += 1; action = &""; action_stage = Stage.IDLE; action_elapsed = 0
	_cancel_geometry()
	if is_instance_valid(boss): boss.velocity = Vector2.ZERO
	_sample_motion(); _redraw_geometry(); cancelling = false
func _redraw_geometry() -> void:
	queue_redraw()
	if is_instance_valid(probe_canvas): probe_canvas.queue_redraw()
func _draw() -> void:
	if action_stage==Stage.WARNING and _owners_available() and _target_alive() and not target_hidden:
		if action==&"beam": preview_beam.draw_visual(self,false)
		else:
			for index in range(0,preview_paths.size(),2):
				Escape.draw_path(self,preview_paths[index],preview_paths[index+1],14)
	if action==&"beam" and action_stage==Stage.ACTIVE and _owners_available() and _target_alive() and not target_hidden:
		beam.draw_visual(self,true)
func _draw_probes() -> void:
	if action_stage==Stage.ACTIVE and _owners_available() and _target_alive() and not target_hidden:
		match action:
			&"probes":
				for probe in probes: probe.draw_visual(probe_canvas)
			&"refract": refract.draw_visual(probe_canvas)
func set_target_hidden(value: bool) -> void:
	if value==target_hidden: return
	target_hidden = value
	if value: cancel_action(); attack_gap = maxf(attack_gap,1.1)
func set_health_phase(phase: int) -> void:
	requested_phase = maxi(requested_phase,clampi(phase,1,3))
	if current_phase>0 and requested_phase>current_phase and state in [State.PHASE_1,State.PHASE_2,State.PHASE_3]:
		state = State.TRANSITION_1 if current_phase==1 else State.TRANSITION_2; state_elapsed = 0
		cancel_action()
		if state!=State.DEATH: combat_cue.emit(&"boss_transition")
func _enter_phase(phase: int) -> void:
	current_phase = phase; state = [State.PHASE_1,State.PHASE_2,State.PHASE_3][phase-1]
	state_elapsed = 0; attack_gap = 0.65; next_action_index = 0; phase_changed.emit(phase)
	if state in [State.PHASE_1,State.PHASE_2,State.PHASE_3] and requested_phase>phase: set_health_phase(requested_phase)
func shutdown() -> void:
	if state==State.DEATH: return
	state = State.DEATH; cancel_action(); state_elapsed = 0; combat_cue.emit(&"boss_death")
func _exit_tree() -> void:
	shutdown()
	for pair in [[target_player,"tree_exiting",_target_departed],[linked_health,"died",_target_departed],[projectile_parent,"tree_exiting",shutdown],[boss,"tree_exiting",shutdown],[owner_health,"died",shutdown]]:
		if is_instance_valid(pair[0]) and pair[0].is_connected(pair[1],pair[2]): pair[0].disconnect(pair[1],pair[2])
