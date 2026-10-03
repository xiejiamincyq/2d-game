extends Node2D
class_name TentacleAttack

const ProjectileScript = preload("res://scripts/components/BossProjectile.gd")

const WARNING_COLOR := Color("f27a4b")
const OUTLINE_COLOR := Color("123b3b")
const SWEEP_WARNING_SECONDS := 1.0
const SWEEP_ACTIVE_SECONDS := 0.22
const SWEEP_RANGE := 300.0
const SWEEP_ARC_DEGREES := 54.0
const SWEEP_DAMAGE := 18.0
const SLAM_WARNING_SECONDS := 1.1
const SLAM_DIAMETER := 90.0
const SLAM_RADIUS := SLAM_DIAMETER * 0.5
const SLAM_DAMAGE := 20.0
const SLAM_CHANNEL_WIDTH := 70.0
const SLAM_TARGET_SPACING := SLAM_DIAMETER + SLAM_CHANNEL_WIDTH + 0.1
const SLAM_PROJECTILE_COUNT := 6
const SLAM_PROJECTILE_SPEED := 105.0
const SLAM_PROJECTILE_DAMAGE := 6.0

enum AttackKind { NONE, SWEEP, SLAM }
enum AttackStage { IDLE, WARNING, ACTIVE }

var boss: Node2D
var target_player: Node2D
var projectile_parent: Node
var attack_kind := AttackKind.NONE
var attack_stage := AttackStage.IDLE
var elapsed := 0.0
var sweep_angle := 0.0
var sweep_hit_player := false
var slam_targets: Array[Vector2] = []
var owned_projectiles: Array[Node] = []
var ground_fill: Node2D

func configure(owner_boss: Node2D, target: Node2D, projectiles: Node) -> void:
	boss = owner_boss
	target_player = target
	projectile_parent = projectiles

func _ready() -> void:
	set_physics_process(false)
	ground_fill = Node2D.new()
	ground_fill.name = "GroundFill"
	ground_fill.z_as_relative = false
	ground_fill.z_index = -1
	ground_fill.draw.connect(_draw_ground_fill)
	add_child(ground_fill)
	_queue_visual_redraw()

func _queue_visual_redraw() -> void:
	queue_redraw()
	if is_instance_valid(ground_fill):
		ground_fill.queue_redraw()

func _physics_process(delta: float) -> void:
	advance_attack(delta)

func start_sweep(target_position: Vector2) -> bool:
	if not _can_start_attack():
		return false
	var direction := target_position - boss.global_position
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	sweep_angle = direction.angle()
	sweep_hit_player = false
	attack_kind = AttackKind.SWEEP
	attack_stage = AttackStage.WARNING
	elapsed = 0.0
	set_physics_process(true)
	_queue_visual_redraw()
	return true

func start_slam(target_positions: Array[Vector2]) -> bool:
	if not _can_start_attack() or not _are_valid_slam_targets(target_positions):
		return false
	slam_targets.assign(target_positions)
	attack_kind = AttackKind.SLAM
	attack_stage = AttackStage.WARNING
	elapsed = 0.0
	set_physics_process(true)
	_queue_visual_redraw()
	return true

func make_slam_targets(anchor: Vector2, count: int = 3) -> Array[Vector2]:
	var resolved_count := clampi(count, 2, 3)
	var outward := anchor - boss.global_position if is_instance_valid(boss) else Vector2.RIGHT
	var axis := outward.normalized().orthogonal() if outward.length_squared() > 0.0001 else Vector2.DOWN
	var result: Array[Vector2] = []
	var center_offset := (float(resolved_count) - 1.0) * 0.5
	for index in range(resolved_count):
		result.append(anchor + axis * (float(index) - center_offset) * SLAM_TARGET_SPACING)
	return result

