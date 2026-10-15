extends Node2D
## First-chapter combat authority. Native animation only reads this state.
signal phase_changed(phase: int)
signal reinforcements_requested(count: int)
signal combat_cue(cue: StringName)
const Seed = preload("res://scripts/components/VineSeedProjectile.gd")
const ENTRANCE_SECONDS := 1.4
const TRANSITION_SECONDS := 0.65
const LASH_RANGE := 210.0
const LASH_ARC := PI/3
const ROOT_RADIUS := 42.0
const ROOT_SPACING := 126.0
const ROOT_STAGGER := 0.12
const ROOT_ACTIVE_SECONDS := 0.18
enum State { ENTRANCE,PHASE_1,TRANSITION_1,PHASE_2,TRANSITION_2,PHASE_3,DEATH }
enum Stage { IDLE,WARNING,ACTIVE,RECOVERY }
const DURATIONS := {&"lash":[0.65,0.14,0.55],&"roots":[0.80,0.42,0.50],&"seeds":[0.40,0.12,0.65]}
const Escape = preload("res://scripts/components/BossEscapeGate.gd")
var boss: CharacterBody2D
var target_player: Node2D
var projectile_parent: Node
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
var locked_target := Vector2.ZERO
var root_centers: Array[Vector2] = []
var lash_points := PackedVector2Array()
var target_hidden := false
var hit_delivered := false
var owned_seeds: Array[Node] = []
var seed_warning_paths: Array[Vector2] = []
var escape_route := {}

func configure(actor: CharacterBody2D,target: Node2D,shots: Node) -> void:
	boss = actor
	target_player = target
	projectile_parent = shots
	show_behind_parent = true
	set_process(false)
	set_physics_process(false)

func get_state_name() -> String: return State.keys()[state]
func is_attacking() -> bool: return action_stage!=Stage.IDLE
func is_movement_locked() -> bool:
	return state in [State.ENTRANCE,State.TRANSITION_1,State.TRANSITION_2,State.DEATH] or is_attacking()
func get_last_attack_class() -> StringName:
	return &"ranged" if action==&"seeds" else &"melee"

func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0 or state==State.DEATH: return
	if not is_instance_valid(boss) or boss.death_resolved:
		shutdown()
		return
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
		var serial := action_serial
		if action==&"roots":
			var before: float = action_elapsed
			if action_stage>=Stage.ACTIVE: before += DURATIONS[&"roots"][0]
			if action_stage==Stage.RECOVERY: before += DURATIONS[&"roots"][1]
			_resolve_root_interval(before,before+delta)
			# Damage callbacks may synchronously cancel or shut down this action.
			if serial!=action_serial or not is_attacking() or state==State.DEATH: return
		action_elapsed += delta
		while is_attacking() and action_elapsed>=DURATIONS[action][action_stage-1]:
			action_elapsed -= DURATIONS[action][action_stage-1]
			if action_stage==Stage.WARNING:
				action_stage = Stage.ACTIVE
				if action==&"seeds": _release_seeds()
				else: _resolve_hit(0.0)
				if serial!=action_serial or state==State.DEATH: return
			elif action_stage==Stage.ACTIVE:
				action_stage = Stage.RECOVERY
			else:
				cancel_action()
				attack_gap = 1.1 if current_phase<3 else 0.9
		if action_stage==Stage.ACTIVE: _resolve_hit()
		if serial!=action_serial or state==State.DEATH: return
		queue_redraw()
		return
	attack_gap = maxf(0,attack_gap-delta)
	if attack_gap<=0 and is_instance_valid(target_player):
		var distance := boss.global_position.distance_to(target_player.global_position)
		var chosen: StringName = &"lash" if distance<240 else &"seeds"
		if current_phase>=2 and attack_index%2==1: chosen = &"roots"
		if start_action(chosen) or (chosen==&"roots" and start_action(&"seeds")):
			attack_index += 1

