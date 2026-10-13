extends Node2D
## Salt Boss owns this one physics clock. Bones supply claw tips, never damage.
signal phase_changed(phase: int)
signal reinforcements_requested(count: int)
signal combat_cue(cue: StringName)
enum State { ENTRANCE,PHASE_1,TRANSITION_1,PHASE_2,TRANSITION_2,PHASE_3,DEATH }
enum Stage { IDLE,WARNING,ACTIVE,RECOVERY }
const ENTRANCE_SECONDS := 1.4
const TRANSITION_SECONDS := 0.65
const DURATIONS := {&"ripple":[0.80,0.72,0.60],&"pincer":[0.52,0.36,0.58],&"salt":[0.36,0.18,0.62]}
const Escape = preload("res://scripts/components/BossEscapeGate.gd")
const RING_START := 110.0
const RING_END := 350.0
const RING_HALF_WIDTH := 6.0
const CLAW_RADIUS := 22.0
const WaveGeometry = preload("res://scripts/components/TideShellWaveGeometry.gd")
const SaltShot = preload("res://scripts/components/TideSaltProjectile.gd")
var boss: CharacterBody2D
var target_player: Node2D
var projectile_parent: Node
var linked_health: Node
var state := State.ENTRANCE
var current_phase := 0
var requested_phase := 1
var state_elapsed := 0.0
var attack_gap := 0.65
var attack_index := 0
var action: StringName = &""
var action_stage := Stage.IDLE
var action_elapsed := 0.0
var action_serial := 0
var locked_origin := Vector2.ZERO
var locked_direction := Vector2.RIGHT
var previous_target := Vector2.ZERO
var previous_claws: Array[Vector2] = []
var owned_projectiles: Array[Node2D] = []
var warning_paths: Array[Vector2] = []
var escape_route := {}
var target_hidden := false
var hit_delivered := false
var pause_cancelled := false

func configure(actor: CharacterBody2D,target: Node2D,shots: Node) -> void:
	boss = actor; target_player = target; projectile_parent = shots
	show_behind_parent = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(false)
	if is_instance_valid(target):
		target.tree_exiting.connect(_target_departed)
		linked_health = target.get("health")
		if is_instance_valid(linked_health) and linked_health.has_signal("died"): linked_health.connect("died",_target_departed)
	if is_instance_valid(shots): shots.tree_exiting.connect(shutdown)
func get_state_name() -> String: return State.keys()[state]
func is_attacking() -> bool: return action_stage!=Stage.IDLE
func is_movement_locked() -> bool:
	return state in [State.ENTRANCE,State.TRANSITION_1,State.TRANSITION_2,State.DEATH] or is_attacking()
func get_last_attack_class() -> StringName: return &"melee" if action==&"pincer" else &"ranged"
func _target_alive() -> bool:
	return is_instance_valid(target_player) and target_player.is_inside_tree() and not target_player.is_queued_for_deletion() and (not target_player.has_method("is_alive") or target_player.is_alive())
func _target_departed() -> void:
	target_hidden = true; cancel_action(); attack_gap = maxf(attack_gap,1.1)
func _process(_delta: float) -> void:
	if get_tree().paused and not pause_cancelled:
		pause_cancelled = true; cancel_action(); attack_gap = maxf(attack_gap,1.1)
func _sample_motion() -> void:
	if is_instance_valid(boss) and boss.has_method("_update_boss_motion"): boss._update_boss_motion(0)
func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0 or state==State.DEATH: return
	if get_tree().paused: _process(0); return
	pause_cancelled = false
	if not is_instance_valid(boss) or boss.death_resolved: shutdown(); return
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
		if attack_gap<=0:
			var chosen: StringName = [&"ripple",&"pincer",&"salt"][attack_index%3]
			if chosen==&"pincer" and boss.global_position.distance_to(target_player.global_position)>150: chosen = &"salt"
			if start_action(chosen): attack_index += 1
		return
	var serial := action_serial
	var duration: float = DURATIONS[action][action_stage-1]
	var step := minf(delta,maxf(0,duration-action_elapsed))
	var before := action_elapsed
	action_elapsed += step
	if action_stage==Stage.ACTIVE and action==&"pincer":
		_sweep_claws(before,action_elapsed)
	else:
		_sample_motion()
		if action_stage==Stage.ACTIVE: _resolve_active(before,action_elapsed)
	# Damage/signal handlers may replace/cancel this very same action type.
	if action_serial!=serial or state==State.DEATH: return
	previous_target = target_player.global_position
	if action_elapsed>=duration-0.000001:
		action_elapsed = 0
		if action_stage==Stage.WARNING:
			action_stage = Stage.ACTIVE
			_sample_motion()
			previous_claws = boss.get_claw_origins()
			if action==&"salt": _spawn_salt()
			else: _resolve_active(0,0)
		elif action_stage==Stage.ACTIVE:
			action_stage = Stage.RECOVERY
		else:
			# Normal recovery does not erase already-fired flying salt fragments.
			cancel_action(false); attack_gap = 1.1 if current_phase<3 else 0.9
	queue_redraw()

