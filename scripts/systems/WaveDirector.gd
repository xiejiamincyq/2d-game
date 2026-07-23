extends Node
class_name WaveDirector

signal wave_changed(index: int, total: int, remaining: int)
signal wave_cleared(completed_wave: int)
signal wave_prepared(summary: Dictionary)
signal wave_finished(summary: Dictionary)
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
signal victory

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const OverseerBossScript = preload("res://scripts/actors/OverseerBoss.gd")
const SpawnPortalScript = preload("res://scripts/world/SpawnPortal.gd")

const PORTAL_MIN_SAFE_DISTANCE := 260.0
const PORTAL_MAX_SAFE_DISTANCE := 520.0
const PORTAL_WORLD_MARGIN := 48.0
const PORTAL_SPAWN_INTERVAL := 0.1
const PORTAL_SPAWN_COUNT := 2
const PORTAL_ENEMY_SPAWN_INNER_RADIUS := 24.0
const PORTAL_ENEMY_SPAWN_OUTER_RADIUS := 104.0
const PORTAL_ENEMY_CLEARANCE := 5.0
const BOSS_PORTAL_WARNING_SECONDS := 1.1
const BOSS_PORTAL_BURST_SECONDS := 0.65
const BOSS_PORTAL_SCALE := 1.8

var enemy_parent: Node
var projectile_parent: Node
var portal_parent: Node
var player: Node
var wave_index: int = -1
var spawn_queue: Array[int] = []
var spawn_timer: float = 0.0
var intermission: float = 1.2
var active: bool = true
var waiting_for_advance: bool = false
var prepared_wave: bool = false
var wave_running: bool = false
var world_bounds: Rect2 = Rect2()
var spawn_rng := RandomNumberGenerator.new()
var active_enemies: Array[Node] = []
var active_portals: Array[Node] = []
var portal_spawn_queues: Dictionary = {}
var portal_spawn_timers: Dictionary = {}
var active_boss: Node
var boss_portal: Node
var boss_entrance_started := false
var boss_defeat_pending := false
var boss_defeated_for_wave := false

var waves: Array[Dictionary] = [
	{"scrapper": 54, "dasher": 12, "spitter": 4, "bruiser": 0, "marksman": 0, "lobber": 0, "overseer": 0, "rate": 0.13},
	{"scrapper": 66, "dasher": 18, "spitter": 8, "bruiser": 2, "marksman": 4, "lobber": 0, "overseer": 0, "rate": 0.105},
	{"scrapper": 76, "dasher": 26, "spitter": 12, "bruiser": 3, "marksman": 7, "lobber": 4, "overseer": 0, "rate": 0.085},
	{"scrapper": 94, "dasher": 34, "spitter": 15, "bruiser": 5, "marksman": 10, "lobber": 8, "overseer": 0, "rate": 0.07},
	{"scrapper": 104, "dasher": 38, "spitter": 16, "bruiser": 6, "marksman": 12, "lobber": 10, "overseer": 0, "rate": 0.055},
]

func _ready() -> void:
	spawn_rng.randomize()

func setup(target_player: Node, enemies: Node, projectiles: Node, portals: Node = null, prepare_initial: bool = true) -> void:
	player = target_player
	enemy_parent = enemies
	projectile_parent = projectiles
	portal_parent = portals if portals != null else enemies
	if prepare_initial:
		prepare_next_wave()

func restore_stable_boundary(pending_stage: int, boundary: String) -> bool:
	if pending_stage < 1 or pending_stage > waves.size() or boundary not in ["wave_intro", "settlement"]:
		return false
	spawn_queue.clear()
	active_enemies.clear()
	active_portals.clear()
	portal_spawn_queues.clear()
	portal_spawn_timers.clear()
	_reset_boss_tracking()
	prepared_wave = false
	wave_running = false
	waiting_for_advance = false
	active = true
	if boundary == "settlement":
		if pending_stage <= 1:
			return false
		wave_index = pending_stage - 2
		waiting_for_advance = true
		_emit_wave_status()
		return true
	wave_index = pending_stage - 2
	return prepare_next_wave()

func _process(delta: float) -> void:
	if not active or player == null:
		return
	if waiting_for_advance or prepared_wave or not wave_running:
		return
	if is_instance_valid(boss_portal):
		_process_boss_entrance(delta)
		return
	if not active_portals.is_empty():
		_process_portal_attack(delta)
		return
	if is_instance_valid(active_boss):
		return
	if spawn_queue.is_empty():
		if active_enemies.is_empty():
			_handle_combat_entities_cleared()
		return
	_process_spawn_timer(delta)

