extends Node2D
class_name BossProjectilePattern

signal warning_started(pattern_id: StringName, duration: float, locked_directions: Array[Vector2])
signal pattern_finished(pattern_id: StringName)

const BossProjectileScript = preload("res://scripts/components/BossProjectile.gd")

const AIMED_FAN: StringName = &"aimed_fan"
const TWIN_SPIRAL: StringName = &"twin_spiral"
const BROKEN_RING: StringName = &"broken_ring"
const AIMED_WARNING_SECONDS := 0.45
const AIMED_ROUND_WINDOW_SECONDS := 0.55
const SPIRAL_WARNING_SECONDS := 0.28
const SPIRAL_GROUP_INTERVAL_SECONDS := 0.14
const RING_WARNING_SECONDS := 0.32
const RING_ROUND_INTERVAL_SECONDS := 0.65
const PATTERN_BLANK_WINDOW_SECONDS := 0.65
const GLOBAL_PROJECTILE_CAP := 140
const MAX_PROJECTILES_PER_SECOND := 40.0
const SPAWN_BURST_CAPACITY := 40.0
const EPSILON := 0.00001

var projectile_parent: Node
var world_bounds := Rect2()
var target_player: Node2D
var boss_owner_id := 0

var _rng := RandomNumberGenerator.new()
var _active_pattern: StringName = &""
var _active_plan: Array[Dictionary] = []
var _event_cursor := 0
var _elapsed := 0.0
var _blank_window_remaining := 0.0
var _spawned_projectiles: Array[Node] = []
var _spawn_budget := SPAWN_BURST_CAPACITY
var _total_spawned := 0

func configure(
	projectiles: Node,
	bounds: Rect2,
	target: Node2D,
	owner_id: int,
	seed_value: int
) -> void:
	projectile_parent = projectiles
	world_bounds = bounds
	target_player = target
	boss_owner_id = owner_id
	_rng.seed = seed_value
	_blank_window_remaining = 0.0

func _process(delta: float) -> void:
	advance(delta)

func start_pattern(pattern_id: StringName) -> bool:
	if _active_pattern != &"" or _blank_window_remaining > EPSILON:
		return false
	if projectile_parent == null:
		return false
	match pattern_id:
		AIMED_FAN:
			if not is_instance_valid(target_player):
				return false
			_active_plan = _build_aimed_fan_plan()
		TWIN_SPIRAL:
			if not is_instance_valid(target_player):
				return false
			_active_plan = _build_twin_spiral_plan()
		BROKEN_RING:
			if not is_instance_valid(target_player):
				return false
			_active_plan = _build_broken_ring_plan()
		_:
			return false
	_active_pattern = pattern_id
	_event_cursor = 0
	_elapsed = 0.0
	var locked_directions: Array[Vector2] = []
	for event: Dictionary in _active_plan:
		if int(event.round) == 0:
			locked_directions.append(event.direction)
	var warning_seconds := AIMED_WARNING_SECONDS
	if pattern_id == TWIN_SPIRAL:
		warning_seconds = SPIRAL_WARNING_SECONDS
	elif pattern_id == BROKEN_RING:
		warning_seconds = RING_WARNING_SECONDS
	warning_started.emit(pattern_id, warning_seconds, locked_directions)
	queue_redraw()
	return true

func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	_spawn_budget = minf(SPAWN_BURST_CAPACITY, _spawn_budget + delta * MAX_PROJECTILES_PER_SECOND)
	if _blank_window_remaining > 0.0:
		_blank_window_remaining = maxf(0.0, _blank_window_remaining - delta)
	if _active_pattern == &"":
		return
	_elapsed += delta
	while _event_cursor < _active_plan.size():
		var event: Dictionary = _active_plan[_event_cursor]
		if float(event.time) > _elapsed + EPSILON:
			break
		_spawn_projectile(event)
		_event_cursor += 1
	if _event_cursor >= _active_plan.size():
		var completed_pattern := _active_pattern
		_active_pattern = &""
		_blank_window_remaining = PATTERN_BLANK_WINDOW_SECONDS
		pattern_finished.emit(completed_pattern)
	queue_redraw()

func get_active_plan() -> Array[Dictionary]:
	return _active_plan.duplicate(true)

func is_pattern_active() -> bool:
	return _active_pattern != &""

func get_total_spawned() -> int:
	return _total_spawned

func cancel(clear_spawned: bool = true) -> void:
	_active_pattern = &""
	_active_plan.clear()
	_event_cursor = 0
	_elapsed = 0.0
	_blank_window_remaining = PATTERN_BLANK_WINDOW_SECONDS
	if clear_spawned:
		clear_projectiles()
	queue_redraw()

func clear() -> void:
	cancel(true)

func clear_projectiles() -> void:
	for projectile in _spawned_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	_spawned_projectiles.clear()

