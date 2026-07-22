extends Node
class_name CombatFeedback

const CombatVfx = preload("res://scripts/effects/CombatVfx.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")

const HIT_STOP_WINDOW_MS: float = 100.0
const MAX_STOP_PER_WINDOW_MS: float = 35.0
const KILL_STOP_MS: float = 18.0
const HEAVY_STOP_MS: float = 12.0
const HIT_STOP_TIME_SCALE: float = 0.05

var combat_vfx: Node
var camera_effects: Node
var audio_manager: Node
var overdrive_active_provider: Callable
var _stop_reservations: Array[Dictionary] = []
var _hit_stop_until_ms: float = 0.0
var _owns_time_scale: bool = false

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(vfx: Node, effects: Node, audio: Node = null, overdrive_provider: Callable = Callable()) -> void:
	combat_vfx = vfx
	camera_effects = effects
	audio_manager = audio
	overdrive_active_provider = overdrive_provider

func on_damage_resolved(
	enemy: Node,
	source: StringName,
	amount: float,
	world_position: Vector2,
	direction: Vector2,
	killed: bool
) -> void:
	if amount <= 0.0:
		return
	var intensity := clampf(amount / 40.0, 0.2, 1.0)
	var feedback_weight := _resolve_feedback_weight(enemy)
	_request_vfx(CombatVfx.SPARK, world_position, direction, intensity)
	_request_hit_audio(source, feedback_weight)
	if killed:
		_request_kill_burst(world_position, direction, maxf(0.8, intensity))
		if source == DamageTypes.PROJECTILE and feedback_weight == EnemyScript.FeedbackWeight.HEAVY:
			_request_camera_impact(_get_kill_trauma(feedback_weight), direction)
		_request_kill_audio()
		request_hit_stop(KILL_STOP_MS)
	elif source in [DamageTypes.DASH, DamageTypes.SPIKE] or amount >= 40.0:
		request_heavy_hit(world_position, direction, intensity)

func request_heavy_hit(
	world_position: Vector2,
	direction: Vector2 = Vector2.ZERO,
	intensity: float = 1.0
) -> void:
	var resolved_intensity := clampf(intensity, 0.25, 1.0)
	_request_vfx(CombatVfx.RING, world_position, direction, resolved_intensity)
	_request_camera_impact(maxf(0.35, resolved_intensity), direction)
	request_hit_stop(HEAVY_STOP_MS)

func request_hit_stop(requested_ms: float) -> float:
	if requested_ms <= 0.0:
		return 0.0
	var now_ms := float(Time.get_ticks_msec())
	_prune_stop_reservations(now_ms)
	var reserved_ms := _sum_reserved_stop_ms()
	var active_remaining_ms := maxf(0.0, _hit_stop_until_ms - now_ms)
	var available_budget := maxf(0.0, MAX_STOP_PER_WINDOW_MS - reserved_ms)
	var available_active := maxf(0.0, MAX_STOP_PER_WINDOW_MS - active_remaining_ms)
	var granted_ms := minf(requested_ms, minf(available_budget, available_active))
	if granted_ms <= 0.0:
		return 0.0
	_stop_reservations.append({"time_ms": now_ms, "duration_ms": granted_ms})
	_hit_stop_until_ms = maxf(_hit_stop_until_ms, now_ms) + granted_ms
	_owns_time_scale = true
	Engine.time_scale = HIT_STOP_TIME_SCALE
	return granted_ms

func get_reserved_hit_stop_ms() -> float:
	_prune_stop_reservations(float(Time.get_ticks_msec()))
	return _sum_reserved_stop_ms()

func get_active_hit_stop_remaining_ms() -> float:
	return maxf(0.0, _hit_stop_until_ms - float(Time.get_ticks_msec()))

func _process(_delta: float) -> void:
	if not _owns_time_scale:
		return
	if float(Time.get_ticks_msec()) >= _hit_stop_until_ms:
		_restore_time_scale()

func reset_all() -> void:
	_stop_reservations.clear()
	_hit_stop_until_ms = 0.0
	_restore_time_scale()

func _request_vfx(
	effect_type: StringName,
	world_position: Vector2,
	direction: Vector2,
	intensity: float
) -> void:
	if is_instance_valid(combat_vfx) and combat_vfx.has_method("request_effect"):
		combat_vfx.request_effect(effect_type, world_position, direction, intensity)

func _request_camera_impact(intensity: float, direction: Vector2) -> void:
	if is_instance_valid(camera_effects) and camera_effects.has_method("request_impact"):
		camera_effects.request_impact(intensity, direction)

func _request_kill_audio() -> void:
	if not is_instance_valid(audio_manager):
		return
	if overdrive_active_provider.is_valid() and bool(overdrive_active_provider.call()) and audio_manager.has_method("play_overdrive_kill"):
		audio_manager.play_overdrive_kill()
	elif audio_manager.has_method("play_kill_confirm"):
		audio_manager.play_kill_confirm()

func _request_hit_audio(source: StringName, feedback_weight: int) -> void:
	if is_instance_valid(audio_manager) and audio_manager.has_method("play_hit"):
		audio_manager.play_hit(source, feedback_weight)

func _resolve_feedback_weight(enemy: Node) -> int:
	if is_instance_valid(enemy) and enemy.has_method("get_feedback_weight"):
		return int(enemy.get_feedback_weight())
	return EnemyScript.FeedbackWeight.MEDIUM

func _get_kill_trauma(feedback_weight: int) -> float:
	match feedback_weight:
		EnemyScript.FeedbackWeight.LIGHT:
			return 0.10
		EnemyScript.FeedbackWeight.HEAVY:
			return 0.45
		_:
			return 0.26

func _request_kill_burst(world_position: Vector2, direction: Vector2, intensity: float) -> void:
	var base_direction := direction.normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT
	for index in range(6):
		var burst_direction := base_direction.rotated(TAU * float(index) / 6.0)
		_request_vfx(CombatVfx.DEBRIS, world_position, burst_direction, intensity)
	for index in range(4):
		var spark_direction := base_direction.rotated(TAU * (float(index) + 0.5) / 4.0)
		_request_vfx(CombatVfx.SPARK, world_position, spark_direction, intensity)
	_request_vfx(CombatVfx.RING, world_position, base_direction, intensity * 1.25)
	_request_vfx(CombatVfx.RING, world_position, -base_direction, intensity * 0.75)

func _prune_stop_reservations(now_ms: float) -> void:
	var cutoff := now_ms - HIT_STOP_WINDOW_MS
	for index in range(_stop_reservations.size() - 1, -1, -1):
		if float(_stop_reservations[index]["time_ms"]) <= cutoff:
			_stop_reservations.remove_at(index)

func _sum_reserved_stop_ms() -> float:
	var total := 0.0
	for reservation in _stop_reservations:
		total += float(reservation["duration_ms"])
	return total

func _restore_time_scale() -> void:
	Engine.time_scale = 1.0
	_owns_time_scale = false

func _exit_tree() -> void:
	reset_all()