func _process_spawn_timer(delta: float) -> int:
	spawn_timer -= delta
	var spawned := 0
	var interval := float(waves[wave_index]["rate"])
	while spawn_timer <= 0.0 and not spawn_queue.is_empty() and spawned < 8:
		_spawn_enemy(spawn_queue.pop_front())
		spawn_timer += interval
		spawned += 1
	if spawned > 0:
		_emit_wave_status()
	return spawned

func prepare_next_wave() -> bool:
	if player == null or prepared_wave or wave_running or waiting_for_advance:
		return false
	wave_index += 1
	if wave_index >= waves.size():
		wave_index = waves.size() - 1
		active = false
		return false
	spawn_queue.clear()
	_reset_boss_tracking()
	var wave := waves[wave_index]
	for count in range(int(wave["scrapper"])):
		spawn_queue.append(EnemyScript.EnemyKind.SCRAPPER)
	for count in range(int(wave["dasher"])):
		spawn_queue.append(EnemyScript.EnemyKind.DASHER)
	for count in range(int(wave["spitter"])):
		spawn_queue.append(EnemyScript.EnemyKind.SPITTER)
	for count in range(int(wave["bruiser"])):
		spawn_queue.append(EnemyScript.EnemyKind.BRUISER)
	for count in range(int(wave["marksman"])):
		spawn_queue.append(EnemyScript.EnemyKind.MARKSMAN)
	for count in range(int(wave["lobber"])):
		spawn_queue.append(EnemyScript.EnemyKind.LOBBER)
	for count in range(int(wave["overseer"])):
		spawn_queue.append(EnemyScript.EnemyKind.OVERSEER)
	spawn_queue.shuffle()
	prepared_wave = true
	wave_running = false
	active = true
	intermission = 0.0
	spawn_timer = 0.0
	_emit_wave_status()
	wave_prepared.emit(_get_wave_summary())
	return true

func begin_prepared_wave() -> bool:
	if not active or not prepared_wave or wave_running or waiting_for_advance:
		return false
	prepared_wave = false
	wave_running = true
	spawn_timer = 0.0
	_open_portal_attack()
	return true

func _open_portal_attack() -> void:
	# Legacy callers without a dedicated portal layer retain the original
	# direct-spawn behavior; the game passes a separate layer from Main.
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
	for index in range(queues.size()):
		if queues[index].is_empty():
			continue
		var portal: Node = SpawnPortalScript.new()
		var portal_position := sample_portal_position(player.global_position, spawn_rng)
		portal.set_process(false)
		var burst_duration := maxf(1.2, ceilf(float(queues[index].size()) / float(PORTAL_SPAWN_COUNT)) * PORTAL_SPAWN_INTERVAL + 0.25)
		portal_parent.add_child(portal)
		portal.configure(portal_position, 0.7, burst_duration)
		active_portals.append(portal)
		portal_spawn_queues[portal.get_instance_id()] = queues[index]
		portal_spawn_timers[portal.get_instance_id()] = 0.0
		portal.closed.connect(_on_portal_closed, CONNECT_ONE_SHOT)
	_emit_wave_status()

func _on_boss_reinforcements_requested(_boss: Node, count: int) -> void:
	if _boss != active_boss or boss_defeat_pending or boss_defeated_for_wave or count <= 0 or portal_parent == null or not is_instance_valid(player):
		return
	count = mini(count, 8)
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
		portal.advance(delta)
		if portal.state != portal.State.BURST:
			continue
		var portal_id: int = portal.get_instance_id()
		portal_spawn_timers[portal_id] = float(portal_spawn_timers.get(portal_id, 0.0)) - delta
		if float(portal_spawn_timers[portal_id]) > 0.0:
			continue
		var queue: Array = portal_spawn_queues.get(portal_id, [])
		for count in range(mini(PORTAL_SPAWN_COUNT, queue.size())):
			_spawn_enemy_at(int(queue.pop_front()), portal.global_position, true)
		portal_spawn_queues[portal_id] = queue
		portal_spawn_timers[portal_id] = PORTAL_SPAWN_INTERVAL
	if active_portals.is_empty() and active_enemies.is_empty() and spawn_queue.is_empty():
		_handle_combat_entities_cleared()
	else:
		_emit_wave_status()

func _handle_combat_entities_cleared() -> void:
	if not wave_running or waiting_for_advance:
		return
	if not spawn_queue.is_empty() or not active_enemies.is_empty() or not active_portals.is_empty():
		return
	if is_instance_valid(boss_portal) or is_instance_valid(active_boss):
		return
	if wave_index == waves.size() - 1:
		if boss_defeated_for_wave:
			_finish_current_wave()
		elif not boss_entrance_started:
			_begin_boss_entrance()
		return
	_finish_current_wave()