func _build_aimed_fan_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var projectile_count := _rng.randi_range(5, 7)
	var aim_direction := (target_player.global_position - global_position).normalized()
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	var spread := deg_to_rad(54.0)
	for round_index in range(2):
		var event_time := AIMED_WARNING_SECONDS + float(round_index) * AIMED_ROUND_WINDOW_SECONDS
		for index in range(projectile_count):
			var ratio := 0.5 if projectile_count == 1 else float(index) / float(projectile_count - 1)
			var direction := aim_direction.rotated(lerpf(-spread * 0.5, spread * 0.5, ratio))
			plan.append({
				"time": event_time,
				"round": round_index,
				"direction": direction,
				"speed": _rng.randf_range(220.0, 280.0),
				"offset": Vector2.ZERO,
				"safe_channel_degrees": 360.0 - rad_to_deg(spread),
			})
	return plan

func _build_twin_spiral_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var group_count := _rng.randi_range(8, 10)
	var aim_direction := (target_player.global_position - global_position).normalized()
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	var source_axis := aim_direction.orthogonal() * 34.0
	for group_index in range(group_count):
		var progress := float(group_index) / float(maxi(1, group_count - 1))
		var sweep_angle := lerpf(-deg_to_rad(60.0), deg_to_rad(60.0), progress)
		var event_time := SPIRAL_WARNING_SECONDS + float(group_index) * SPIRAL_GROUP_INTERVAL_SECONDS
		for arm_index in range(2):
			var arm_sign := -1.0 if arm_index == 0 else 1.0
			plan.append({
				"time": event_time,
				"round": group_index,
				"direction": aim_direction.rotated(sweep_angle * arm_sign),
				"speed": _rng.randf_range(150.0, 210.0),
				"offset": source_axis * arm_sign,
				"safe_channel_degrees": 240.0,
			})
	return plan

func _build_broken_ring_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var aim_direction := (target_player.global_position - global_position).normalized()
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	var gap_degrees := _rng.randf_range(46.0, 60.0)
	var gap_radians := deg_to_rad(gap_degrees)
	var gap_rotation := deg_to_rad(_rng.randf_range(25.0, 35.0))
	for round_index in range(3):
		var projectile_count := _rng.randi_range(20, 24)
		var gap_center := aim_direction.angle() + gap_rotation * float(round_index)
		var available_arc := TAU - gap_radians
		var event_time := RING_WARNING_SECONDS + float(round_index) * RING_ROUND_INTERVAL_SECONDS
		for index in range(projectile_count):
			var ratio := float(index) / float(maxi(1, projectile_count - 1))
			var angle := gap_center + gap_radians * 0.5 + available_arc * ratio
			plan.append({
				"time": event_time,
				"round": round_index,
				"direction": Vector2.RIGHT.rotated(angle),
				"speed": _rng.randf_range(175.0, 205.0),
				"offset": Vector2.ZERO,
				"gap_center": gap_center,
				"gap_degrees": gap_degrees,
				"safe_channel_degrees": gap_degrees,
			})
	return plan

func _spawn_projectile(event: Dictionary) -> void:
	if _get_global_boss_projectile_count() >= GLOBAL_PROJECTILE_CAP:
		return
	if _spawn_budget + EPSILON < 1.0:
		return
	var shot: Node2D = BossProjectileScript.new()
	shot.velocity = Vector2(event.direction) * float(event.speed)
	shot.damage = 9.0
	shot.radius = 5.0
	shot.lifetime = 6.0
	shot.target_group = &"player"
	shot.tint = Color("f559bf")
	shot.world_bounds = world_bounds
	shot.set_meta(&"boss_owner_id", boss_owner_id)
	shot.set_meta(&"boss_pattern", _active_pattern)
	shot.add_to_group(&"boss_projectiles")
	projectile_parent.add_child(shot)
	shot.global_position = global_position + Vector2(event.offset)
	_spawned_projectiles.append(shot)
	_spawn_budget = maxf(0.0, _spawn_budget - 1.0)
	_total_spawned += 1

func _get_global_boss_projectile_count() -> int:
	if not is_inside_tree():
		return 0
	var count := 0
	for projectile in get_tree().get_nodes_in_group(&"boss_projectiles"):
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			count += 1
	return count

func _draw() -> void:
	if _active_pattern != AIMED_FAN or _elapsed >= AIMED_WARNING_SECONDS:
		return
	var progress := clampf(_elapsed / AIMED_WARNING_SECONDS, 0.0, 1.0)
	for event: Dictionary in _active_plan:
		if int(event.round) != 0:
			continue
		draw_line(Vector2.ZERO, Vector2(event.direction) * 340.0, Color(1.0, 0.34, 0.12, 0.18 + progress * 0.42), 1.5)
