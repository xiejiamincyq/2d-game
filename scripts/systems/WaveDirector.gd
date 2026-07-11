extends Node
class_name WaveDirector

signal wave_changed(index: int, total: int, remaining: int)
signal enemy_killed(xp_value: int)
signal victory

const EnemyScript = preload("res://scripts/actors/Enemy.gd")

var enemy_parent: Node
var projectile_parent: Node
var player: Node
var wave_index: int = -1
var spawn_queue: Array[int] = []
var spawn_timer: float = 0.0
var intermission: float = 1.2
var active: bool = true
var world_bounds: Rect2 = Rect2()
var spawn_rng := RandomNumberGenerator.new()
var active_enemies: Array[Node] = []

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

func setup(target_player: Node, enemies: Node, projectiles: Node) -> void:
	player = target_player
	enemy_parent = enemies
	projectile_parent = projectiles
	_start_next_wave()

func _process(delta: float) -> void:
	if not active or player == null:
		return
	if intermission > 0.0:
		intermission -= delta
		return
	if spawn_queue.is_empty():
		if active_enemies.is_empty():
			_start_next_wave()
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

func _start_next_wave() -> void:
	wave_index += 1
	if wave_index >= waves.size():
		active = false
		victory.emit()
		return
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
	intermission = 1.5
	spawn_timer = 0.0
	_emit_wave_status()

func _spawn_enemy(kind: int) -> void:
	var enemy := EnemyScript.new()
	enemy.global_position = sample_spawn_position(player.global_position, 24.0, 430.0, spawn_rng)
	if world_bounds.size != Vector2.ZERO:
		enemy.world_bounds = world_bounds
	enemy.setup(kind, wave_index + 1, projectile_parent)
	enemy_parent.add_child(enemy)
	active_enemies.append(enemy)
	enemy.tree_exiting.connect(_on_enemy_tree_exiting.bind(enemy), CONNECT_ONE_SHOT)
	enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("hit"):
		enemy.hit.connect(func(source: StringName) -> void:
			if get_parent().has_method("_on_enemy_hit"):
				get_parent()._on_enemy_hit(source)
		)

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

func _on_enemy_died(enemy: Node, xp_value: int) -> void:
	var death_position: Vector2 = enemy.global_position
	var shield_value: float = enemy.shield_drop_value
	enemy_killed.emit(xp_value)
	call_deferred("_deferred_spawn_drops", death_position, xp_value, shield_value)
	_emit_wave_status()

func _deferred_spawn_drops(position: Vector2, xp_value: int, shield_value: float) -> void:
	var owner := get_parent()
	if not is_instance_valid(owner):
		return
	if xp_value > 0 and owner.has_method("spawn_experience"):
		owner.spawn_experience(position, xp_value)
	if shield_value > 0.0 and owner.has_method("spawn_shield"):
		owner.spawn_shield(position, shield_value)

func _on_enemy_tree_exiting(enemy: Node) -> void:
	active_enemies.erase(enemy)

func get_active_enemies() -> Array[Node]:
	return active_enemies

func _emit_wave_status() -> void:
	var remaining := spawn_queue.size() + active_enemies.size()
	wave_changed.emit(wave_index + 1, waves.size(), remaining)