func start_action(kind: StringName) -> bool:
	if kind not in DURATIONS or is_attacking() or state not in [State.PHASE_1,State.PHASE_2,State.PHASE_3] or target_hidden or not is_instance_valid(target_player) or boss.death_resolved: return false
	owned_seeds = owned_seeds.filter(func(shot): return is_instance_valid(shot) and not shot.is_queued_for_deletion())
	if not owned_seeds.is_empty(): attack_gap = 0.2; return false
	escape_route.clear()
	locked_origin = boss.global_position
	locked_target = target_player.global_position
	locked_direction = locked_origin.direction_to(locked_target)
	if locked_direction==Vector2.ZERO: locked_direction = Vector2.RIGHT
	root_centers.clear()
	if kind==&"lash":
		var danger := func(at: Vector2,_age: float) -> bool:
			var offset := at-locked_origin
			return offset.length()<=LASH_RANGE+3 and absf(locked_direction.angle_to(offset))<=LASH_ARC/2+0.02
		if not Escape.has_route(boss,target_player,DURATIONS[kind][0],DURATIONS[kind][1],boss.world_bounds,danger,escape_route): return false
	if kind==&"roots":
		for index in 3:
			var center := locked_target+locked_direction.orthogonal()*(index-1)*ROOT_SPACING
			if boss.world_bounds.size!=Vector2.ZERO:
				var allowed: Rect2 = boss.world_bounds.grow(-ROOT_RADIUS)
				if allowed.size.x<=0 or allowed.size.y<=0: continue
				center = center.clamp(allowed.position,allowed.end-Vector2.ONE*0.001)
			var overlaps := false
			for prior in root_centers:
				if prior.distance_to(center)<ROOT_RADIUS*2:
					overlaps = true
					break
			if overlaps: continue
			var shape := CircleShape2D.new()
			shape.radius = ROOT_RADIUS
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.transform = Transform2D(0,center)
			query.collision_mask = boss.collision_mask
			query.exclude = _excluded_bodies()
			if boss.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): root_centers.append(center)
		if root_centers.is_empty(): return false
		root_centers.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_squared_to(locked_target)<b.distance_squared_to(locked_target))
		if not _has_root_escape():
			root_centers.clear()
			return false
	action = kind
	action_stage = Stage.WARNING
	action_elapsed = 0
	action_serial += 1
	hit_delivered = false
	seed_warning_paths.clear()
	if kind==&"seeds":
		action_stage = Stage.ACTIVE
		var origin: Vector2 = boss.get_seed_release_origin()
		action_stage = Stage.WARNING; boss._update_boss_motion(0)
		var count := 5 if current_phase==3 else 3
		for index in count:
			seed_warning_paths.append(origin)
			seed_warning_paths.append(origin+origin.direction_to(locked_target).rotated(deg_to_rad((index-(count-1)/2.0)*18))*300*2.0)
		var radius: float = target_player.get_body_radius() if target_player.has_method("get_body_radius") else 17.0
		var danger := func(at: Vector2,age: float) -> bool:
			for index in range(0,seed_warning_paths.size(),2):
				if at.distance_to(seed_warning_paths[index].lerp(seed_warning_paths[index+1],age/2.0))<=6+radius+3: return true
			return false
		if not Escape.has_route(boss,target_player,DURATIONS[kind][0],2.0,boss.world_bounds,danger,escape_route): cancel_action(); attack_gap = 0.2; return false
	lash_points.clear()
	if kind==&"lash":
		for index in 17:
			var endpoint := locked_origin+locked_direction.rotated(-LASH_ARC/2+LASH_ARC*index/16)*LASH_RANGE
			var ray := PhysicsRayQueryParameters2D.create(locked_origin,endpoint,boss.collision_mask,_excluded_bodies())
			var hit := boss.get_world_2d().direct_space_state.intersect_ray(ray)
			lash_points.append(hit.position if not hit.is_empty() else endpoint)
	combat_cue.emit(&"boss_barrage" if kind==&"seeds" else &"boss_tentacle")
	queue_redraw()
	return true

func _excluded_bodies() -> Array[RID]:
	var excluded: Array[RID] = [boss.get_rid()]
	if target_player is CollisionObject2D: excluded.append(target_player.get_rid())
	return excluded

