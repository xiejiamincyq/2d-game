extends Node2D
## Furnace-only combat authority. Native clips read, never advance this clock.
signal phase_changed(phase: int)
signal reinforcements_requested(count: int)
signal combat_cue(cue: StringName)
enum State { ENTRANCE,PHASE_1,TRANSITION_1,PHASE_2,TRANSITION_2,PHASE_3,DEATH }
enum Stage { IDLE,WARNING,ACTIVE,RECOVERY }
const ENTRANCE_SECONDS := 1.4
const TRANSITION_SECONDS := 0.65
const JET_RANGE := 260.0
const JET_ARC := deg_to_rad(44)
const VENT_RADIUS := 44.0
const RAM_SPEED := 480.0
const DURATIONS := {&"jet":[0.65,0.18,0.55],&"ram":[0.75,0.5,0.70],&"vents":[0.70,0.45,0.60]}
const Escape = preload("res://scripts/components/BossEscapeGate.gd")
var warning_origin := Vector2.ZERO
var escape_route := {}
var boss: CharacterBody2D
var target_player: Node2D
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
var locked_origin := Vector2.ZERO
var locked_direction := Vector2.RIGHT
var locked_target := Vector2.ZERO
var vent_centers: Array[Vector2] = []
var jet_points := PackedVector2Array()
var target_hidden := false
var hit_delivered := false
var blocked := false
var pause_cancelled := false

func configure(actor: CharacterBody2D,target: Node2D,_shots: Node) -> void:
	boss = actor; target_player = target
	show_behind_parent = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(false) # Boss calls advance exactly once per physics tick.
	if is_instance_valid(target):
		target.tree_exiting.connect(_target_departed)
		linked_health = target.get("health")
		if is_instance_valid(linked_health) and linked_health.has_signal("died"):
			linked_health.connect("died",_target_departed)
func get_state_name() -> String: return State.keys()[state]
func is_attacking() -> bool: return action_stage!=Stage.IDLE
func is_movement_locked() -> bool:
	return state in [State.ENTRANCE,State.TRANSITION_1,State.TRANSITION_2,State.DEATH] or is_attacking()
func get_last_attack_class() -> StringName: return &"melee" if action==&"ram" else &"ranged"
func _target_alive() -> bool:
	return is_instance_valid(target_player) and target_player.is_inside_tree() and not target_player.is_queued_for_deletion() and (not target_player.has_method("is_alive") or target_player.is_alive())
func _target_departed() -> void:
	cancel_action(); target_hidden = true; attack_gap = maxf(attack_gap,1.1)
func _process(_delta: float) -> void:
	if get_tree().paused: _cancel_for_pause()
func _cancel_for_pause() -> void:
	if pause_cancelled: return
	pause_cancelled = true
	cancel_action(); attack_gap = maxf(attack_gap,1.1)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0 or state==State.DEATH: return
	if get_tree().paused: _cancel_for_pause(); return
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
	if is_attacking():
		var duration: float = DURATIONS[action][action_stage-1]
		var step := minf(delta,maxf(0,duration-action_elapsed))
		if action_stage==Stage.ACTIVE:
			if action==&"ram": _advance_ram(step)
			else: _resolve_area_hit()
			if action_stage!=Stage.ACTIVE: queue_redraw(); return
		action_elapsed += step
		# One stage transition per call: a stalled frame cannot hide every cue.
		if action_elapsed>=duration-0.000001:
			action_elapsed = 0
			if action_stage==Stage.WARNING:
				action_stage = Stage.ACTIVE
				if action==&"jet":
					if boss.has_method("_update_boss_motion"): boss._update_boss_motion(0)
					locked_origin = boss.get_safe_heat_origin()
					if not locked_origin.is_equal_approx(warning_origin): cancel_action(); attack_gap = 1.1; return
					_clip_jet()
				if action!=&"ram": _resolve_area_hit()
			elif action_stage==Stage.ACTIVE:
				action_stage = Stage.RECOVERY; boss.velocity = Vector2.ZERO
			else:
				cancel_action(); attack_gap = 1.1 if current_phase<3 else 0.9
		queue_redraw(); return
	attack_gap = maxf(0,attack_gap-delta)
	if attack_gap<=0:
		var chosen: StringName = &"jet" if attack_index%2==0 else &"ram"
		if current_phase>=2 and attack_index%3==2: chosen = &"vents"
		if start_action(chosen) or (chosen==&"vents" and start_action(&"jet")): attack_index += 1

