extends Node2D
## Priest-only combat authority. Each completed attack is admitted explicitly.
signal phase_changed(phase: int)
signal combat_cue(cue: StringName)
enum State { ENTRANCE,PHASE_1,TRANSITION_1,PHASE_2,TRANSITION_2,PHASE_3,DEATH }
enum Stage { IDLE,WARNING,ACTIVE,RECOVERY }
const ENTRANCE_SECONDS := 1.4
const TRANSITION_SECONDS := 0.65
const DURATIONS := {&"bell":[0.42,0.42,0.54],&"pendant":[0.36,0.56,0.66],&"crown":[0.36,0.48,0.60]}
const Escape = preload("res://scripts/components/BossEscapeGate.gd")
const Strike = preload("res://scripts/components/BellPriestStrike.gd")
const Pendant = preload("res://scripts/components/BellPriestPendantProjectile.gd")
const Crown = preload("res://scripts/components/BellPriestCrownProjectile.gd")
const MAX_PENDANTS := 2
const MAX_CROWN := 6
const CROWN_NOTES := [0.08,0.23,0.38]
const ACTION_ORDER := [&"bell",&"pendant",&"crown"]
var strike: RefCounted = Strike.new()
var previous_target := Vector2.ZERO
var pendant_origins: Array[Vector2] = []
var pendant_headings: Array[Vector2] = []
var pendant_released := false
var pendant_attempt: Dictionary = {}
var crown_notes := 0
var next_action_index := 0
var owned_projectiles: Array[Node2D] = []
var boss: CharacterBody2D
var target_player: Node2D
var projectile_parent: Node2D
var linked_health: Node
var state := State.ENTRANCE
var current_phase := 0
var requested_phase := 1
var state_elapsed := 0.0
var attack_gap := 0.65
var action: StringName = &""
var action_stage := Stage.IDLE
var action_elapsed := 0.0
var action_serial := 0
var locked_origin := Vector2.ZERO
var locked_direction := Vector2.RIGHT
var target_hidden := false
var pause_cancelled := false
var cancelling := false
var escape_route := {}
func configure(actor: CharacterBody2D,target: Node2D,shots: Node2D) -> void:
	boss = actor; target_player = target; projectile_parent = shots
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_as_relative = false; z_index = -1; show_behind_parent = true
	if is_instance_valid(target):
		target.tree_exiting.connect(_target_departed); linked_health = target.get("health")
		if is_instance_valid(linked_health): linked_health.connect("died",_target_departed)
	if is_instance_valid(shots): shots.tree_exiting.connect(shutdown)
func get_state_name() -> String: return State.keys()[state]
func is_attacking() -> bool: return action_stage!=Stage.IDLE
func is_movement_locked() -> bool: return state in [State.ENTRANCE,State.TRANSITION_1,State.TRANSITION_2,State.DEATH] or is_attacking()
func get_last_attack_class() -> StringName: return &"melee" if action==&"bell" else &"ranged"
func _owners_available() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(boss) and boss.is_inside_tree() and not boss.is_queued_for_deletion() and not boss.death_resolved and is_instance_valid(projectile_parent) and projectile_parent.is_inside_tree() and not projectile_parent.is_queued_for_deletion()
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
	if action_stage==Stage.WARNING and delta>1.0/15.0: cancel_action(); attack_gap = 1.1; return
	if action_stage==Stage.WARNING and not Escape.route_still_clear(boss,target_player,escape_route): cancel_action(); attack_gap = 0.2; return
	if not is_attacking():
		attack_gap = maxf(0,attack_gap-delta)
		if attack_gap<=0: _start_next_action()
		return # At most one stage transition; no catch-up burst after a hitch.
	var serial := action_serial; var before := action_elapsed
	var duration: float = DURATIONS[action][action_stage-1]
	action_elapsed = minf(duration,action_elapsed+delta)
	# A hitch may slow a phrase but must never silently catch up three notes.
	if action==&"crown" and action_stage==Stage.ACTIVE and crown_notes<3:
		action_elapsed = minf(action_elapsed,CROWN_NOTES[crown_notes])
	_sample_motion()
	if serial!=action_serial or state==State.DEATH: return
	if action==&"bell" and action_stage==Stage.ACTIVE:
		var first := maxf(before,0.08); var last := minf(action_elapsed,0.16)
		if last>=first:
			# Only sweep the portion of this physics step inside the active interval.
			strike.resolve_hit(previous_target.lerp(target_player.global_position,(first-before)/delta),previous_target.lerp(target_player.global_position,(last-before)/delta))
			if serial!=action_serial or state==State.DEATH: return
			if not strike.armed: cancel_action(); attack_gap = 1.1; return
	elif action==&"pendant" and action_stage==Stage.ACTIVE and action_elapsed>=0.1 and not pendant_released:
		pendant_released = true; _release_pendants(serial)
		if serial!=action_serial or state==State.DEATH: return
	elif action==&"crown" and action_stage==Stage.ACTIVE and crown_notes<3 and action_elapsed>=CROWN_NOTES[crown_notes]-0.000001:
		crown_notes += 1; _release_crown_note(serial)
		if serial!=action_serial or state==State.DEATH: return
	previous_target = target_player.global_position
	if action_elapsed>=duration-0.000001:
		action_elapsed = 0
		if action_stage==Stage.WARNING: action_stage = Stage.ACTIVE; _sample_motion()
		elif action_stage==Stage.ACTIVE: action_stage = Stage.RECOVERY; strike.cancel(); _sample_motion()
		else: cancel_action(false); attack_gap = 1.1 if current_phase<3 else 0.85
	queue_redraw()
