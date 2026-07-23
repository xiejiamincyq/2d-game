extends Node2D
class_name TentacleAttack

const ProjectileScript = preload("res://scripts/components/Projectile.gd")

const WARNING_COLOR := Color("ff571f")
const SWEEP_WARNING_SECONDS := 0.65
const SWEEP_ACTIVE_SECONDS := 0.22
const SWEEP_RANGE := 300.0
const SWEEP_ARC_DEGREES := 78.0
const SWEEP_DAMAGE := 18.0
const SLAM_WARNING_SECONDS := 0.75
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

func configure(owner_boss: Node2D, target: Node2D, projectiles: Node) -> void:
	boss = owner_boss
	target_player = target
	projectile_parent = projectiles

func _ready() -> void:
	set_physics_process(false)
	queue_redraw()

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
	queue_redraw()
	return true

func start_slam(target_positions: Array[Vector2]) -> bool:
	if not _can_start_attack() or not _are_valid_slam_targets(target_positions):
		return false
	slam_targets.assign(target_positions)
	attack_kind = AttackKind.SLAM
	attack_stage = AttackStage.WARNING
	elapsed = 0.0
	set_physics_process(true)
	queue_redraw()
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
			queue_redraw()
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
	queue_redraw()

func cancel_attack() -> void:
	attack_kind = AttackKind.NONE
	attack_stage = AttackStage.IDLE
	elapsed = 0.0
	slam_targets.clear()
	sweep_hit_player = false
	set_physics_process(false)
	cleanup_projectiles()
	queue_redraw()

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
	queue_redraw()

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
	var points := PackedVector2Array([Vector2.ZERO])
	for index in range(25):
		var angle := sweep_angle - half_arc + (half_arc * 2.0 * float(index) / 24.0)
		points.append(Vector2.RIGHT.rotated(angle) * SWEEP_RANGE)
	var fill_alpha := 0.18 if attack_stage == AttackStage.WARNING else 0.38
	draw_colored_polygon(points, Color(WARNING_COLOR, fill_alpha))
	draw_arc(Vector2.ZERO, SWEEP_RANGE, sweep_angle - half_arc, sweep_angle + half_arc, 24, Color(WARNING_COLOR, 0.9), 3.0)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(sweep_angle - half_arc) * SWEEP_RANGE, Color(WARNING_COLOR, 0.75), 2.0)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(sweep_angle + half_arc) * SWEEP_RANGE, Color(WARNING_COLOR, 0.75), 2.0)

func _draw_slam() -> void:
	for world_target in slam_targets:
		var local_target := to_local(world_target)
		draw_circle(local_target, SLAM_RADIUS, Color(WARNING_COLOR, 0.16))
		draw_arc(local_target, SLAM_RADIUS, 0.0, TAU, 36, Color(WARNING_COLOR, 0.92), 3.0)
		draw_line(local_target - Vector2(12.0, 0.0), local_target + Vector2(12.0, 0.0), Color(WARNING_COLOR, 0.8), 2.0)
		draw_line(local_target - Vector2(0.0, 12.0), local_target + Vector2(0.0, 12.0), Color(WARNING_COLOR, 0.8), 2.0)