func advance_attack(delta: float) -> void:
	if not is_attacking() or delta <= 0.0:
		return
	elapsed += delta
	if attack_stage == AttackStage.WARNING:
		var warning_duration := SWEEP_WARNING_SECONDS if attack_kind == AttackKind.SWEEP else SLAM_WARNING_SECONDS
		if elapsed < warning_duration:
			_queue_visual_redraw()
			return
		elapsed -= warning_duration
		attack_stage = AttackStage.ACTIVE
		if attack_kind == AttackKind.SLAM:
			_resolve_slam()
			_finish_attack()
			return
	if attack_kind == AttackKind.SWEEP:
		_try_sweep_hit()
		if elapsed >= SWEEP_ACTIVE_SECONDS:
			_finish_attack()
	_queue_visual_redraw()

func cancel_attack() -> void:
	attack_kind = AttackKind.NONE
	attack_stage = AttackStage.IDLE
	elapsed = 0.0
	slam_targets.clear()
	sweep_hit_player = false
	set_physics_process(false)
	cleanup_projectiles()
	_queue_visual_redraw()

func cleanup_projectiles() -> void:
	for shot in owned_projectiles:
		if is_instance_valid(shot):
			shot.queue_free()
	owned_projectiles.clear()

func is_attacking() -> bool:
	return attack_kind != AttackKind.NONE

func is_point_in_sweep(world_point: Vector2) -> bool:
	if not is_instance_valid(boss):
		return false
	var offset := world_point - boss.global_position
	if offset.length() > SWEEP_RANGE:
		return false
	return absf(wrapf(offset.angle() - sweep_angle, -PI, PI)) <= deg_to_rad(SWEEP_ARC_DEGREES * 0.5)

func get_slam_targets() -> Array[Vector2]:
	return slam_targets.duplicate()

func get_projectile_group() -> StringName:
	var owner_id := boss.get_instance_id() if is_instance_valid(boss) else 0
	return StringName("boss_tentacle_projectiles_%d" % owner_id)

func _can_start_attack() -> bool:
	return not is_attacking() and is_instance_valid(boss)

func _are_valid_slam_targets(target_positions: Array[Vector2]) -> bool:
	if target_positions.size() < 2 or target_positions.size() > 3:
		return false
	for first in range(target_positions.size()):
		for second in range(first + 1, target_positions.size()):
			if target_positions[first].distance_to(target_positions[second]) < SLAM_TARGET_SPACING:
				return false
	return true

func _try_sweep_hit() -> void:
	if sweep_hit_player or not is_instance_valid(target_player):
		return
	if is_point_in_sweep(target_player.global_position) and target_player.has_method("take_damage"):
		target_player.take_damage(SWEEP_DAMAGE)
		sweep_hit_player = true

func _resolve_slam() -> void:
	for target_position in slam_targets:
		if (
			is_instance_valid(target_player)
			and target_player.global_position.distance_to(target_position) <= SLAM_RADIUS
			and target_player.has_method("take_damage")
		):
			target_player.take_damage(SLAM_DAMAGE)
		_spawn_slam_projectiles(target_position)

func _spawn_slam_projectiles(origin: Vector2) -> void:
	if not is_instance_valid(projectile_parent):
		return
	for index in range(SLAM_PROJECTILE_COUNT):
		var shot := ProjectileScript.new()
		shot.velocity = Vector2.RIGHT.rotated(TAU * float(index) / float(SLAM_PROJECTILE_COUNT)) * SLAM_PROJECTILE_SPEED
		shot.damage = SLAM_PROJECTILE_DAMAGE
		shot.target_group = &"player"
		shot.tint = WARNING_COLOR
		shot.radius = 5.0
		shot.lifetime = 3.0
		var projectile_bounds: Rect2 = boss.get("world_bounds")
		if projectile_bounds.size != Vector2.ZERO:
			shot.world_bounds = projectile_bounds
		shot.set_meta(&"boss_owner_id", boss.get_instance_id())
		shot.add_to_group(get_projectile_group())
		projectile_parent.add_child(shot)
		shot.global_position = origin
		owned_projectiles.append(shot)

func _finish_attack() -> void:
	attack_kind = AttackKind.NONE
	attack_stage = AttackStage.IDLE
	elapsed = 0.0
	slam_targets.clear()
	set_physics_process(false)
	_queue_visual_redraw()