func _start_next_action() -> void:
	for _attempt in ACTION_ORDER.size():
		var kind: StringName = ACTION_ORDER[next_action_index]
		next_action_index = (next_action_index+1)%ACTION_ORDER.size()
		if kind==&"bell" and boss.global_position.distance_to(target_player.global_position)>155: continue
		if start_action(kind): return
		if state==State.DEATH or target_hidden: return
	# Blocked geometry/quota must not spin every physics frame.
	attack_gap = 0.2
func start_action(kind: StringName) -> bool:
	if cancelling or kind not in DURATIONS or state not in [State.PHASE_1,State.PHASE_2,State.PHASE_3] or is_attacking() or get_tree().paused or target_hidden or not _target_alive() or not _owners_available(): return false
	owned_projectiles = owned_projectiles.filter(func(shot): return is_instance_valid(shot) and not shot.is_queued_for_deletion())
	if not owned_projectiles.is_empty(): return false # Do not combine a new cue with a still-live previous volley.
	if kind==&"pendant" and owned_projectiles.filter(func(shot): return shot.get_script()==Pendant).size()+2>MAX_PENDANTS: return false
	if kind==&"crown" and owned_projectiles.filter(func(shot): return shot.get_script()==Crown).size()+6>MAX_CROWN: return false
	boss._update_visual_facing(target_player.global_position)
	# Resolve the actual warning pose BEFORE freezing its semantic world socket.
	action = kind; action_stage = Stage.WARNING; action_elapsed = 0; action_serial += 1
	_sample_motion()
	if kind==&"pendant":
		pendant_origins = [boss.get_action_origin(&"pendant_left",Pendant.RADIUS),boss.get_action_origin(&"pendant_right",Pendant.RADIUS)]
		# Both real sockets converge on the warning-time target, never a shared
		# centre ray that can miss a stationary target but intercept its escape.
		pendant_headings.clear()
		for origin in pendant_origins:
			var heading := origin.direction_to(target_player.global_position)
			pendant_headings.append(Vector2.RIGHT if heading.is_zero_approx() else heading)
		locked_origin = (pendant_origins[0]+pendant_origins[1])/2
		pendant_attempt = {"attempted":false}; pendant_released = false
	elif kind==&"crown": locked_origin = boss.get_action_origin(&"crown",4); crown_notes = 0
	else: locked_origin = boss.get_action_origin(&"bell",Strike.RADIUS)
	locked_direction = locked_origin.direction_to(target_player.global_position)
	if locked_direction.is_zero_approx(): locked_direction = Vector2.RIGHT
	if kind==&"bell" and not strike.arm(boss,target_player,locked_origin,locked_direction): cancel_action(); return false
	if kind==&"bell":
		var danger := func(at: Vector2,age: float) -> bool:
			return age>=0.08 and age<=0.16 and Escape.segment_danger(at,strike.origin,strike.tip,Strike.RADIUS+target_player.get_body_radius())
		if not Escape.has_route(boss,target_player,DURATIONS[kind][0],DURATIONS[kind][1],boss.world_bounds,danger,escape_route): cancel_action(); return false
	else:
		var danger := func(at: Vector2,age: float) -> bool:
			if kind==&"pendant":
				if age<0.1 or age>0.1+Pendant.LEG_SECONDS*2: return false
				var travel := age-0.1
				if travel>Pendant.LEG_SECONDS: travel = Pendant.LEG_SECONDS*2-travel
				for index in pendant_origins.size():
					var point := pendant_origins[index]+pendant_headings[index]*Pendant.SPEED*travel
					if at.distance_to(point)<=Pendant.RADIUS+target_player.get_body_radius()+6: return true
			else:
				var spread := 0.055+0.015*(current_phase-1)
				for release in CROWN_NOTES:
					var travel: float = age-release
					if travel<0 or travel>1.05: continue
					for side in [-1,1]:
						var point: Vector2 = locked_origin+locked_direction.rotated(side*spread)*440*travel
						if at.distance_to(point)<=4+target_player.get_body_radius()+3: return true
			return false
		if not Escape.has_route(boss,target_player,DURATIONS[kind][0],0.5 if kind==&"pendant" else 1.43,boss.world_bounds,danger,escape_route): cancel_action(); return false
	previous_target = target_player.global_position
	boss.velocity = Vector2.ZERO; combat_cue.emit(&"boss_barrage"); queue_redraw()
	return true