func start_action(kind: StringName) -> bool:
	if kind not in DURATIONS or is_attacking() or get_tree().paused or state not in [State.PHASE_1,State.PHASE_2,State.PHASE_3] or target_hidden or not _target_alive() or not is_instance_valid(boss) or boss.death_resolved: return false
	locked_target = target_player.global_position
	locked_origin = boss.get_safe_heat_origin() if kind==&"jet" else boss.global_position
	locked_direction = locked_origin.direction_to(locked_target)
	if locked_direction==Vector2.ZERO: locked_direction = Vector2.RIGHT
	vent_centers.clear(); jet_points.clear()
	if kind==&"vents":
		for index in 3:
			var center := locked_target+locked_direction.orthogonal()*(index-1)*130.0
			if boss.world_bounds.size!=Vector2.ZERO:
				var allowed: Rect2 = boss.world_bounds.grow(-VENT_RADIUS)
				if allowed.size.x<=0 or allowed.size.y<=0: continue
				center = center.clamp(allowed.position,allowed.end-Vector2.ONE*0.001)
			if vent_centers.any(func(prior): return prior.distance_to(center)<VENT_RADIUS*2): continue
			var shape := CircleShape2D.new(); shape.radius = VENT_RADIUS
			var query := PhysicsShapeQueryParameters2D.new(); query.shape = shape
			query.transform = Transform2D(0,center); query.collision_mask = boss.collision_mask
			query.exclude = _excluded_bodies()
			if boss.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): vent_centers.append(center)
		if vent_centers.is_empty(): return false
	action = kind; action_stage = Stage.WARNING; action_elapsed = 0
	hit_delivered = false; blocked = false; boss.velocity = Vector2.ZERO
	if kind==&"jet":
		# Sample the exact release pose, then restore WARNING before any frame.
		action_stage = Stage.ACTIVE; boss._update_boss_motion(0)
		warning_origin = boss.get_safe_heat_origin()
		action_stage = Stage.WARNING; boss._update_boss_motion(0)
		locked_origin = warning_origin; _clip_jet()
	else: warning_origin = locked_origin
	var danger := func(at: Vector2,age: float) -> bool:
		if kind==&"vents":
			for center in vent_centers:
				if at.distance_to(center)<=VENT_RADIUS+_target_radius()+3: return true
			return false
		if kind==&"ram":
			return Escape.segment_danger(at,locked_origin,locked_origin+locked_direction*RAM_SPEED*age,boss.body_radius+_target_radius()+boss.safe_margin+0.5)
		var offset := at-warning_origin
		return offset.length()<=JET_RANGE+_target_radius()+3 and absf(locked_direction.angle_to(offset))<=JET_ARC/2+0.02
	if not Escape.has_route(boss,target_player,DURATIONS[kind][0],DURATIONS[kind][1],boss.world_bounds,danger,escape_route): cancel_action(); attack_gap = 0.2; return false
	combat_cue.emit(&"boss_barrage" if kind==&"jet" else &"boss_tentacle")
	queue_redraw(); return true
func _clip_jet() -> void:
	jet_points.clear()
	for index in 13:
		var end := locked_origin+locked_direction.rotated(-JET_ARC/2+JET_ARC*index/12)*JET_RANGE
		var hit := boss.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(locked_origin,end,boss.collision_mask,_excluded_bodies()))
		jet_points.append(hit.position if not hit.is_empty() else end)
func _excluded_bodies() -> Array[RID]:
	var excluded: Array[RID] = [boss.get_rid()]
	if target_player is CollisionObject2D: excluded.append(target_player.get_rid())
	return excluded
func _target_radius() -> float:
	return target_player.get_body_radius() if target_player.has_method("get_body_radius") else 13.0
func _line_clear(origin: Vector2,target: Vector2) -> bool:
	return boss.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(origin,target,boss.collision_mask,_excluded_bodies())).is_empty()
func _deliver_damage(amount: float) -> void:
	if not hit_delivered and _target_alive() and target_player.has_method("take_damage"):
		hit_delivered = true # Immunity refusal cannot retry the same cast.
		target_player.take_damage(amount,&"furnace_foreman")
func _resolve_area_hit() -> void:
	if hit_delivered or target_hidden or not _target_alive(): return
	var at := target_player.global_position
	if action==&"jet":
		var offset := at-locked_origin
		if offset.length()<=JET_RANGE+_target_radius() and absf(locked_direction.angle_to(offset))<=JET_ARC/2 and _line_clear(locked_origin,at): _deliver_damage(48)
	elif action==&"vents":
		for center in vent_centers:
			if center.distance_to(at)<=VENT_RADIUS+_target_radius() and _line_clear(center,at): _deliver_damage(42); break
