extends RefCounted
const Drawing = preload("res://scripts/effects/HostileAttackDrawing.gd")

# Only basic chasers use these locked, dodgeable strikes. The actor owns motion
# and collision; this controller never teleports or modifies player damage rules.
enum Move { CLAW, POUNCE }
enum Stage { IDLE, WARNING, ACTIVE, RECOVERY }
const CLAW_RADIUS := 64.0
const CLAW_HALF_ANGLE := PI / 5.0
const POUNCE_SPEED := 330.0
const POUNCE_DURATION := 0.30
const COOLDOWN := 4.0
const CLAW_WARNING := 0.22
const POUNCE_WARNING := 0.30
const CLAW_ACTIVE := 0.12
const RECOVERY := 0.20
var stage := Stage.IDLE
var move := Move.CLAW
var elapsed := 0.0
var cooldown := 1.6
var direction := Vector2.RIGHT
var origin := Vector2.ZERO
var did_hit := false
var next_move := Move.CLAW
var target_radius := 14.0

func is_active() -> bool:
	return stage != Stage.IDLE

func cancel() -> void:
	stage = Stage.IDLE
	# Preserve the old full cycle while releasing movement sooner.
	cooldown = COOLDOWN + get_released_delay()
	did_hit = false

func get_warning_duration() -> float:
	return CLAW_WARNING if move == Move.CLAW else POUNCE_WARNING

func get_active_duration() -> float:
	return CLAW_ACTIVE if move == Move.CLAW else POUNCE_DURATION

func get_released_delay() -> float:
	return (0.5 if move == Move.CLAW else 0.6) - get_warning_duration() + 0.4 - RECOVERY

func begin(actor: Node2D, target: Node2D, chosen: int) -> bool:
	if is_active() or not is_instance_valid(target):
		return false
	move = chosen
	var target_collision := target.get_node_or_null("PlayerCollision") as CollisionShape2D
	target_radius = 14.0
	if target_collision != null and target_collision.shape is CircleShape2D:
		target_radius = (target_collision.shape as CircleShape2D).radius
	direction = actor.global_position.direction_to(target.global_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	origin = actor.global_position
	stage = Stage.WARNING
	elapsed = 0.0
	did_hit = false
	return true

func consider(actor: Node2D, target: Node2D, delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0 or is_active():
		return
	var distance := actor.global_position.distance_to(target.global_position)
	if distance > 36.0 and distance <= CLAW_RADIUS and next_move == Move.CLAW:
		begin(actor, target, Move.CLAW)
	elif distance >= 80.0 and distance <= POUNCE_SPEED * POUNCE_DURATION + get_contact_reach(actor) - 2.0:
		begin(actor, target, Move.POUNCE)
	elif distance > 36.0 and distance <= CLAW_RADIUS:
		begin(actor, target, Move.CLAW)

func advance(delta: float) -> void:
	if not is_active():
		return
	elapsed += maxf(0.0, delta)
	var warning := get_warning_duration()
	var active := get_active_duration()
	if elapsed >= warning + active + RECOVERY:
		next_move = Move.POUNCE if move == Move.CLAW else Move.CLAW
		cancel()
	elif elapsed >= warning + active:
		stage = Stage.RECOVERY
	elif elapsed >= warning:
		stage = Stage.ACTIVE

func get_velocity() -> Vector2:
	return direction * POUNCE_SPEED if stage == Stage.ACTIVE and move == Move.POUNCE else Vector2.ZERO

func finish_motion() -> void:
	if stage == Stage.ACTIVE and move == Move.POUNCE:
		stage = Stage.RECOVERY
		elapsed = get_warning_duration() + POUNCE_DURATION

func is_point_in_warning(actor: Node2D, point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point - actor.global_position, get_warning_polygon(actor))

func get_contact_reach(actor: CharacterBody2D) -> float:
	# Collision stops at the sum of both radii. Include its safe margin rather
	# than requiring bodies to overlap to deal damage.
	return actor.body_radius + target_radius + actor.safe_margin + 0.5

func resolve_hit(actor: CharacterBody2D, target: Node2D) -> void:
	if stage != Stage.ACTIVE or did_hit or not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	var offset := target.global_position - actor.global_position
	var in_reach: bool = offset.length() <= get_contact_reach(actor)
	if move == Move.CLAW:
		in_reach = true # Fixed claw origin, not an actor displaced by a crowd.
	if not in_reach or not is_point_in_warning(actor, target.global_position):
		return
	# A claw cannot damage through an obstacle, either.
	var ray_origin := origin if move == Move.CLAW else actor.global_position
	var ray := PhysicsRayQueryParameters2D.create(ray_origin, target.global_position, actor.collision_mask, [actor.get_rid()])
	var blocker := actor.get_world_2d().direct_space_state.intersect_ray(ray)
	if not blocker.is_empty() and blocker.collider != target:
		return
	did_hit = true
	target.take_damage(actor.contact_damage)

func get_warning_polygon(actor: Node2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	var base := origin - actor.global_position
	if move == Move.CLAW:
		points.append(base)
		for index in range(17):
			points.append(base + direction.rotated(lerpf(-CLAW_HALF_ANGLE, CLAW_HALF_ANGLE, index / 16.0)) * CLAW_RADIUS)
	else:
		var end := base + direction * POUNCE_SPEED * POUNCE_DURATION
		# Warn the full player-center hit corridor, including both end caps.
		var reach := get_contact_reach(actor)
		for index in range(13):
			points.append(end + direction.rotated(lerpf(-PI * 0.5, PI * 0.5, index / 12.0)) * reach)
		for index in range(13):
			points.append(base + direction.rotated(lerpf(PI * 0.5, PI * 1.5, index / 12.0)) * reach)
	return points

func draw_warning(canvas: Node2D, actor: Node2D) -> void:
	if stage != Stage.ACTIVE:
		return
	Drawing.draw_strokes(canvas, get_attack_strokes(actor))

func get_attack_strokes(actor: Node2D) -> Array[PackedVector2Array]:
	if stage != Stage.ACTIVE:
		return []
	var base := origin - actor.global_position
	if move == Move.CLAW:
		return Drawing.claw_strokes(base, direction, (elapsed - get_warning_duration()) / CLAW_ACTIVE, CLAW_RADIUS, CLAW_HALF_ANGLE)
	var strokes: Array[PackedVector2Array] = []
	var traveled := clampf((actor.global_position - origin).dot(direction), 0.0, POUNCE_SPEED * POUNCE_DURATION)
	var tail_end := maxf(0.0, traveled - actor.body_radius * 0.90)
	var tail_start := maxf(0.0, tail_end - actor.body_radius * 2.5)
	for offset in [0.0]:
		var side: Vector2 = direction.orthogonal() * actor.body_radius * float(offset)
		strokes.append(PackedVector2Array([base + direction * tail_start + side, base + direction * tail_end + side]))
	return strokes