func _cast_available(serial: int) -> bool:
	if serial!=action_serial or state==State.DEATH: return false
	if get_tree().paused: _process(0); return false
	if not _owners_available(): shutdown(); return false
	if target_hidden or not _target_alive(): _target_departed(); return false
	return true
func _release_pendants(serial: int) -> void:
	for index in 2:
		if not _cast_available(serial): return
		var shot := Pendant.new()
		shot.configure(boss,target_player,pendant_origins[index],pendant_headings[index],pendant_attempt)
		projectile_parent.add_child(shot)
		# Child-entered callbacks may cancel the whole cast before append.
		if not _cast_available(serial):
			if is_instance_valid(shot): shot.cancel()
			return
		if not is_instance_valid(shot) or shot.is_queued_for_deletion(): cancel_action(); return
		owned_projectiles.append(shot)
func _release_crown_note(serial: int) -> void:
	var attempt := {"attempted":false}
	var spread := 0.055+0.015*(current_phase-1)
	for side in [-1,1]:
		if not _cast_available(serial): return
		var shot := Crown.new()
		shot.position = projectile_parent.to_local(locked_origin)
		shot.velocity = locked_direction.rotated(side*spread)*440
		shot.world_bounds = boss.world_bounds; shot.collision_layer = 0; shot.collision_mask = boss.collision_mask
		shot.set_target(target_player,attempt); projectile_parent.add_child(shot)
		if not _cast_available(serial):
			if is_instance_valid(shot): shot.cancel()
			return
		if not is_instance_valid(shot) or shot.is_queued_for_deletion(): cancel_action(); return
		shot.ignore_source(boss); owned_projectiles.append(shot)
func cancel_action(clear_projectiles: bool = true) -> void:
	if cancelling: return
	escape_route.clear()
	cancelling = true # Visibility/cleanup callbacks cannot rearm or recurse.
	action_serial += 1; action = &""; action_stage = Stage.IDLE; action_elapsed = 0
	strike.cancel(); pendant_origins.clear(); pendant_headings.clear(); pendant_released = false; pendant_attempt = {}; crown_notes = 0
	if clear_projectiles:
		for shot in owned_projectiles:
			if is_instance_valid(shot): shot.cancel()
		owned_projectiles.clear()
	if is_instance_valid(boss): boss.velocity = Vector2.ZERO
	_sample_motion(); queue_redraw(); cancelling = false
func _draw() -> void:
	if action_stage==Stage.WARNING and _owners_available() and _target_alive() and not target_hidden:
		if action==&"pendant":
			for index in pendant_origins.size(): Escape.draw_path(self,pendant_origins[index],pendant_origins[index]+pendant_headings[index]*Pendant.DISTANCE,Pendant.RADIUS)
		elif action==&"crown":
			var spread := 0.055+0.015*(current_phase-1)
			for side in [-1,1]: Escape.draw_path(self,locked_origin,locked_origin+locked_direction.rotated(side*spread)*440*1.05,4)
	if action==&"bell" and _owners_available() and _target_alive() and not target_hidden:
		if action_stage==Stage.WARNING or (action_stage==Stage.ACTIVE and action_elapsed<=0.16):
			strike.draw_visual(self,action_stage==Stage.ACTIVE and action_elapsed>=0.08)
func set_target_hidden(value: bool) -> void:
	if value==target_hidden: return
	target_hidden = value
	if value: cancel_action(); attack_gap = maxf(attack_gap,1.1)
func set_health_phase(phase: int) -> void:
	requested_phase = maxi(requested_phase,clampi(phase,1,3))
	if current_phase>0 and requested_phase>current_phase and state in [State.PHASE_1,State.PHASE_2,State.PHASE_3]: _begin_transition()
func _begin_transition() -> void:
	if state==State.DEATH: return
	state = State.TRANSITION_1 if current_phase==1 else State.TRANSITION_2; state_elapsed = 0
	cancel_action()
	if state==State.DEATH: return
	combat_cue.emit(&"boss_transition")
func _enter_phase(phase: int) -> void:
	current_phase = phase; state = [State.PHASE_1,State.PHASE_2,State.PHASE_3][phase-1]
	state_elapsed = 0; attack_gap = 0.65; phase_changed.emit(phase)
	if state in [State.PHASE_1,State.PHASE_2,State.PHASE_3] and requested_phase>phase: _begin_transition()
func shutdown() -> void:
	if state==State.DEATH: return
	state = State.DEATH; cancel_action(); state_elapsed = 0; combat_cue.emit(&"boss_death")
func _exit_tree() -> void:
	shutdown()
	if is_instance_valid(target_player) and target_player.tree_exiting.is_connected(_target_departed): target_player.tree_exiting.disconnect(_target_departed)
	if is_instance_valid(linked_health) and linked_health.is_connected("died",_target_departed): linked_health.disconnect("died",_target_departed)
	if is_instance_valid(projectile_parent) and projectile_parent.tree_exiting.is_connected(shutdown): projectile_parent.tree_exiting.disconnect(shutdown)