func get_root_stage(index: int) -> Stage:
	if index<0 or index>=root_centers.size() or action!=&"roots": return Stage.IDLE
	if action_stage!=Stage.ACTIVE: return action_stage
	var local_time := action_elapsed-index*ROOT_STAGGER
	if local_time<0: return Stage.WARNING
	return Stage.ACTIVE if local_time<ROOT_ACTIVE_SECONDS else Stage.RECOVERY

func get_root_warning_fraction(index: int) -> float:
	var elapsed := action_elapsed if action_stage==Stage.WARNING else DURATIONS[&"roots"][0]+action_elapsed
	return clampf(elapsed/(DURATIONS[&"roots"][0]+index*ROOT_STAGGER),0,1)

func _has_root_escape() -> bool:
	var radius: float = target_player.get_body_radius() if target_player.has_method("get_body_radius") else 17.0
	var danger := func(at: Vector2,age: float) -> bool:
		for index in root_centers.size():
			var local_time := age-index*ROOT_STAGGER
			if local_time>=0 and local_time<=ROOT_ACTIVE_SECONDS and at.distance_to(root_centers[index])<=ROOT_RADIUS+radius+3: return true
		return false
	return Escape.has_route(boss,target_player,DURATIONS[&"roots"][0],DURATIONS[&"roots"][1],boss.world_bounds,danger,escape_route)

func _resolve_root_interval(from: float,to: float) -> void:
	# Resolve every crossed active window, even if a frame skips a whole side root.
	var serial := action_serial
	for index in root_centers.size():
		var start: float = DURATIONS[&"roots"][0]+index*ROOT_STAGGER
		if to>=start and from<start+ROOT_ACTIVE_SECONDS:
			_resolve_hit(index*ROOT_STAGGER,index)
			if serial!=action_serial or hit_delivered or action!=&"roots" or state==State.DEATH: return

func _resolve_hit(root_time: float = -1.0,only_root: int = -1) -> void:
	if hit_delivered or action==&"seeds" or target_hidden or not is_instance_valid(target_player): return
	var target_at := target_player.global_position
	var origin := locked_origin
	var hits := false
	if action==&"lash":
		var offset := target_at-locked_origin
		hits = offset.length()<=LASH_RANGE and absf(locked_direction.angle_to(offset))<=LASH_ARC/2
	else:
		for index in root_centers.size():
			if only_root>=0 and index!=only_root: continue
			var at_time := action_elapsed if root_time<0 else root_time
			var local_time := at_time-index*ROOT_STAGGER
			if local_time<0 or local_time>=ROOT_ACTIVE_SECONDS: continue
			var center := root_centers[index]
			if center.distance_to(target_at)<=ROOT_RADIUS:
				origin = center
				hits = true
				break
	if not hits: return
	var ray := PhysicsRayQueryParameters2D.create(origin,target_at,boss.collision_mask,_excluded_bodies())
	if not boss.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return
	if target_player.has_method("take_damage"):
		hit_delivered = true
		target_player.take_damage(54.0 if action==&"lash" else 60.0)

func _release_seeds() -> void:
	if target_hidden or state==State.DEATH or not is_instance_valid(projectile_parent): return
	var serial := action_serial
	var origin: Vector2 = boss.get_seed_release_origin()
	if seed_warning_paths.is_empty() or not origin.is_equal_approx(seed_warning_paths[0]): cancel_action(); attack_gap = 1.1; return
	var count := 5 if current_phase==3 else 3
	owned_seeds = owned_seeds.filter(func(shot): return is_instance_valid(shot) and not shot.is_queued_for_deletion())
	for index in count:
		if serial!=action_serial or state==State.DEATH or boss.death_resolved: return
		var shot := Seed.new()
		shot.source_actor_id = boss.get_instance_id()
		projectile_parent.add_child(shot)
		if serial!=action_serial or state==State.DEATH or boss.death_resolved:
			if is_instance_valid(shot): shot.set_physics_process(false); shot.queue_free()
			return
		shot.global_position = origin
		shot.velocity = origin.direction_to(locked_target).rotated(deg_to_rad((index-(count-1)/2.0)*18))*300
		shot.world_bounds = boss.world_bounds
		shot.ignore_source(boss)
		owned_seeds.append(shot)

