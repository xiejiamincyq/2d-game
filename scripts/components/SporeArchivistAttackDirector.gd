extends Node2D
## Archivist-only authority. Reinforcement births belong to the chapter director.
signal phase_changed(phase: int)
signal combat_cue(cue: StringName)
signal reinforcements_requested(count: int)
enum State { ENTRANCE,PHASE_1,TRANSITION_1,PHASE_2,TRANSITION_2,PHASE_3,DEATH }
enum Stage { IDLE,WARNING,ACTIVE,RECOVERY }
const ENTRANCE_SECONDS := 1.4
const TRANSITION_SECONDS := 0.65
const DURATIONS := {&"page":[0.35,0.40,0.52],&"seal":[0.50,0.28,0.64],&"brood":[0.35,0.36,0.70]}
const Escape = preload("res://scripts/components/BossEscapeGate.gd")
const MAX_ATTACK_STEP := 1.0/15.0
const MAX_PAGES := 2
const Page = preload("res://scripts/components/ArchivePageProjectile.gd")
const Seal = preload("res://scripts/components/ArchiveSealAttack.gd")
var seal_attack: RefCounted = Seal.new()
var previous_target := Vector2.ZERO
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
var owned_projectiles: Array[Node2D] = []
var target_hidden := false
var pause_cancelled := false
var brood_released_phases: Array[int] = []
var next_primary: StringName = &"page"
var escape_route := {}
func configure(actor: CharacterBody2D,target: Node2D,shots: Node2D) -> void:
	boss = actor; target_player = target; projectile_parent = shots
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_as_relative = false; z_index = -1; show_behind_parent = true
	if is_instance_valid(target):
		target.tree_exiting.connect(_target_departed)
		linked_health = target.get("health")
		if is_instance_valid(linked_health) and linked_health.has_signal("died"): linked_health.connect("died",_target_departed)
	if is_instance_valid(shots): shots.tree_exiting.connect(shutdown)
func get_state_name() -> String: return State.keys()[state]
func is_attacking() -> bool: return action_stage!=Stage.IDLE
func is_movement_locked() -> bool: return state in [State.ENTRANCE,State.TRANSITION_1,State.TRANSITION_2,State.DEATH] or is_attacking()
func get_last_attack_class() -> StringName: return &"ranged"
func _target_alive() -> bool:
	return is_instance_valid(target_player) and target_player.is_inside_tree() and not target_player.is_queued_for_deletion() and is_instance_valid(linked_health) and linked_health.current_health>0
func _owners_available() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(boss) and boss.is_inside_tree() and not boss.is_queued_for_deletion() and not boss.death_resolved and is_instance_valid(projectile_parent) and projectile_parent.is_inside_tree() and not projectile_parent.is_queued_for_deletion()
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
		if attack_gap<=0: _start_automatic_action()
		return # A hitch cannot skip an entire visible warning.
	var serial := action_serial
	if delta>MAX_ATTACK_STEP: cancel_action(); attack_gap = maxf(attack_gap,1.1); return
	if action==&"seal" and action_stage==Stage.ACTIVE:
		seal_attack.resolve_hit(previous_target,target_player.global_position)
		if serial!=action_serial or state==State.DEATH: return
	previous_target = target_player.global_position
	var duration: float = DURATIONS[action][action_stage-1]
	action_elapsed = minf(duration,action_elapsed+delta)
	_sample_motion()
	if serial!=action_serial or state==State.DEATH: return
	if action_elapsed>=duration-0.000001:
		action_elapsed = 0
		if action_stage==Stage.WARNING:
			action_stage = Stage.ACTIVE; _sample_motion()
			if action==&"page": _release_page(serial)
			elif action==&"seal": seal_attack.resolve_hit(previous_target,previous_target)
			elif action==&"brood": _release_brood(serial)
		elif action_stage==Stage.ACTIVE:
			action_stage = Stage.RECOVERY; seal_attack.cancel(); _sample_motion()
		else:
			cancel_action(false); attack_gap = 1.1 if current_phase<3 else 0.9
	queue_redraw()
func _start_automatic_action() -> void:
	if current_phase>=2 and current_phase not in brood_released_phases:
		start_action(&"brood")
		return
	var requested := next_primary
	if start_action(requested):
		next_primary = &"seal" if requested==&"page" else &"page"
	elif requested==&"seal":
		# A terrain-blocked footprint cannot stall the boss or skip a warning.
		start_action(&"page")
