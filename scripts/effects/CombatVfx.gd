extends Node2D
class_name CombatVfx

const SPARK: StringName = &"spark"
const DEBRIS: StringName = &"debris"
const RING: StringName = &"ring"
const AFTERIMAGE: StringName = &"afterimage"

const MAX_SPARKS: int = 96
const MAX_DEBRIS: int = 48
const MAX_RINGS: int = 16
const MAX_AFTERIMAGES: int = 24

const CYAN := Color("33fff2")
const MAGENTA := Color("f559bf")
const ORANGE := Color("ff571f")

var _sparks: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _afterimages: Array[Dictionary] = []

func request_effect(
	effect_type: StringName,
	world_position: Vector2,
	direction: Vector2 = Vector2.ZERO,
	intensity: float = 1.0
) -> void:
	var strength := clampf(intensity, 0.1, 2.0)
	var resolved_direction := direction.normalized()
	if resolved_direction == Vector2.ZERO:
		resolved_direction = Vector2.RIGHT
	match effect_type:
		SPARK:
			_append_bounded(_sparks, {
				"position": world_position,
				"velocity": resolved_direction * (90.0 + 70.0 * strength),
				"life": 0.1 + 0.06 * strength,
				"max_life": 0.1 + 0.06 * strength,
				"size": 5.0 + 4.0 * strength,
			}, MAX_SPARKS)
		DEBRIS:
			_append_bounded(_debris, {
				"position": world_position,
				"velocity": resolved_direction.rotated(0.65) * (55.0 + 45.0 * strength),
				"life": 0.22 + 0.1 * strength,
				"max_life": 0.22 + 0.1 * strength,
				"size": 3.0 + 2.0 * strength,
			}, MAX_DEBRIS)
		RING:
			_append_bounded(_rings, {
				"position": world_position,
				"life": 0.16 + 0.08 * strength,
				"max_life": 0.16 + 0.08 * strength,
				"radius": 8.0,
				"growth": 90.0 + 45.0 * strength,
			}, MAX_RINGS)
		AFTERIMAGE:
			_append_bounded(_afterimages, {
				"position": world_position,
				"direction": resolved_direction,
				"life": 0.14 + 0.08 * strength,
				"max_life": 0.14 + 0.08 * strength,
				"size": 12.0 + 5.0 * strength,
			}, MAX_AFTERIMAGES)
		_:
			return
	queue_redraw()

func _process(delta: float) -> void:
	var had_effects := get_total_effect_count() > 0
	_update_moving_records(_sparks, delta)
	_update_moving_records(_debris, delta)
	_update_static_records(_rings, delta, true)
	_update_static_records(_afterimages, delta, false)
	if had_effects or get_total_effect_count() > 0:
		queue_redraw()

func _draw() -> void:
	for record in _afterimages:
		var alpha: float = _life_ratio(record) * 0.22
		var size: float = record["size"]
		var direction: Vector2 = record["direction"]
		var perpendicular := direction.orthogonal()
		var center: Vector2 = record["position"]
		var points := PackedVector2Array([
			center + direction * size,
			center + perpendicular * size * 0.55,
			center - direction * size,
			center - perpendicular * size * 0.55,
		])
		draw_colored_polygon(points, Color(CYAN, alpha))
	for record in _rings:
		var ratio: float = _life_ratio(record)
		draw_arc(
			record["position"],
			record["radius"],
			0.0,
			TAU,
			24,
			Color(MAGENTA, ratio * 0.7),
			2.0 + ratio * 2.0
		)
	for record in _debris:
		var debris_ratio: float = _life_ratio(record)
		var debris_size: float = record["size"]
		draw_rect(
			Rect2(record["position"] - Vector2.ONE * debris_size * 0.5, Vector2.ONE * debris_size),
			Color(CYAN, debris_ratio * 0.8)
		)
	for record in _sparks:
		var spark_ratio: float = _life_ratio(record)
		var velocity: Vector2 = record["velocity"]
		var tail: Vector2 = velocity.normalized() * float(record["size"])
		draw_line(record["position"], record["position"] - tail, Color(ORANGE, spark_ratio), 2.0)

func clear_all() -> void:
	_sparks.clear()
	_debris.clear()
	_rings.clear()
	_afterimages.clear()
	queue_redraw()

func get_effect_count(effect_type: StringName) -> int:
	match effect_type:
		SPARK:
			return _sparks.size()
		DEBRIS:
			return _debris.size()
		RING:
			return _rings.size()
		AFTERIMAGE:
			return _afterimages.size()
	return 0

func get_total_effect_count() -> int:
	return _sparks.size() + _debris.size() + _rings.size() + _afterimages.size()

func _append_bounded(records: Array[Dictionary], record: Dictionary, capacity: int) -> void:
	if records.size() >= capacity:
		records.pop_front()
	records.append(record)

func _update_moving_records(records: Array[Dictionary], delta: float) -> void:
	for index in range(records.size() - 1, -1, -1):
		var record: Dictionary = records[index]
		record["life"] = float(record["life"]) - delta
		if record["life"] <= 0.0:
			records.remove_at(index)
			continue
		record["position"] = Vector2(record["position"]) + Vector2(record["velocity"]) * delta
		records[index] = record

func _update_static_records(records: Array[Dictionary], delta: float, grows: bool) -> void:
	for index in range(records.size() - 1, -1, -1):
		var record: Dictionary = records[index]
		record["life"] = float(record["life"]) - delta
		if record["life"] <= 0.0:
			records.remove_at(index)
			continue
		if grows:
			record["radius"] = float(record["radius"]) + float(record["growth"]) * delta
		records[index] = record

func _life_ratio(record: Dictionary) -> float:
	return clampf(float(record["life"]) / maxf(0.001, float(record["max_life"])), 0.0, 1.0)

func _exit_tree() -> void:
	clear_all()