func cancel_action() -> void:
	action_serial += 1
	escape_route.clear()
	action_stage = Stage.IDLE
	action = &""
	action_elapsed = 0
	hit_delivered = false
	root_centers.clear()
	lash_points.clear()
	seed_warning_paths.clear()
	queue_redraw()
func _clear_seeds() -> void:
	for shot in owned_seeds:
		if is_instance_valid(shot):
			shot.set_physics_process(false)
			shot.queue_free()
	owned_seeds.clear()
func set_target_hidden(hidden: bool) -> void:
	if target_hidden==hidden: return
	target_hidden = hidden
	if hidden:
		cancel_action()
		_clear_seeds()
		attack_gap = maxf(attack_gap,1.1)
func set_health_phase(phase: int) -> void:
	requested_phase = maxi(requested_phase,clampi(phase,1,3))
	if current_phase>0 and requested_phase>current_phase and state in [State.PHASE_1,State.PHASE_2,State.PHASE_3]: _start_transition()
func _start_transition() -> void:
	if state==State.DEATH: return
	cancel_action()
	_clear_seeds()
	state = State.TRANSITION_1 if current_phase==1 else State.TRANSITION_2
	state_elapsed = 0
	reinforcements_requested.emit(6 if current_phase==1 else 8)
	if state!=State.DEATH: combat_cue.emit(&"boss_transition")
func _enter_phase(phase: int) -> void:
	current_phase = phase
	state = [State.PHASE_1,State.PHASE_2,State.PHASE_3][phase-1]
	state_elapsed = 0
	attack_gap = 0.65
	phase_changed.emit(phase)
	if state in [State.PHASE_1,State.PHASE_2,State.PHASE_3] and requested_phase>phase: _start_transition()
func shutdown() -> void:
	if state==State.DEATH: return
	cancel_action()
	_clear_seeds()
	state = State.DEATH
	state_elapsed = 0
	combat_cue.emit(&"boss_death")
func _exit_tree() -> void: shutdown()

func _draw() -> void:
	if target_hidden or not is_attacking(): return
	if action==&"roots" and action_stage in [Stage.WARNING,Stage.ACTIVE]:
		for index in root_centers.size():
			var stage := get_root_stage(index)
			if stage==Stage.RECOVERY: continue
			var at := to_local(root_centers[index])
			draw_circle(at,ROOT_RADIUS,Color(Color("f27a4b"),0.14))
			draw_arc(at,ROOT_RADIUS,0,TAU,48,Color("171f25"),5,true)
			draw_arc(at,ROOT_RADIUS,0,TAU,48,Color("f27a4b"),3,true)
			if stage==Stage.WARNING:
				var countdown := ROOT_RADIUS*(1.0-get_root_warning_fraction(index))
				if countdown>1: draw_arc(at,countdown,0,TAU,40,Color("f3eddc"),2,true)
			if stage==Stage.ACTIVE:
				for offset in [-16,0,16]:
					var spike := PackedVector2Array([at+Vector2(offset-5,8),at+Vector2(offset,-22),at+Vector2(offset+5,8)])
					draw_colored_polygon(spike,Color("91b47d"))
					draw_polyline(spike+PackedVector2Array([spike[0]]),Color("171f25"),2)
	elif action==&"lash" and action_stage==Stage.WARNING:
		var points := PackedVector2Array([to_local(locked_origin)])
		for index in range(25): points.append(to_local(locked_origin+locked_direction.rotated(-LASH_ARC/2+LASH_ARC*index/24)*LASH_RANGE))
		points.append(to_local(locked_origin))
		draw_colored_polygon(points,Color(Color("f27a4b"),0.08))
		draw_polyline(points,Color("172026"),4,true); draw_polyline(points,Color("f27a4b"),2,true)
	elif action==&"seeds" and action_stage==Stage.WARNING:
		for index in range(0,seed_warning_paths.size(),2): Escape.draw_path(self,seed_warning_paths[index],seed_warning_paths[index+1],6)
	elif action==&"lash" and action_stage==Stage.ACTIVE:
		var points := PackedVector2Array()
		for point in lash_points: points.append(to_local(point))
		draw_polyline(points,Color("171f25"),3)
		draw_polyline(points,Color("91b47d"),1)
