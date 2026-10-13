extends "res://scripts/systems/ChapterEncounterDirector.gd"
## Actual archive families and finite Archivist combat; main readiness waits for A5.
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const SporeField = preload("res://scripts/world/ArchiveSporeField.gd")
const Archivist = preload("res://scripts/actors/ArchiveArchivistBoss.gd")
const BROOD_KINDS := [EnemyScript.EnemyKind.SCRAPPER,EnemyScript.EnemyKind.SPITTER,EnemyScript.EnemyKind.SCRAPPER,EnemyScript.EnemyKind.SPITTER,EnemyScript.EnemyKind.SCRAPPER]
const BROOD_VISUAL_SPACING := 76.0 # Native silhouettes + bars, not larger hitboxes.
var spore_field: Node2D
var boss_cleanup_started := false
var reinforcements_committed := 0
var accepted_brood_phases: Array[int] = []
func bind_spore_field(field: Node2D) -> bool:
	if state!=State.IDLE or not is_instance_valid(field) or not field.is_inside_tree() or field.get_script()!=SporeField: return false
	if is_instance_valid(spore_field) and spore_field.tree_exiting.is_connected(_on_spore_departure): spore_field.tree_exiting.disconnect(_on_spore_departure)
	spore_field = field; spore_field.tree_exiting.connect(_on_spore_departure); return true
func _on_spore_departure() -> void: _fail("菌光孢巢所有者离场")
func start_run(seed_value: int,target: PlayerBody,enemies: Node2D,projectiles: Node2D,portals: Node2D,build: BuildSystem,navigation: ArenaLayout) -> bool:
	if not is_instance_valid(spore_field) or not spore_field.is_inside_tree() or spore_field.layout!=navigation: return false
	return super.start_run(seed_value,target,enemies,projectiles,portals,build,navigation)
func _chapter_number() -> int: return 4
func get_attack_targets() -> Array[Node]:
	var targets := super.get_attack_targets()
	if _birth_context_active() and is_instance_valid(spore_field) and spore_field.is_inside_tree() and not spore_field.is_queued_for_deletion():
		for nest in spore_field.get_children():
			if not nest.is_queued_for_deletion() and nest.is_in_group(&"enemies"): targets.append(nest)
	return targets
func _boss_label() -> String: return "藏孢书记 · 页刃 / 菌封 / 有限孢群"
func _boss_available() -> bool: return true
func _create_boss_actor() -> Node: return Archivist.new()
func _boss_position() -> Vector2: return Vector2(0,-672)
func _build_encounters() -> Array[Dictionary]:
	return [
		{"id":&"sealed_shelves","name":"封签书廊","mote":spawn_rng.randi_range(6,8),"planter":spawn_rng.randi_range(3,4),"rate":0.22},
		{"id":&"spore_warren","name":"菌巢侧室","mote":spawn_rng.randi_range(8,11),"planter":spawn_rng.randi_range(5,6),"rate":0.20},
		{"id":&"bloomed_detour","name":"高风险：四室菌息","mote":spawn_rng.randi_range(12,14),"planter":spawn_rng.randi_range(7,8),"rate":0.18},
	]
func _encounter_kinds(encounter: Dictionary) -> Array[int]:
	var kinds: Array[int] = []
	for _count in encounter.mote: kinds.append(EnemyScript.EnemyKind.SCRAPPER)
	for _count in encounter.planter: kinds.append(EnemyScript.EnemyKind.SPITTER)
	return kinds
func _create_enemy_actor(kind: int) -> Node:
	var role: String
	match kind:
		EnemyScript.EnemyKind.SCRAPPER: role = "splitting_mote"
		EnemyScript.EnemyKind.SPITTER: role = "capsule_planter"
		_: return null
	var actor := Factory.create_actor(4,role,encounter_index+4,projectile_parent,player)
	actor.world_bounds = world_bounds; return actor
func _on_run_started() -> void: spore_field.configure(arena_navigation,run_seed,player)
func _on_state_changed(next: State) -> void:
	if is_instance_valid(spore_field): spore_field.set_active(next==State.COMBAT,4 if encounter_index==2 else 2)
	if next==State.FAILED: _cancel_boss_followers()
func _birth_context_active() -> bool:
	return not boss_cleanup_started and super._birth_context_active()
func _on_boss_died(boss: Node,dropped_coins: int,source: StringName) -> void:
	if state!=State.BOSS or boss!=active_boss or boss.health.current_health>0 or not boss.death_resolved: return
	# Cancel this encounter's authority before publishing any victory callback.
	_cancel_boss_followers()
	super._on_boss_died(boss,dropped_coins,source)