func _advance_ram(delta: float) -> void:
	if delta<=0: return
	var start := boss.global_position
	var motion := locked_direction*RAM_SPEED*delta
	var clipped := false
	if boss.world_bounds.size!=Vector2.ZERO:
		var allowed: Rect2 = boss.world_bounds.grow(-boss.body_radius)
		var fraction := 1.0
		for axis in 2:
			if motion[axis]>0: fraction = minf(fraction,(allowed.end[axis]-0.001-start[axis])/motion[axis])
			elif motion[axis]<0: fraction = minf(fraction,(allowed.position[axis]-start[axis])/motion[axis])
		fraction = clampf(fraction,0,1); clipped = fraction<1; motion *= fraction
	boss.velocity = locked_direction*RAM_SPEED
	var collision := boss.move_and_collide(motion)
	var closest := Geometry2D.get_closest_point_to_segment(target_player.global_position,start,boss.global_position)
	if closest.distance_to(target_player.global_position)<=boss.body_radius+_target_radius()+boss.safe_margin+0.5 and _line_clear(closest,target_player.global_position): _deliver_damage(54)
	# Damage may synchronously emit death/cancel/transition. Never write an old
	# collision's recovery over a newer terminal state or replacement action.
	if action!=&"ram" or action_stage!=Stage.ACTIVE or state==State.DEATH: return
	if not _target_alive(): _target_departed(); return
	if collision!=null or clipped:
		blocked = true; action_stage = Stage.RECOVERY; action_elapsed = 0; boss.velocity = Vector2.ZERO
func cancel_action() -> void:
	escape_route.clear()
	action = &""; action_stage = Stage.IDLE; action_elapsed = 0; hit_delivered = false
	vent_centers.clear(); jet_points.clear()
	if is_instance_valid(boss): boss.velocity = Vector2.ZERO; boss.queue_redraw()
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
func _draw() -> void:
	if target_hidden or not is_attacking(): return
	var ink := Color("172026"); var hot := Color("edaa62")
	if action==&"vents" and action_stage in [Stage.WARNING,Stage.ACTIVE]:
		for center in vent_centers:
			var at := to_local(center)
			draw_circle(at,VENT_RADIUS,Color(hot,0.10))
			draw_arc(at,VENT_RADIUS,0,TAU,48,ink,5,true); draw_arc(at,VENT_RADIUS,0,TAU,48,Color("f27a4b"),3,true)
			if action_stage==Stage.WARNING: draw_arc(at,VENT_RADIUS*(1-action_elapsed/DURATIONS[action][0]),0,TAU,40,Color("f3eddc"),2,true)
			if action_stage==Stage.ACTIVE:
				for x in [-14,0,14]:
					var flame := PackedVector2Array([at+Vector2(x-5,9),at+Vector2(x-3,-15),at+Vector2(x+2,-24),at+Vector2(x+5,9)])
					draw_colored_polygon(flame,hot); draw_polyline(flame,ink,2,true)
	elif action==&"jet" and action_stage==Stage.WARNING:
		var boundary := PackedVector2Array([to_local(warning_origin)])
		for point in jet_points: boundary.append(to_local(point))
		boundary.append(to_local(warning_origin))
		draw_colored_polygon(boundary,Color(Color("f27a4b"),0.08))
		draw_polyline(boundary,ink,4,true); draw_polyline(boundary,Color("f27a4b"),2,true)
	elif action==&"ram" and action_stage==Stage.WARNING:
		Escape.draw_path(self,locked_origin,locked_origin+locked_direction*RAM_SPEED*DURATIONS[action][1],boss.body_radius)
	elif action==&"jet" and action_stage==Stage.ACTIVE:
		# Separated ragged heat tongues, not five unbroken laser spokes.
		for index in [1,4,6,8,11]:
			var a := to_local(locked_origin); var b := to_local(jet_points[index])
			var length := a.distance_to(b)
			if length<12: continue
			var direction := a.direction_to(b); var side := direction.orthogonal()
			var end := b-direction*minf(6,length*0.1)
			var wobble := sin(action_elapsed*45+index)*2
			for interval in [[0.03,0.27],[0.34,0.60],[0.70,1.0]]:
				var from := a.lerp(end,interval[0]); var to := a.lerp(end,interval[1])
				var flame := PackedVector2Array([from,from.lerp(to,0.3)+side*3,from.lerp(to,0.65)+side*(4+wobble),to,from.lerp(to,0.55)-side*4,from-side*2,from])
				draw_colored_polygon(flame,hot); draw_polyline(flame,ink,2,true)
	elif action==&"ram" and action_stage==Stage.ACTIVE:
		var trail: Vector2 = -locked_direction*boss.body_radius
		draw_line(trail-locked_direction*22,trail,ink,4,true); draw_line(trail-locked_direction*22,trail,hot,1,true)