func _exit_tree() -> void:
	cancel_attack()

func _draw() -> void:
	if attack_stage == AttackStage.IDLE:
		return
	if attack_kind == AttackKind.SWEEP:
		_draw_sweep()
	elif attack_kind == AttackKind.SLAM:
		_draw_slam()

func _draw_sweep() -> void:
	var half_arc := deg_to_rad(SWEEP_ARC_DEGREES * 0.5)
	draw_arc(Vector2.ZERO, SWEEP_RANGE, sweep_angle - half_arc, sweep_angle + half_arc, 24, OUTLINE_COLOR, 5.0, true)
	draw_arc(Vector2.ZERO, SWEEP_RANGE, sweep_angle - half_arc, sweep_angle + half_arc, 24, WARNING_COLOR, 3.0, true)
	for edge_angle in [sweep_angle - half_arc, sweep_angle + half_arc]:
		var endpoint := Vector2.RIGHT.rotated(edge_angle) * SWEEP_RANGE
		draw_line(Vector2.ZERO, endpoint, OUTLINE_COLOR, 4.0, true)
		draw_line(Vector2.ZERO, endpoint, WARNING_COLOR, 2.0, true)
	if attack_stage == AttackStage.ACTIVE:
		_draw_active_hose(half_arc)

func _draw_active_hose(half_arc: float) -> void:
	# Visual sweep only: damage remains the original once-per-sector active hit.
	var progress := clampf(elapsed / SWEEP_ACTIVE_SECONDS, 0.0, 1.0)
	var direction_angle := sweep_angle + lerpf(-half_arc + 0.03, half_arc - 0.03, progress)
	var points := PackedVector2Array()
	for index in range(25):
		var ratio := float(index) / 24.0
		var bend := sin(ratio * PI) * sin(progress * PI) * 0.05
		var angle := clampf(direction_angle + bend, sweep_angle - half_arc + 0.03, sweep_angle + half_arc - 0.03)
		points.append(Vector2.RIGHT.rotated(angle) * lerpf(56.0, SWEEP_RANGE - 10.0, ratio))
	draw_polyline(points, OUTLINE_COLOR, 13.0, true)
	draw_polyline(points, Color("35b8ac"), 8.0, true)
	var tip := points[points.size() - 1]
	draw_circle(tip, 8.0, OUTLINE_COLOR)
	draw_circle(tip, 5.0, WARNING_COLOR)

func _draw_ground_fill() -> void:
	if attack_stage == AttackStage.IDLE:
		return
	if attack_kind == AttackKind.SLAM:
		for world_target in slam_targets:
			ground_fill.draw_circle(ground_fill.to_local(world_target), SLAM_RADIUS, Color(WARNING_COLOR, 0.08))
		return
	if attack_kind != AttackKind.SWEEP:
		return
	var half_arc := deg_to_rad(SWEEP_ARC_DEGREES * 0.5)
	var points := PackedVector2Array([Vector2.ZERO])
	for index in range(25):
		var angle := sweep_angle - half_arc + (half_arc * 2.0 * float(index) / 24.0)
		points.append(Vector2.RIGHT.rotated(angle) * SWEEP_RANGE)
	ground_fill.draw_colored_polygon(points, Color(WARNING_COLOR, 0.08 if attack_stage == AttackStage.WARNING else 0.14))

func _draw_slam() -> void:
	for world_target in slam_targets:
		var local_target := to_local(world_target)
		draw_arc(local_target, SLAM_RADIUS, 0.0, TAU, 36, OUTLINE_COLOR, 5.0, true)
		draw_arc(local_target, SLAM_RADIUS, 0.0, TAU, 36, WARNING_COLOR, 3.0, true)
		for axis in [Vector2.RIGHT, Vector2.DOWN]:
			draw_line(local_target - axis * 12.0, local_target + axis * 12.0, OUTLINE_COLOR, 4.0, true)
			draw_line(local_target - axis * 12.0, local_target + axis * 12.0, WARNING_COLOR, 2.0, true)
