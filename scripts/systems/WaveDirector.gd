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
		if get_tree().get_nodes_in_group("enemies").is_empty():
			_start_next_wave()
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_enemy(spawn_queue.pop_front())
		spawn_timer = float(waves[wave_index]["rate"])
		_emit_wave_status()

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
	var angle := randf() * TAU
	var distance := randf_range(430.0, 620.0)
	enemy.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * distance
	if world_bounds.size != Vector2.ZERO:
		enemy.global_position = enemy.global_position.clamp(world_bounds.position + Vector2(24, 24), world_bounds.end - Vector2(24, 24))
		enemy.world_bounds = world_bounds
	enemy.setup(kind, wave_index + 1, projectile_parent)
	enemy_parent.add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("hit"):
		enemy.hit.connect(func(source: StringName) -> void:
			if get_parent().has_method("_on_enemy_hit"):
				get_parent()._on_enemy_hit(source)
		)

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

func _emit_wave_status() -> void:
	var remaining := spawn_queue.size() + get_tree().get_nodes_in_group("enemies").size()
	wave_changed.emit(wave_index + 1, waves.size(), remaining)