func start_action(kind: StringName) -> bool:
	if kind not in DURATIONS or is_attacking() or get_tree().paused or state not in [State.PHASE_1,State.PHASE_2,State.PHASE_3] or target_hidden or not _target_alive() or not is_instance_valid(boss) or boss.death_resolved: return false
	if kind==&"salt" and (not is_instance_valid(projectile_parent) or not projectile_parent.is_inside_tree() or projectile_parent.is_queued_for_deletion()): return false
	locked_origin = boss.global_position
	locked_direction = locked_origin.direction_to(target_player.global_position)
	if locked_direction==Vector2.ZERO: locked_direction = Vector2.RIGHT
	previous_target = target_player.global_position
	action = kind; action_stage = Stage.WARNING; action_elapsed = 0; action_serial += 1
	hit_delivered = false; boss.velocity = Vector2.ZERO
	owned_projectiles = owned_projectiles.filter(func(shot): return is_instance_valid(shot) and not shot.is_queued_for_deletion())
	if not owned_projectiles.is_empty(): cancel_action(false); attack_gap = 0.2; return false
	_sample_motion(); previous_claws = boss.get_claw_origins()
	warning_paths.clear()
	if kind==&"pincer":
		var prior: Array[Vector2] = previous_claws.duplicate()
		for index in range(31):
			action_stage = Stage.ACTIVE; action_elapsed = DURATIONS[kind][1]*index/30.0; _sample_motion()
			var claws: Array[Vector2] = boss.get_claw_origins()
			for claw in mini(prior.size(),claws.size()): warning_paths.append(prior[claw]); warning_paths.append(claws[claw])
			prior = claws
	elif kind==&"salt":
		action_stage = Stage.ACTIVE; action_elapsed = 0; _sample_motion()
		var origin: Vector2 = boss.get_safe_salt_origin()
		for angle in [-0.24,0.0,0.24]: warning_paths.append(origin); warning_paths.append(origin+locked_direction.rotated(angle)*350*1.4)
	action_stage = Stage.WARNING; action_elapsed = 0; _sample_motion(); previous_claws = boss.get_claw_origins()
	if kind==&"ripple":
		var danger := func(at: Vector2,age: float) -> bool:
			return absf(at.distance_to(locked_origin)-ring_radius(age))<=RING_HALF_WIDTH+target_player.get_body_radius()+3
		if not Escape.has_route(boss,target_player,DURATIONS[kind][0],DURATIONS[kind][1],boss.world_bounds,danger,escape_route): cancel_action(); attack_gap = 0.2; return false
	else:
		var radius: float = (CLAW_RADIUS if kind==&"pincer" else 6.0)+target_player.get_body_radius()
		var danger := func(at: Vector2,age: float) -> bool:
			for index in range(0,warning_paths.size(),2):
				if kind==&"salt":
					var point := warning_paths[index].lerp(warning_paths[index+1],clampf(age/1.4,0,1))
					if at.distance_to(point)<=radius+3: return true
				elif Escape.segment_danger(at,warning_paths[index],warning_paths[index+1],radius): return true
			return false
		if not Escape.has_route(boss,target_player,DURATIONS[kind][0],1.4 if kind==&"salt" else DURATIONS[kind][1],boss.world_bounds,danger,escape_route): cancel_action(); attack_gap = 0.2; return false
	combat_cue.emit(&"boss_barrage" if kind==&"salt" else &"boss_tentacle")
	queue_redraw(); return true