func _begin_boss_entrance() -> bool:
	if (
		boss_entrance_started
		or boss_defeated_for_wave
		or not wave_running
		or wave_index != waves.size() - 1
		or portal_parent == null
		or not is_instance_valid(player)
	):
		return false
	boss_entrance_started = true
	var portal: Node = SpawnPortalScript.new()
	portal.name = "OverseerEntrancePortal"
	portal.scale = Vector2.ONE * BOSS_PORTAL_SCALE
	portal.z_index = 4
	portal.set_process(false)
	portal_parent.add_child(portal)
	portal.configure(sample_portal_position(player.global_position, spawn_rng), BOSS_PORTAL_WARNING_SECONDS, BOSS_PORTAL_BURST_SECONDS)
	portal.burst_started.connect(_on_boss_portal_burst, CONNECT_ONE_SHOT)
	portal.closed.connect(_on_boss_portal_closed, CONNECT_ONE_SHOT)
	boss_portal = portal
	_emit_wave_status()
	return true

func _process_boss_entrance(delta: float) -> void:
	var portal := boss_portal
	if not is_instance_valid(portal):
		boss_portal = null
		return
	portal.advance(delta)

func _on_boss_portal_burst(portal: Node) -> void:
	if portal != boss_portal or is_instance_valid(active_boss) or boss_defeated_for_wave:
		return
	_spawn_boss_at(portal.global_position)

func _spawn_boss_at(position: Vector2) -> Node:
	if is_instance_valid(active_boss) or boss_defeated_for_wave or enemy_parent == null:
		return null
	var boss: Node = OverseerBossScript.new()
	boss.world_bounds = world_bounds
	boss.setup(wave_index + 1, projectile_parent, player as Node2D)
	boss.died.connect(_on_boss_died)
	boss.damage_resolved.connect(_forward_damage_resolved)
	boss.reinforcements_requested.connect(_on_boss_reinforcements_requested)
	boss.combat_cue.connect(func(cue: StringName) -> void: boss_cue.emit(cue))
	boss.tree_exiting.connect(_on_boss_tree_exiting.bind(boss), CONNECT_ONE_SHOT)
	enemy_parent.add_child(boss)
	var spawn_bounds := world_bounds.grow(-float(boss.body_radius)) if world_bounds.size != Vector2.ZERO else Rect2()
	boss.global_position = position.clamp(spawn_bounds.position, spawn_bounds.end - Vector2(0.001, 0.001)) if spawn_bounds.size != Vector2.ZERO else position
	boss.velocity = Vector2.ZERO
	active_boss = boss
	active_enemies.append(boss)
	boss.health_changed.connect(_on_boss_health_changed)
	boss_spawned.emit(boss, OverseerBossScript.DISPLAY_NAME, float(boss.health.max_health))
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
	if boss == active_boss:
		active_boss = null
	if boss_defeat_pending and not boss_defeated_for_wave:
		boss_defeat_pending = false
		boss_defeated_for_wave = true
		boss_defeated.emit(boss)
	_emit_wave_status()
	call_deferred("_handle_combat_entities_cleared")

func _on_boss_portal_closed(portal: Node) -> void:
	if portal == boss_portal:
		boss_portal = null
	portal.queue_free()
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

func _finish_current_wave() -> void:
	if waiting_for_advance or not wave_running:
		return
	if wave_index == waves.size() - 1 and not boss_defeated_for_wave:
		return
	_emit_wave_status()
	wave_running = false
	waiting_for_advance = true
	var summary := _get_wave_summary()
	wave_finished.emit(summary)
	if not bool(summary["is_final"]):
		wave_cleared.emit(wave_index + 1)

func advance_after_settlement() -> bool:
	if not can_advance_after_settlement():
		return false
	waiting_for_advance = false
	return prepare_next_wave()

func can_advance_after_settlement() -> bool:
	return (
		waiting_for_advance
		and active
		and not prepared_wave
		and not wave_running
		and wave_index >= 0
		and wave_index < waves.size() - 1
	)

func complete_final_wave() -> bool:
	if not active or not waiting_for_advance or wave_index != waves.size() - 1 or not boss_defeated_for_wave:
		return false
	waiting_for_advance = false
	active = false
	victory.emit()
	return true

func _get_wave_summary() -> Dictionary:
	return {
		"wave": wave_index + 1,
		"total": waves.size(),
		"is_final": wave_index == waves.size() - 1,
	}

func _spawn_enemy(kind: int) -> void:
	var ranged_kind := kind in [EnemyScript.EnemyKind.SPITTER, EnemyScript.EnemyKind.MARKSMAN, EnemyScript.EnemyKind.LOBBER]
	var position := sample_spitter_spawn_position(player.global_position, get_camera_safe_rect(), spawn_rng) if ranged_kind else sample_spawn_position(player.global_position, 24.0, 430.0, spawn_rng)
	_spawn_enemy_at(kind, position)