func _cancel_boss_followers() -> void:
	if boss_cleanup_started: return
	boss_cleanup_started = true
	if is_instance_valid(active_boss): active_boss.cancel_boss_attacks()
	_cancel_pending_births()
	spawn_queue.clear(); portal_spawn_queues.clear(); portal_spawn_timers.clear()
	var portals_to_cancel := active_portals.duplicate(); active_portals.clear()
	var followers := active_enemies.duplicate(); followers.erase(active_boss)
	# Tree-exiting listeners must see cancellation, not a counterfeit death.
	for follower in followers: active_enemies.erase(follower)
	neighbor_grid.invalidate()
	for node in portals_to_cancel+followers:
		if not is_instance_valid(node): continue
		if node.get_parent()!=null: node.get_parent().remove_child(node)
		node.queue_free()
func _brood_context_valid(owner: Node) -> bool:
	return _birth_context_active() and not get_tree().paused and state==State.BOSS and is_instance_valid(owner) and owner==active_boss and owner.is_inside_tree() and not owner.is_queued_for_deletion() and not owner.death_resolved and not boss_defeat_pending and not boss_defeated_for_wave and owner.get_target_player()==player
func _on_boss_reinforcements_requested(owner: Node,count: int,_count_limit: int = 8) -> void:
	if not _brood_context_valid(owner): return
	var combat = owner.get_attack_director()
	var phase: int = combat.current_phase
	var expected := 2 if phase==2 else 3
	if phase not in [2,3] or phase in accepted_brood_phases or count!=expected or combat.action!=&"brood" or combat.action_stage!=combat.Stage.ACTIVE or phase not in combat.brood_released_phases or reinforcements_committed+count>BROOD_KINDS.size(): return
	# Reserve before add_child / UI callbacks. Cancellation never refunds births.
	accepted_brood_phases.append(phase)
	var first := reinforcements_committed
	reinforcements_committed += count
	var serial: int = combat.action_serial
	var positions := _brood_positions(owner,count)
	if positions.size()!=count: return # No safe full batch: no wall birth or retry debt.
	for index in count:
		if not _brood_context_valid(owner) or combat.action_serial!=serial: return
		var actor = _create_enemy_actor(BROOD_KINDS[first+index])
		actor.set_arena_navigation(arena_navigation)
		actor.position = enemy_parent.to_local(positions[index])
		actor.apply_spawn_impulse(Vector2.ZERO,0.18)
		enemy_parent.add_child(actor)
		# Ready/tree-entered listeners may kill the Boss or remove an owner.
		if not _brood_context_valid(owner) or combat.action_serial!=serial or actor.get_parent()!=enemy_parent or not _register_enemy(actor):
			if actor.get_parent()!=null: actor.get_parent().remove_child(actor)
			actor.queue_free(); return
	_emit_wave_status()
func _brood_positions(owner: CharacterBody2D,count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var origin: Vector2 = owner.get_safe_brood_origin()
	var away: float = (owner.global_position-player.global_position).angle()
	var shape := CircleShape2D.new(); shape.radius = 16
	var query := PhysicsShapeQueryParameters2D.new(); query.shape = shape
	query.collision_mask = owner.collision_mask; query.collide_with_areas = true
	query.exclude = [owner.get_rid(),player.get_rid()]
	var space := owner.get_world_2d().direct_space_state
	for radius in [112.0,144.0,176.0,208.0]:
		for sector in 16:
			var at: Vector2 = origin+Vector2.from_angle(away+TAU*sector/16.0)*radius
			if not world_bounds.grow(-16).has_point(at) or not arena_navigation.is_position_walkable(at,16) or at.distance_to(player.global_position)<100 or _get_enemy_spawn_clearance(at,16)<0: continue
			if at.distance_to(owner.global_position)<120 or points.any(func(p): return p.distance_to(at)<BROOD_VISUAL_SPACING): continue
			if active_enemies.any(func(a): return is_instance_valid(a) and a!=owner and not a.is_queued_for_deletion() and a.global_position.distance_to(at)<BROOD_VISUAL_SPACING): continue
			var ray := PhysicsRayQueryParameters2D.create(origin,at,owner.collision_mask,query.exclude)
			ray.hit_from_inside = true
			if not space.intersect_ray(ray).is_empty(): continue
			query.transform = Transform2D(0,at)
			if not space.intersect_shape(query,1).is_empty(): continue
			points.append(at)
			if points.size()==count: return points
	return []