func _excluded_bodies() -> Array[RID]:
	var excluded: Array[RID] = [boss.get_rid()]
	if target_player is CollisionObject2D: excluded.append(target_player.get_rid())
	return excluded
func _point_visible(point: Vector2) -> bool:
	if boss.world_bounds.size!=Vector2.ZERO and not boss.world_bounds.has_point(point): return false
	return boss.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(locked_origin,point,boss.collision_mask,_excluded_bodies())).is_empty()
func _deliver_damage(amount: float) -> void:
	if hit_delivered or not _target_alive() or not target_player.has_method("take_damage"): return
	hit_delivered = true
	target_player.take_damage(amount,&"salt_tide")
func ring_radius(seconds: float) -> float: return lerpf(RING_START,RING_END,clampf(seconds/DURATIONS[&"ripple"][1],0,1))
func _sweep_claws(before: float,after: float) -> void:
	var serial := action_serial
	var current_target := target_player.global_position
	var start_target := previous_target
	# A complete 0.36s active clip is bounded to 30 sub-samples, including a
	# dropped frame spanning the return pose; bones still read this single clock.
	var steps := maxi(1,int(ceil((after-before)/0.012)))
	for index in range(1,steps+1):
		var fraction := index/float(steps)
		action_elapsed = lerpf(before,after,fraction)
		_sample_motion()
		var interpolated := start_target.lerp(current_target,fraction)
		_resolve_claw_hit(previous_target,interpolated)
		if serial!=action_serial or state==State.DEATH: return
		previous_target = interpolated
	action_elapsed = after
func _resolve_claw_hit(from_target: Vector2,to_target: Vector2) -> void:
	var serial := action_serial
	var claws: Array[Vector2] = boss.get_claw_origins()
	var radius: float = target_player.get_body_radius() if target_player.has_method("get_body_radius") else 13.0
	if not hit_delivered and not target_hidden and _target_alive():
		for index in mini(claws.size(),previous_claws.size()):
			var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,previous_claws[index]-from_target,claws[index]-to_target)
			if closest.length()<=CLAW_RADIUS+radius and _point_visible(to_target): _deliver_damage(48); break
	if action_serial==serial and state!=State.DEATH: previous_claws = claws
func _resolve_active(before: float,after: float) -> void:
	if hit_delivered or target_hidden or not _target_alive(): return
	var at := target_player.global_position
	var radius: float = target_player.get_body_radius() if target_player.has_method("get_body_radius") else 13.0
	if action==&"ripple":
		var fraction := WaveGeometry.hit_fraction(locked_origin,previous_target,at,ring_radius(before),ring_radius(after),RING_HALF_WIDTH+radius)
		if fraction>=0 and _point_visible(previous_target.lerp(at,fraction)): _deliver_damage(42)
	elif action==&"pincer":
		_resolve_claw_hit(previous_target,at)
func _spawn_salt() -> void:
	var serial := action_serial
	var origin: Vector2 = boss.get_safe_salt_origin()
	if warning_paths.is_empty() or not origin.is_equal_approx(warning_paths[0]): cancel_action(); attack_gap = 1.1; return
	for angle in [-0.24,0.0,0.24]:
		if serial!=action_serial or state==State.DEATH or not _target_alive() or target_hidden: return
		var shot := SaltShot.new()
		shot.position = projectile_parent.to_local(origin)
		shot.velocity = locked_direction.rotated(angle)*350
		shot.world_bounds = boss.world_bounds
		shot.collision_layer = 0; shot.collision_mask = boss.collision_mask
		projectile_parent.add_child(shot)
		if serial!=action_serial or state==State.DEATH:
			shot.queue_free()
			return
		shot.ignore_source(boss)
		owned_projectiles.append(shot)
func cancel_action(clear_projectiles: bool = true) -> void:
	escape_route.clear()
	action_serial += 1
	action = &""; action_stage = Stage.IDLE; action_elapsed = 0; hit_delivered = false
	previous_claws.clear()
	warning_paths.clear()
	if clear_projectiles:
		for shot in owned_projectiles:
			if is_instance_valid(shot): shot.queue_free()
		owned_projectiles.clear()
	if is_instance_valid(boss):
		boss.velocity = Vector2.ZERO
		_sample_motion() # Explicit cancellation also releases a paused manual pose.
		boss.queue_redraw()
	queue_redraw()