func _spawn_enemy_at(kind: int, position: Vector2, disperse_from_portal: bool = false) -> void:
	var enemy := EnemyScript.new()
	if world_bounds.size != Vector2.ZERO:
		enemy.world_bounds = world_bounds
	enemy.setup(kind, wave_index + 1, projectile_parent, player as Node2D)
	var spawn_bounds := world_bounds.grow(-enemy.body_radius) if world_bounds.size != Vector2.ZERO else Rect2()
	enemy_parent.add_child(enemy)
	var spawn_position := position
	if disperse_from_portal:
		spawn_position = sample_clear_portal_enemy_position(position, enemy.body_radius)
	elif spawn_bounds.size != Vector2.ZERO:
		spawn_position = position.clamp(spawn_bounds.position, spawn_bounds.end - Vector2(0.001, 0.001))
	# global_position only has world-space meaning after the enemy is parented.
	enemy.global_position = spawn_position
	enemy.velocity = Vector2.ZERO
	active_enemies.append(enemy)
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
	var viewport_size := viewport.get_visible_rect().size
	var camera := viewport.get_camera_2d()
	var center: Vector2 = player.global_position if player != null else viewport.get_visible_rect().get_center()
	var zoom := Vector2.ONE
	if camera != null:
		center = camera.get_screen_center_position()
		zoom = camera.zoom.abs()
	var visible_size := Vector2(
		viewport_size.x / maxf(zoom.x, 0.001),
		viewport_size.y / maxf(zoom.y, 0.001)
	)
	var safe_rect := Rect2(center - visible_size * 0.5, visible_size).grow(-margin)
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
	if world_bounds.size == Vector2.ZERO:
		return player_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * PORTAL_MIN_SAFE_DISTANCE
	var playable := world_bounds.grow(-PORTAL_WORLD_MARGIN)
	var maximum := playable.end - Vector2(0.001, 0.001)
	for attempt in range(128):
		var candidate := Vector2(
			rng.randf_range(playable.position.x, maximum.x),
			rng.randf_range(playable.position.y, maximum.y)
		)
		var distance := candidate.distance_to(player_position)
		if distance >= PORTAL_MIN_SAFE_DISTANCE and distance <= PORTAL_MAX_SAFE_DISTANCE:
			return candidate
	# Keep a concrete margin beyond the contract minimum so a border fallback
	# cannot lose the safety guarantee to floating-point rounding.
	var fallback_distance := PORTAL_MIN_SAFE_DISTANCE + 1.0
	for step in range(48):
		var angle := TAU * float(step) / 48.0
		var candidate := player_position + Vector2.RIGHT.rotated(angle) * fallback_distance
		if playable.has_point(candidate):
			return candidate
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

func _on_enemy_died(enemy: Node, coin_value: int, source: StringName) -> void:
	if enemy.get_meta(&"kill_resolved", false):
		return
	enemy.set_meta(&"kill_resolved", true)
	var death_position: Vector2 = enemy.global_position
	var shield_value: float = enemy.shield_drop_value
	enemy_killed.emit(enemy, source, coin_value)
	call_deferred("_deferred_spawn_drops", death_position, coin_value, shield_value)
	_emit_wave_status()

func _deferred_spawn_drops(position: Vector2, coin_value: int, shield_value: float) -> void:
	var owner := get_parent()
	if not is_instance_valid(owner):
		return
	if coin_value > 0 and owner.has_method("spawn_coins"):
		owner.spawn_coins(position, coin_value)
	if shield_value > 0.0 and owner.has_method("spawn_shield"):
		owner.spawn_shield(position, shield_value)

func _on_enemy_tree_exiting(enemy: Node) -> void:
	active_enemies.erase(enemy)

func _on_portal_closed(portal: Node) -> void:
	portal_spawn_queues.erase(portal.get_instance_id())
	portal_spawn_timers.erase(portal.get_instance_id())
	active_portals.erase(portal)
	portal.queue_free()

func get_active_enemies() -> Array[Node]:
	return active_enemies

func get_active_boss() -> Node:
	return active_boss if is_instance_valid(active_boss) else null

func get_active_portal_count() -> int:
	return active_portals.size()

func _emit_wave_status() -> void:
	var portal_remaining := 0
	for queue in portal_spawn_queues.values():
		portal_remaining += (queue as Array).size()
	var boss_remaining := 1 if wave_index == waves.size() - 1 and (prepared_wave or wave_running) and not boss_defeated_for_wave else 0
	var remaining := spawn_queue.size() + portal_remaining + active_enemies.size()
	if boss_remaining > 0 and not is_instance_valid(active_boss):
		remaining += boss_remaining
	wave_changed.emit(wave_index + 1, waves.size(), remaining)

func _reset_boss_tracking() -> void:
	active_boss = null
	boss_portal = null
	boss_entrance_started = false
	boss_defeat_pending = false
	boss_defeated_for_wave = false
