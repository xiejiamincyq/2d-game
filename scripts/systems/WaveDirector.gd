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
signal victory

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const SpawnPortalScript = preload("res://scripts/world/SpawnPortal.gd")

const PORTAL_MIN_SAFE_DISTANCE := 260.0
const PORTAL_MAX_SAFE_DISTANCE := 520.0
const PORTAL_WORLD_MARGIN := 48.0
const PORTAL_SPAWN_INTERVAL := 0.1
const PORTAL_SPAWN_COUNT := 2

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

var waves: Array[Dictionary] = [
	{"scrapper": 34, "dasher": 5, "spitter": 0, "bruiser": 0, "rate": 0.16},
	{"scrapper": 46, "dasher": 10, "spitter": 2, "bruiser": 1, "rate": 0.13},
	{"scrapper": 58, "dasher": 16, "spitter": 4, "bruiser": 1, "rate": 0.11},
	{"scrapper": 72, "dasher": 22, "spitter": 6, "bruiser": 2, "rate": 0.095},
	{"scrapper": 88, "dasher": 28, "spitter": 8, "bruiser": 2, "rate": 0.08},
	{"scrapper": 104, "dasher": 36, "spitter": 11, "bruiser": 3, "rate": 0.07},
	{"scrapper": 124, "dasher": 44, "spitter": 14, "bruiser": 4, "rate": 0.06},
	{"scrapper": 150, "dasher": 56, "spitter": 18, "bruiser": 5, "rate": 0.05}
]

func _ready() -> void:
	spawn_rng.randomize()

func setup(target_player: Node, enemies: Node, projectiles: Node, portals: Node = null) -> void:
	player = target_player
	enemy_parent = enemies
	projectile_parent = projectiles
	portal_parent = portals if portals != null else enemies
	prepare_next_wave()

func _process(delta: float) -> void:
	if not active or player == null:
		return
	if waiting_for_advance or prepared_wave or not wave_running:
		return
	if not active_portals.is_empty():
		_process_portal_attack(delta)
		return
	if spawn_queue.is_empty():
		if active_enemies.is_empty():
			_finish_current_wave()
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
	var wave := waves[wave_index]
	for count in range(int(wave["scrapper"])):
		spawn_queue.append(EnemyScript.EnemyKind.SCRAPPER)
	for count in range(int(wave["dasher"])):
		spawn_queue.append(EnemyScript.EnemyKind.DASHER)
	for count in range(int(wave["spitter"])):
		spawn_queue.append(EnemyScript.EnemyKind.SPITTER)
	for count in range(int(wave["bruiser"])):
		spawn_queue.append(EnemyScript.EnemyKind.BRUISER)
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
	for index in range(portal_count):
		var portal: Node = SpawnPortalScript.new()
		var portal_position := sample_portal_position(player.global_position, spawn_rng)
		portal.set_process(false)
		var burst_duration := maxf(1.2, ceilf(float(queues[index].size()) / float(PORTAL_SPAWN_COUNT)) * PORTAL_SPAWN_INTERVAL + 0.25)
		portal_parent.add_child(portal)
		# The portal layer can be transformed independently from the enemy layer.
		# Attach first so this remains an actual world-space spawn point.
		portal.configure(portal_position, 0.7, burst_duration)
		active_portals.append(portal)
		portal_spawn_queues[portal.get_instance_id()] = queues[index]
		portal_spawn_timers[portal.get_instance_id()] = 0.0
		portal.closed.connect(_on_portal_closed, CONNECT_ONE_SHOT)
	_emit_wave_status()

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
			_spawn_enemy_at(int(queue.pop_front()), portal.global_position)
		portal_spawn_queues[portal_id] = queue
		portal_spawn_timers[portal_id] = PORTAL_SPAWN_INTERVAL
	if active_portals.is_empty() and active_enemies.is_empty() and spawn_queue.is_empty():
		_finish_current_wave()
	else:
		_emit_wave_status()

func _finish_current_wave() -> void:
	if waiting_for_advance or not wave_running:
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
	if not active or not waiting_for_advance or wave_index != waves.size() - 1:
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
	var position := sample_spitter_spawn_position(player.global_position, get_camera_safe_rect(), spawn_rng) if kind == EnemyScript.EnemyKind.SPITTER else sample_spawn_position(player.global_position, 24.0, 430.0, spawn_rng)
	_spawn_enemy_at(kind, position)

func _spawn_enemy_at(kind: int, position: Vector2) -> void:
	var enemy := EnemyScript.new()
	if world_bounds.size != Vector2.ZERO:
		enemy.world_bounds = world_bounds
	enemy.setup(kind, wave_index + 1, projectile_parent)
	var spawn_bounds := world_bounds.grow(-enemy.body_radius) if world_bounds.size != Vector2.ZERO else Rect2()
	enemy_parent.add_child(enemy)
	# Set world coordinates after parenting. Otherwise a transformed world/layer
	# silently interprets the portal position as local and can launch enemies
	# toward an unrelated map edge on their first pursuit frame.
	enemy.global_position = position.clamp(spawn_bounds.position, spawn_bounds.end - Vector2.ONE) if spawn_bounds.size != Vector2.ZERO else position
	enemy.velocity = Vector2.ZERO
	active_enemies.append(enemy)
	enemy.tree_exiting.connect(_on_enemy_tree_exiting.bind(enemy), CONNECT_ONE_SHOT)
	enemy.died.connect(_on_enemy_died)
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

func get_active_portal_count() -> int:
	return active_portals.size()

func _emit_wave_status() -> void:
	var portal_remaining := 0
	for queue in portal_spawn_queues.values():
		portal_remaining += (queue as Array).size()
	var remaining := spawn_queue.size() + portal_remaining + active_enemies.size()
	wave_changed.emit(wave_index + 1, waves.size(), remaining)