func set_target_hidden(hidden: bool) -> void:
	if target_hidden==hidden: return
	target_hidden = hidden
	if hidden: cancel_action(); attack_gap = maxf(attack_gap,1.1)
func set_health_phase(phase: int) -> void:
	requested_phase = maxi(requested_phase,clampi(phase,1,3))
	if current_phase>0 and requested_phase>current_phase and state in [State.PHASE_1,State.PHASE_2,State.PHASE_3]: _start_transition()
func _start_transition() -> void:
	if state==State.DEATH: return
	cancel_action(); state = State.TRANSITION_1 if current_phase==1 else State.TRANSITION_2; state_elapsed = 0
	reinforcements_requested.emit(2 if current_phase==1 else 3)
	if state!=State.DEATH: combat_cue.emit(&"boss_transition")
func _enter_phase(phase: int) -> void:
	current_phase = phase; state = [State.PHASE_1,State.PHASE_2,State.PHASE_3][phase-1]
	state_elapsed = 0; attack_gap = 0.65; phase_changed.emit(phase)
	if state in [State.PHASE_1,State.PHASE_2,State.PHASE_3] and requested_phase>phase: _start_transition()
func shutdown() -> void:
	if state==State.DEATH: return
	cancel_action(); state = State.DEATH; state_elapsed = 0; combat_cue.emit(&"boss_death")
func _exit_tree() -> void:
	shutdown()
	if is_instance_valid(target_player) and target_player.tree_exiting.is_connected(_target_departed): target_player.tree_exiting.disconnect(_target_departed)
	if is_instance_valid(linked_health) and linked_health.has_signal("died") and linked_health.is_connected("died",_target_departed): linked_health.disconnect("died",_target_departed)
	if is_instance_valid(projectile_parent) and projectile_parent.tree_exiting.is_connected(shutdown): projectile_parent.tree_exiting.disconnect(shutdown)
func _draw() -> void:
	if target_hidden or action_stage not in [Stage.WARNING,Stage.ACTIVE]: return
	var ink := Color("172026"); var coral := Color("f27a4b")
	if action_stage==Stage.WARNING and action==&"salt":
		for index in range(0,warning_paths.size(),2): Escape.draw_path(self,warning_paths[index],warning_paths[index+1],6)
	elif action_stage==Stage.WARNING and action==&"pincer":
		# One outer sweep silhouette per claw, not dozens of overlapping circles.
		for claw in 2:
			var outline := PackedVector2Array()
			for index in range(claw*2,warning_paths.size(),4):
				for point in [warning_paths[index],warning_paths[index+1]]:
					for side in 12: outline.append(to_local(point)+Vector2.from_angle(TAU*side/12)*CLAW_RADIUS)
			if outline.size()<3: continue
			var hull := Geometry2D.convex_hull(outline)
			draw_colored_polygon(hull,Color(coral,0.08)); draw_polyline(hull,ink,4,true); draw_polyline(hull,coral,2,true)
	if action==&"ripple":
		var radius := RING_START if action_stage==Stage.WARNING else ring_radius(action_elapsed)
		if action_stage==Stage.WARNING:
			draw_arc(to_local(locked_origin),RING_END,0,TAU,96,Color(coral,0.55),2,true)
			draw_arc(to_local(locked_origin),RING_START,0,TAU,64,coral,3,true)
			draw_arc(to_local(locked_origin),RING_START+RING_HALF_WIDTH,0,TAU,64,ink,2,true)
		for index in 64:
			var a := locked_origin+Vector2.RIGHT.rotated(TAU*index/64)*radius
			var b := locked_origin+Vector2.RIGHT.rotated(TAU*(index+1)/64)*radius
			if _point_visible(a) and _point_visible(b):
				draw_line(to_local(a),to_local(b),ink,RING_HALF_WIDTH*2+2,true)
				draw_line(to_local(a),to_local(b),coral,2,true)
	elif action==&"pincer" and action_stage==Stage.ACTIVE:
		for point in boss.get_claw_origins():
			if _point_visible(point):
				var at := to_local(point)
				draw_arc(at,CLAW_RADIUS,0,TAU,32,ink,4,true)
				draw_arc(at,CLAW_RADIUS,0,TAU,32,coral,1.5,true)
