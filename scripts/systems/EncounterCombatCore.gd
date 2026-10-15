extends Node
class_name EncounterCombatCore
## Shared physical combat only. No old wave progression or snapshot entry points.

signal collection_window_started(summary: Dictionary, duration: float)
signal collection_window_changed(remaining: float, duration: float)
signal enemy_killed(enemy: Node, source: StringName, coin_value: int)
signal damage_resolved(
	enemy: Node,
	source: StringName,
	amount: float,
	world_position: Vector2,
	direction: Vector2,
	killed: bool
)
signal boss_spawned(boss: Node, display_name: String, maximum_health: float)
signal boss_health_changed(current: float, maximum: float, phase: int)
signal boss_defeated(boss: Node)
signal boss_cue(cue: StringName)

const CombatView = preload("res://scripts/systems/CombatView.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const EnemyNeighborGridScript = preload("res://scripts/components/EnemyNeighborGrid.gd")
const SpawnPortalScript = preload("res://scripts/world/SpawnPortal.gd")
const PORTAL_MIN_SAFE_DISTANCE := 260.0
const PORTAL_MAX_SAFE_DISTANCE := 520.0
const PORTAL_WORLD_MARGIN := 48.0
const PORTAL_SPAWN_INTERVAL := 0.2
const PORTAL_SPAWN_COUNT := 1
const PORTAL_MIN_SEPARATION := 160.0
const PORTAL_SPAWN_IMPULSE_SPEED := 140.0
const PORTAL_SPAWN_IMPULSE_SECONDS := 0.32
const PORTAL_ENEMY_SPAWN_INNER_RADIUS := 24.0
const PORTAL_ENEMY_SPAWN_OUTER_RADIUS := 104.0
const PORTAL_ENEMY_CLEARANCE := 5.0
const COLLECTION_WINDOW_SECONDS := 3.0
const HEART_DROP_CHANCE := 0.025
const SHIELD_DROP_CHANCE := 0.70

var enemy_parent: Node
var projectile_parent: Node
var portal_parent: Node
var arena_navigation: Node
var player: Node
var spawn_queue: Array[int] = []
var spawn_timer: float = 0.0
var active: bool = true
var world_bounds: Rect2 = Rect2()
var spawn_rng := RandomNumberGenerator.new()
var active_enemies: Array[Node] = []
var neighbor_grid := EnemyNeighborGridScript.new()
var active_portals: Array[Node] = []
var portal_spawn_queues: Dictionary = {}
var portal_spawn_timers: Dictionary = {}
var active_boss: Node
var boss_defeat_pending := false
var boss_defeated_for_wave := false

func setup_combat(target_player: Node,enemies: Node,projectiles: Node,portals: Node,navigation: Node) -> void:
	player=target_player
	enemy_parent=enemies
	projectile_parent=projectiles
	portal_parent=portals if portals!=null else enemies
	arena_navigation=navigation

func _difficulty_index() -> int: return 1
func _spawn_interval() -> float: return 0.2
func _create_boss_actor() -> Node: return null
func _emit_wave_status() -> void: pass # Implemented by the encounter owner.
func _handle_combat_entities_cleared() -> void: pass

func _ready() -> void:
	spawn_rng.randomize()

func _process_spawn_timer(delta: float) -> int:
	spawn_timer -= delta
	var spawned := 0
	var interval := _spawn_interval()
	while spawn_timer <= 0.0 and not spawn_queue.is_empty() and spawned < 8:
		if not _can_spawn_enemy(spawn_queue[0]):
			spawn_timer=0.0 # No deferred catch-up burst after population backpressure.
			break
		_spawn_enemy(spawn_queue.pop_front())
		spawn_timer += interval
		spawned += 1
	if spawned > 0:
		_emit_wave_status()
	return spawned

func _open_portal_attack() -> void:
	# A caller without a dedicated portal layer uses direct-spawn admission.
	if spawn_queue.is_empty() or portal_parent == null or portal_parent == enemy_parent:
		return
	var portal_count := clampi(ceili(float(spawn_queue.size()) / 40.0), 3, 5)
	var queues: Array[Array] = []
	for index in range(portal_count):
		queues.append([])
	for index in range(spawn_queue.size()):
		queues[index % portal_count].append(spawn_queue[index])
	spawn_queue.clear()
	_open_portals_for_queues(queues)

func _open_portals_for_queues(queues: Array[Array]) -> void:
	var occupied_positions: Array[Vector2] = []
	for existing_portal in active_portals:
		if is_instance_valid(existing_portal):
			occupied_positions.append(existing_portal.global_position)
	for index in range(queues.size()):
		if queues[index].is_empty():
			continue
		var portal: Node = SpawnPortalScript.new()
		var portal_position := sample_portal_position_avoiding(player.global_position, spawn_rng, occupied_positions)
		portal_position = resolve_arena_spawn_position(portal_position, 48.0)
		# The script's _process is auto-enabled on ready; the director owns this clock.
		portal.ready.connect(portal.set_process.bind(false), CONNECT_ONE_SHOT)
		var burst_duration := float(queues[index].size()) * PORTAL_SPAWN_INTERVAL
		portal_parent.add_child(portal)
		portal.configure(portal_position, 0.7, burst_duration)
		occupied_positions.append(portal_position)
		active_portals.append(portal)
		var portal_id := portal.get_instance_id()
		portal_spawn_queues[portal_id] = queues[index]
		portal_spawn_timers[portal_id] = 0.0
		portal.closed.connect(_on_portal_closed, CONNECT_ONE_SHOT)
		portal.tree_exiting.connect(_on_portal_tree_exiting.bind(portal, portal_id), CONNECT_ONE_SHOT)
	_emit_wave_status()

func _on_boss_reinforcements_requested(_boss: Node, count: int, count_limit: int = 8) -> void:
	if _boss != active_boss or boss_defeat_pending or boss_defeated_for_wave or count <= 0 or portal_parent == null or not is_instance_valid(player):
		return
	count = mini(count, maxi(0, count_limit))
	var portal_count := clampi(ceili(float(count) / 8.0), 2, 3)
	var queues: Array[Array] = []
	for index in range(portal_count):
		queues.append([])
	var reinforcement_kinds: Array[int] = [
		EnemyScript.EnemyKind.SCRAPPER,
		EnemyScript.EnemyKind.DASHER,
	]
	for index in range(count):
		queues[index % portal_count].append(reinforcement_kinds[index % reinforcement_kinds.size()])
	_open_portals_for_queues(queues)

func _process_portal_attack(delta: float) -> void:
	for portal in active_portals.duplicate():
		if not is_instance_valid(portal):
			active_portals.erase(portal)
			continue
		var portal_id: int = portal.get_instance_id()
		var queue: Array = portal_spawn_queues.get(portal_id, [])
		if portal.state==portal.State.BURST and not queue.is_empty():
			# A chapter may hold births for capacity. A timed portal must never
			# close and discard the still-owned queue while that gate is blocked.
			portal.burst_duration=maxf(portal.burst_duration,portal.state_time+maxf(0,delta)+PORTAL_SPAWN_INTERVAL+0.01)
		var burst_delta: float = _get_portal_burst_overlap(portal, delta)
		var enters_burst: bool = portal.state == portal.State.WARNING and portal.state_time + maxf(0.0, delta) + 0.0001 >= portal.warning_duration
		var timer: float = float(portal_spawn_timers.get(portal_id, 0.0)) - burst_delta
		if burst_delta > 0.0 or enters_burst or portal.state == portal.State.BURST:
			while timer <= 0.0001 and not queue.is_empty():
				if not _can_spawn_enemy(int(queue[0])):
					timer=0.0
					break
				var spawn_age: float = maxf(0.0, -timer)
				_spawn_enemy_at(int(queue.pop_front()), portal.global_position, true, spawn_age)
				timer += PORTAL_SPAWN_INTERVAL
		portal_spawn_queues[portal_id] = queue
		portal_spawn_timers[portal_id] = timer
		if not queue.is_empty():
			var advance_burst: float=maxf(0,delta)-(maxf(0,portal.warning_duration-portal.state_time) if portal.state==portal.State.WARNING else 0.0)
			var burst_time: float=portal.state_time if portal.state==portal.State.BURST else 0.0
			portal.burst_duration=maxf(portal.burst_duration,burst_time+maxf(0,advance_burst)+PORTAL_SPAWN_INTERVAL+0.01)
		portal.advance(delta)
	if active_portals.is_empty() and active_enemies.is_empty() and spawn_queue.is_empty():
		_handle_combat_entities_cleared()
	else:
		_emit_wave_status()

func _apply_combat_scaling(_actor: Node) -> void:
	pass # Chapter policy owns loop scaling, not the shared spawn machinery.

func _spawn_boss_at(position: Vector2) -> Node:
	if is_instance_valid(active_boss) or boss_defeated_for_wave or enemy_parent == null:
		return null
	var boss: Node = _create_boss_actor()
	if boss==null: return null
	boss.world_bounds = world_bounds
	boss.setup(_difficulty_index(), projectile_parent, player as Node2D)
	_apply_combat_scaling(boss)
	if boss.has_method("set_arena_navigation"):
		boss.set_arena_navigation(arena_navigation)
	boss.died.connect(_on_boss_died)
	boss.damage_resolved.connect(_forward_damage_resolved)
	boss.reinforcements_requested.connect(_on_boss_reinforcements_requested)
	boss.combat_cue.connect(func(cue: StringName) -> void: boss_cue.emit(cue))
	boss.tree_exiting.connect(_on_boss_tree_exiting.bind(boss), CONNECT_ONE_SHOT)
	var spawn_bounds := world_bounds.grow(-float(boss.body_radius)) if world_bounds.size != Vector2.ZERO else Rect2()
	var boss_spawn := position.clamp(spawn_bounds.position, spawn_bounds.end - Vector2(0.001, 0.001)) if spawn_bounds.size != Vector2.ZERO else position
	boss_spawn = resolve_arena_spawn_position(boss_spawn, float(boss.body_radius))
	boss.position = enemy_parent.to_local(boss_spawn)
	enemy_parent.add_child(boss)
	boss.velocity = Vector2.ZERO
	active_boss = boss
	active_enemies.append(boss)
	neighbor_grid.invalidate()
	boss.health_changed.connect(_on_boss_health_changed)
	boss_spawned.emit(boss, boss.get_display_name(), float(boss.health.max_health))
	boss_health_changed.emit(float(boss.health.current_health), float(boss.health.max_health), int(boss.get_phase()))
	_emit_wave_status()
	return boss

func _on_boss_health_changed(current: float, maximum: float, phase: int) -> void:
	if not boss_defeat_pending and not boss_defeated_for_wave:
		boss_health_changed.emit(current, maximum, phase)

func _on_boss_died(boss: Node, dropped_coins: int, source: StringName) -> void:
	if boss != active_boss or boss_defeat_pending or boss_defeated_for_wave:
		return
	boss_defeat_pending = true
	_on_enemy_died(boss, dropped_coins, source)

func _on_boss_tree_exiting(boss: Node) -> void:
	active_enemies.erase(boss)
	neighbor_grid.invalidate()
	if boss == active_boss:
		active_boss = null
	if boss_defeat_pending and not boss_defeated_for_wave:
		boss_defeat_pending = false
		boss_defeated_for_wave = true
		boss_defeated.emit(boss)
	_emit_wave_status()
	call_deferred("_handle_combat_entities_cleared")

func _forward_damage_resolved(
	resolved_enemy: Node,
	source: StringName,
	amount: float,
	world_position: Vector2,
	direction: Vector2,
	killed: bool
) -> void:
	damage_resolved.emit(resolved_enemy, source, amount, world_position, direction, killed)

func _spawn_enemy(kind: int) -> void:
	var ranged_kind := kind in [EnemyScript.EnemyKind.SPITTER, EnemyScript.EnemyKind.MARKSMAN, EnemyScript.EnemyKind.LOBBER]
	var position := sample_spitter_spawn_position(player.global_position, get_camera_safe_rect(), spawn_rng) if ranged_kind else sample_spawn_position(player.global_position, 24.0, 430.0, spawn_rng)
	_spawn_enemy_at(kind, position)

func _can_spawn_enemy(_kind: int) -> bool:
	return true

func _create_enemy_actor(kind: int) -> Node:
	var enemy := EnemyScript.new()
	if world_bounds.size != Vector2.ZERO:
		enemy.world_bounds = world_bounds
	enemy.setup(kind, _difficulty_index(), projectile_parent, player as Node2D)
	return enemy

func _spawn_enemy_at(kind: int, position: Vector2, disperse_from_portal: bool = false, spawn_age: float = 0.0) -> void:
	var enemy = _create_enemy_actor(kind)
	enemy.set_arena_navigation(arena_navigation)
	var spawn_bounds := world_bounds.grow(-enemy.body_radius) if world_bounds.size != Vector2.ZERO else Rect2()
	var spawn_position := position
	if disperse_from_portal:
		spawn_position = position
	elif spawn_bounds.size != Vector2.ZERO:
		spawn_position = position.clamp(spawn_bounds.position, spawn_bounds.end - Vector2(0.001, 0.001))
	spawn_position = resolve_arena_spawn_position(spawn_position, enemy.body_radius)
	# CharacterBody2D must enter the physics tree at its final spawn position.
	# Moving it from the parent origin after add_child can resolve a transient
	# overlap against the player and appear to teleport the player to the portal.
	enemy.position = enemy_parent.to_local(spawn_position)
	enemy_parent.add_child(enemy)
	if disperse_from_portal:
		var impulse_direction := Vector2.RIGHT.rotated(spawn_rng.randf() * TAU)
		enemy.apply_spawn_impulse(impulse_direction * PORTAL_SPAWN_IMPULSE_SPEED, PORTAL_SPAWN_IMPULSE_SECONDS, spawn_age)
		enemy._clamp_to_world_bounds()
	else:
		enemy.velocity = Vector2.ZERO
	_register_enemy(enemy)

func _register_enemy(enemy: Node) -> bool:
	# Only live bodies enter the neighbor grid; pending births are chapter debt.
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_queued_for_deletion() or enemy.death_resolved or active_enemies.has(enemy): return false
	active_enemies.append(enemy)
	neighbor_grid.invalidate()
	enemy.set_neighbor_provider(_get_enemy_neighbors.bind(enemy))
	enemy.tree_exiting.connect(_on_enemy_tree_exiting.bind(enemy), CONNECT_ONE_SHOT)
	enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("reinforcements_requested"):
		enemy.reinforcements_requested.connect(_on_boss_reinforcements_requested)
	if enemy.has_signal("damage_resolved"):
		enemy.damage_resolved.connect(func(
			resolved_enemy: Node,
			source: StringName,
			amount: float,
			world_position: Vector2,
			direction: Vector2,
			killed: bool
		) -> void:
			damage_resolved.emit(
				resolved_enemy,
				source,
				amount,
				world_position,
				direction,
				killed
			)
		)
	return true

func _get_portal_burst_overlap(portal: Node, delta: float) -> float:
	var safe_delta := maxf(0.0, delta)
	if portal.state == portal.State.BURST:
		return minf(safe_delta, maxf(0.0, portal.burst_duration - portal.state_time))
	if portal.state != portal.State.WARNING:
		return 0.0
	var warning_remaining := maxf(0.0, portal.warning_duration - portal.state_time)
	return minf(maxf(0.0, safe_delta - warning_remaining), portal.burst_duration)

func sample_clear_portal_enemy_position(portal_position: Vector2, body_radius: float) -> Vector2:
	var spawn_bounds := world_bounds.grow(-body_radius) if world_bounds.size != Vector2.ZERO else Rect2()
	var maximum := spawn_bounds.end - Vector2(0.001, 0.001)
	var fallback := portal_position
	if spawn_bounds.size != Vector2.ZERO:
		fallback = portal_position.clamp(spawn_bounds.position, maximum)
	var best_position := fallback
	var best_clearance := _get_enemy_spawn_clearance(fallback, body_radius)
	var phase := spawn_rng.randf() * TAU
	for ring_index in range(4):
		var ring_fraction := float(ring_index) / 3.0
		var distance := lerpf(
			maxf(PORTAL_ENEMY_SPAWN_INNER_RADIUS, body_radius + PORTAL_ENEMY_CLEARANCE),
			PORTAL_ENEMY_SPAWN_OUTER_RADIUS,
			ring_fraction
		)
		for angle_index in range(16):
			var angle := phase + TAU * float(angle_index) / 16.0
			var candidate := portal_position + Vector2.RIGHT.rotated(angle) * distance
			if spawn_bounds.size != Vector2.ZERO and not spawn_bounds.has_point(candidate):
				continue
			var clearance := _get_enemy_spawn_clearance(candidate, body_radius)
			if clearance >= 0.0:
				return candidate
			if clearance > best_clearance:
				best_clearance = clearance
				best_position = candidate
	return best_position

func resolve_arena_spawn_position(position: Vector2, radius: float) -> Vector2:
	if arena_navigation != null and arena_navigation.has_method("resolve_spawn_position"):
		return arena_navigation.resolve_spawn_position(position, radius)
	return position

func _get_enemy_spawn_clearance(candidate: Vector2, body_radius: float) -> float:
	var clearance := INF
	for other in active_enemies:
		var other_node := other as Node2D
		if other_node == null or not is_instance_valid(other_node) or other_node.is_queued_for_deletion():
			continue
		var other_radius := 14.0
		var radius_value: Variant = other_node.get("body_radius")
		if radius_value != null:
			other_radius = float(radius_value)
		clearance = minf(
			clearance,
			candidate.distance_to(other_node.global_position)
			- body_radius
			- other_radius
			- PORTAL_ENEMY_CLEARANCE
		)
	return clearance

func get_camera_safe_rect(margin: float = EnemyScript.RANGED_SAFE_MARGIN) -> Rect2:
	var viewport := get_viewport()
	var center: Vector2 = player.global_position if player != null else viewport.get_visible_rect().get_center()
	var safe_rect := CombatView.visible_rect(viewport, center).grow(-margin)
	if world_bounds.size != Vector2.ZERO:
		safe_rect = safe_rect.intersection(world_bounds.grow(-24.0))
	return safe_rect

func sample_spitter_spawn_position(
	player_position: Vector2,
	safe_rect: Rect2,
	rng: RandomNumberGenerator
) -> Vector2:
	var allowed_rect := safe_rect
	if world_bounds.size != Vector2.ZERO:
		allowed_rect = allowed_rect.intersection(world_bounds.grow(-24.0))
	if allowed_rect.size.x <= 0.0 or allowed_rect.size.y <= 0.0:
		return sample_spawn_position(player_position, 24.0, 430.0, rng)
	var minimum_distance := EnemyScript.calculate_dynamic_ranged_min_distance(safe_rect)
	var maximum_distance := EnemyScript.calculate_dynamic_ranged_max_distance(safe_rect)
	var maximum := allowed_rect.end - Vector2(0.001, 0.001)
	for attempt in range(128):
		var candidate := Vector2(
			rng.randf_range(allowed_rect.position.x, maximum.x),
			rng.randf_range(allowed_rect.position.y, maximum.y)
		)
		var distance := candidate.distance_to(player_position)
		if distance >= minimum_distance and distance <= maximum_distance:
			return candidate
	for y_step in range(17):
		for x_step in range(17):
			var candidate := Vector2(
				lerpf(allowed_rect.position.x, maximum.x, float(x_step) / 16.0),
				lerpf(allowed_rect.position.y, maximum.y, float(y_step) / 16.0)
			)
			var distance := candidate.distance_to(player_position)
			if distance >= minimum_distance and distance <= maximum_distance:
				return candidate
	# Degenerate camera/world intersections are not expected in the game, but
	# keep the fallback visible and inside world bounds rather than losing it.
	return player_position.clamp(allowed_rect.position, maximum)

func sample_spawn_position(
	player_position: Vector2,
	margin: float,
	minimum_distance: float,
	rng: RandomNumberGenerator
) -> Vector2:
	if world_bounds.size == Vector2.ZERO:
		var angle := rng.randf() * TAU
		return player_position + Vector2.RIGHT.rotated(angle) * minimum_distance
	var playable := world_bounds.grow(-margin)
	var maximum := playable.end - Vector2(0.001, 0.001)
	for attempt in range(32):
		var candidate := Vector2(
			rng.randf_range(playable.position.x, maximum.x),
			rng.randf_range(playable.position.y, maximum.y)
		)
		if candidate.distance_to(player_position) >= minimum_distance:
			return candidate
	var center := playable.get_center()
	var candidates: Array[Vector2] = [
		playable.position,
		Vector2(maximum.x, playable.position.y),
		maximum,
		Vector2(playable.position.x, maximum.y),
		Vector2(center.x, playable.position.y),
		Vector2(maximum.x, center.y),
		Vector2(center.x, maximum.y),
		Vector2(playable.position.x, center.y),
	]
	var farthest := candidates[0]
	var farthest_distance := farthest.distance_squared_to(player_position)
	for candidate_value in candidates.slice(1):
		var candidate: Vector2 = candidate_value
		var distance: float = candidate.distance_squared_to(player_position)
		if distance > farthest_distance:
			farthest = candidate
			farthest_distance = distance
	return farthest

func sample_portal_position(player_position: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var target_distance := get_portal_spawn_distance()
	if world_bounds.size == Vector2.ZERO:
		return player_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * target_distance
	var playable := world_bounds.grow(-PORTAL_WORLD_MARGIN)
	for attempt in range(128):
		var candidate := player_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * target_distance
		if playable.has_point(candidate):
			return candidate
	for step in range(48):
		var angle := TAU * float(step) / 48.0
		var candidate := player_position + Vector2.RIGHT.rotated(angle) * target_distance
		if playable.has_point(candidate):
			return candidate
	var maximum := playable.end - Vector2(0.001, 0.001)
	var corners: Array[Vector2] = [
		playable.position,
		Vector2(maximum.x, playable.position.y),
		maximum,
		Vector2(playable.position.x, maximum.y),
	]
	var farthest := corners[0]
	for candidate in corners.slice(1):
		if candidate.distance_squared_to(player_position) > farthest.distance_squared_to(player_position):
			farthest = candidate
	return farthest

func get_portal_spawn_distance() -> float:
	var viewport := get_viewport()
	if viewport == null and is_inside_tree():
		viewport = get_tree().root
	var visible_size := CombatView.visible_rect(viewport, Vector2.ZERO).size
	return maxf(PORTAL_MIN_SAFE_DISTANCE, minf(visible_size.x, visible_size.y) * 0.5)

func sample_portal_position_avoiding(
	player_position: Vector2,
	rng: RandomNumberGenerator,
	occupied_positions: Array[Vector2]
) -> Vector2:
	for attempt in range(96):
		var candidate := sample_portal_position(player_position, rng)
		var separated := true
		for occupied in occupied_positions:
			if candidate.distance_to(occupied) < PORTAL_MIN_SEPARATION:
				separated = false
				break
		if separated:
			return candidate
	var radius := get_portal_spawn_distance()
	var phase := rng.randf() * TAU
	for step in range(64):
		var candidate := player_position + Vector2.RIGHT.rotated(phase + TAU * float(step) / 64.0) * radius
		var playable := world_bounds.grow(-PORTAL_WORLD_MARGIN)
		if world_bounds.size != Vector2.ZERO and not playable.has_point(candidate):
			continue
		var separated := true
		for occupied in occupied_positions:
			if candidate.distance_to(occupied) < PORTAL_MIN_SEPARATION:
				separated = false
				break
		if separated:
			return candidate
	return sample_portal_position(player_position, rng)

func _on_enemy_died(enemy: Node, coin_value: int, source: StringName) -> void:
	if enemy.get_meta(&"kill_resolved", false):
		return
	enemy.set_meta(&"kill_resolved", true)
	var death_position: Vector2 = enemy.global_position
	var drops := _roll_enemy_drops(enemy)
	var floor_coins := _settle_coin_reward(enemy, coin_value)
	enemy_killed.emit(enemy, source, coin_value)
	call_deferred("_deferred_spawn_drops", death_position, floor_coins, drops.shield_value, drops.heart, drops.shield)
	_emit_wave_status()

func _settle_coin_reward(_enemy: Node, coin_value: int) -> int:
	return coin_value

func _roll_enemy_drops(enemy: Node) -> Dictionary:
	# Default policy keeps the old probabilities AND short-circuit RNG consumption.
	var shield_value: float = enemy.shield_drop_value
	var heart := should_drop_heart(spawn_rng.randf())
	var shield := shield_value > 0.0 and should_drop_shield(spawn_rng.randf())
	return {"heart": heart, "shield": shield, "shield_value": shield_value}

static func should_drop_heart(roll: float) -> bool:
	return roll >= 0.0 and roll < HEART_DROP_CHANCE

static func should_drop_shield(roll: float) -> bool:
	return roll >= 0.0 and roll < SHIELD_DROP_CHANCE

func _deferred_spawn_drops(position: Vector2, coin_value: int, shield_value: float, drops_heart: bool = false, drops_shield: bool = false) -> void:
	var owner := get_parent()
	if not is_instance_valid(owner):
		return
	if coin_value > 0 and owner.has_method("spawn_coins"):
		owner.spawn_coins(position, coin_value)
	if drops_shield and shield_value > 0.0 and owner.has_method("spawn_shield"):
		owner.spawn_shield(position, shield_value)
	if drops_heart and owner.has_method("spawn_heart"):
		owner.spawn_heart(position, 20.0)

func _on_enemy_tree_exiting(enemy: Node) -> void:
	active_enemies.erase(enemy)
	neighbor_grid.invalidate()

func _on_portal_closed(portal: Node) -> void:
	_release_portal_state(portal, portal.get_instance_id())
	portal.queue_free()

func _on_portal_tree_exiting(portal: Node, portal_id: int) -> void:
	_release_portal_state(portal, portal_id)

func _release_portal_state(portal: Node, portal_id: int) -> void:
	portal_spawn_queues.erase(portal_id)
	portal_spawn_timers.erase(portal_id)
	active_portals.erase(portal)

func get_active_enemies() -> Array[Node]:
	return active_enemies

func _get_enemy_neighbors(enemy: Node2D) -> Array[Node]:
	neighbor_grid.refresh(active_enemies, Engine.get_physics_frames())
	return neighbor_grid.neighbors(enemy)

func get_active_boss() -> Node:
	return active_boss if is_instance_valid(active_boss) else null

func get_active_portal_count() -> int:
	return active_portals.size()