func start_action(kind: StringName) -> bool:
	if kind not in DURATIONS or state not in [State.PHASE_1,State.PHASE_2,State.PHASE_3] or is_attacking() or get_tree().paused or target_hidden or not _target_alive() or not _owners_available(): return false
	if kind==&"brood" and (current_phase<2 or current_phase in brood_released_phases): return false
	owned_projectiles = owned_projectiles.filter(func(page): return is_instance_valid(page) and not page.is_queued_for_deletion())
	if not owned_projectiles.is_empty(): return false
	escape_route.clear()
	if kind==&"page" and owned_projectiles.size()>=MAX_PAGES: return false
	boss._update_visual_facing(target_player.global_position)
	locked_origin = boss.get_safe_page_origin() if kind==&"page" else boss.global_position
	locked_direction = locked_origin.direction_to(target_player.global_position)
	if locked_direction==Vector2.ZERO: locked_direction = Vector2.RIGHT
	if kind==&"seal" and not seal_attack.arm(boss,target_player,locked_direction): return false
	if kind==&"seal":
		var danger := func(at: Vector2,_age: float) -> bool:
			for center in seal_attack.centers:
				if at.distance_to(center)<=Seal.RADIUS+target_player.get_body_radius()+3: return true
			return false
		if not Escape.has_route(boss,target_player,DURATIONS[kind][0],DURATIONS[kind][1],boss.world_bounds,danger,escape_route): seal_attack.cancel(); return false
	previous_target = target_player.global_position
	action = kind; action_stage = Stage.WARNING; action_elapsed = 0; action_serial += 1
	boss.velocity = Vector2.ZERO; _sample_motion()
	if kind==&"page":
		action_stage = Stage.ACTIVE; _sample_motion()
		locked_origin = boss.get_safe_page_origin()
		action_stage = Stage.WARNING; _sample_motion()
		var danger := func(at: Vector2,age: float) -> bool:
			return at.distance_to(locked_origin+locked_direction*420*age)<=5+target_player.get_body_radius()+3
		if not Escape.has_route(boss,target_player,DURATIONS[kind][0],1.35,boss.world_bounds,danger,escape_route): cancel_action(); return false
	combat_cue.emit(&"boss_barrage")
	queue_redraw()
	return true
func _release_page(serial: int) -> void:
	if serial!=action_serial or state==State.DEATH or target_hidden or not _target_alive() or not _owners_available(): return
	if not boss.get_safe_page_origin().is_equal_approx(locked_origin): cancel_action(); attack_gap = 1.1; return
	var page := Page.new()
	page.position = projectile_parent.to_local(boss.get_safe_page_origin())
	page.velocity = locked_direction*420; page.world_bounds = boss.world_bounds
	page.collision_layer = 0; page.collision_mask = boss.collision_mask
	projectile_parent.add_child(page)
	# add_child signals may synchronously kill/cancel an owner. Never append late.
	if serial!=action_serial or state==State.DEATH or not _owners_available() or not _target_alive(): page.cancel(); return
	page.ignore_source(boss); owned_projectiles.append(page)
func _release_brood(serial: int) -> void:
	if serial!=action_serial or state==State.DEATH or target_hidden or not _target_alive() or not _owners_available() or current_phase in brood_released_phases: return
	brood_released_phases.append(current_phase) # Reserve before synchronous callbacks.
	reinforcements_requested.emit(2 if current_phase==2 else 3)
func cancel_action(clear_projectiles: bool = true) -> void:
	escape_route.clear()
	action_serial += 1; action = &""; action_stage = Stage.IDLE; action_elapsed = 0
	seal_attack.cancel(); queue_redraw()
	if clear_projectiles:
		for page in owned_projectiles:
			if is_instance_valid(page): page.cancel()
		owned_projectiles.clear()
	if is_instance_valid(boss): boss.velocity = Vector2.ZERO
	_sample_motion()
func _draw() -> void:
	if action==&"page" and action_stage==Stage.WARNING and _owners_available() and _target_alive() and not target_hidden:
		Escape.draw_path(self,locked_origin,locked_origin+locked_direction*420*1.35,5)
	if action==&"seal" and action_stage in [Stage.WARNING,Stage.ACTIVE] and _owners_available() and _target_alive() and not target_hidden:
		seal_attack.draw_visual(self,action_stage==Stage.ACTIVE,action_elapsed/DURATIONS[&"seal"][0])
func set_target_hidden(value: bool) -> void:
	if value==target_hidden: return
	target_hidden = value
	if value: cancel_action(); attack_gap = maxf(attack_gap,1.1)
func set_health_phase(phase: int) -> void:
	requested_phase = maxi(requested_phase,clampi(phase,1,3))
	if current_phase>0 and requested_phase>current_phase and state in [State.PHASE_1,State.PHASE_2,State.PHASE_3]: _begin_transition()
func _begin_transition() -> void:
	if state==State.DEATH: return
	cancel_action(); state = State.TRANSITION_1 if current_phase==1 else State.TRANSITION_2; state_elapsed = 0
	combat_cue.emit(&"boss_transition")
func _enter_phase(phase: int) -> void:
	current_phase = phase; state = [State.PHASE_1,State.PHASE_2,State.PHASE_3][phase-1]
	next_primary = &"page"
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
