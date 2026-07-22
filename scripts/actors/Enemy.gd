extends CharacterBody2D
class_name Enemy

signal died(enemy: Node, coin_value: int, source: StringName)
signal hit(source: StringName)
signal damage_resolved(
	enemy: Node,
	source: StringName,
	amount: float,
	world_position: Vector2,
	direction: Vector2,
	killed: bool
)

const ProjectileScript = preload("res://scripts/components/Projectile.gd")
const HealthComponentScript = preload("res://scripts/components/HealthComponent.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")

const RANGED_SAFE_MARGIN := 48.0
const RANGED_MIN_DISTANCE_FLOOR := 160.0
const RANGED_MIN_VIEW_FRACTION := 0.38
const RANGED_MAX_VIEW_FRACTION := 0.48

enum EnemyKind { SCRAPPER, DASHER, SPITTER, BRUISER }
enum FeedbackWeight { LIGHT, MEDIUM, HEAVY }

var kind: EnemyKind = EnemyKind.SCRAPPER
var feedback_weight: int = FeedbackWeight.MEDIUM
var speed: float = 90.0
var contact_damage: float = 8.0
var coin_value: int = 1
var shield_drop_value: float = 0.0
var shoot_cooldown: float = 0.0
var health: Node
var projectile_parent: Node
var flash_timer: float = 0.0
var body_radius: float = 14.0
var attack_range: float = 32.0
var attack_windup: float = 0.32
var attack_recovery: float = 0.55
var attack_timer: float = 0.0
var attack_cooldown: float = 0.0
var attack_has_hit: bool = false
var is_attacking: bool = false
var ranged_keep_min: float = 320.0
var ranged_keep_max: float = 520.0
var attack_anchor_position: Vector2 = Vector2.ZERO
var world_bounds: Rect2 = Rect2()
var death_resolved: bool = false
var target_player: Node2D

func setup(enemy_kind: EnemyKind, wave_index: int, projectiles: Node, target: Node2D = null) -> void:
	kind = enemy_kind
	projectile_parent = projectiles
	target_player = target
	var scale_factor := 1.0 + float(wave_index) * 0.13
	match kind:
		EnemyKind.SCRAPPER:
			feedback_weight = FeedbackWeight.MEDIUM
			speed = 80.0 + wave_index * 3.0
			contact_damage = 8.0
			coin_value = 1
			_add_health(36.0 * scale_factor)
		EnemyKind.DASHER:
			feedback_weight = FeedbackWeight.LIGHT
			speed = 145.0 + wave_index * 4.0
			contact_damage = 6.0
			coin_value = 2
			_add_health(22.0 * scale_factor)
		EnemyKind.SPITTER:
			feedback_weight = FeedbackWeight.LIGHT
			speed = 58.0 + wave_index * 2.0
			contact_damage = 5.0
			coin_value = 3
			shoot_cooldown = randf_range(1.0, 2.0)
			_add_health(28.0 * scale_factor)
		EnemyKind.BRUISER:
			feedback_weight = FeedbackWeight.HEAVY
			speed = 54.0 + wave_index * 1.5
			contact_damage = 18.0
			coin_value = 8
			shield_drop_value = 17.0 + wave_index * 1.5
			body_radius = 24.0
			attack_range = 46.0
			attack_windup = 0.5
			attack_recovery = 0.75
			_add_health(300.0 * scale_factor)

func _ready() -> void:
	add_to_group("enemies")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	var player := get_target_player()
	if player == null:
		return
	var to_player: Vector2 = player.global_position - global_position
	var desired: Vector2 = to_player.normalized()
	if kind != EnemyKind.SPITTER:
		_update_melee_attack(delta, player, to_player.length())
		if is_attacking:
			velocity = Vector2.ZERO
			global_position = attack_anchor_position
			if flash_timer > 0.0:
				flash_timer -= delta
			queue_redraw()
			return
	else:
		desired = _get_ranged_desired_velocity(to_player, get_camera_safe_rect())
	velocity = desired * speed
	move_and_slide()
	_clamp_to_world_bounds()
	if kind == EnemyKind.SPITTER:
		_update_spitter(delta, player)
	if flash_timer > 0.0:
		flash_timer = maxf(0.0, flash_timer - delta)
		queue_redraw()

func get_target_player() -> Node2D:
	if is_instance_valid(target_player):
		return target_player
	return get_tree().get_first_node_in_group("player") as Node2D

func get_camera_safe_rect() -> Rect2:
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	var camera := viewport.get_camera_2d()
	var center := global_position
	var zoom := Vector2.ONE
	if camera != null:
		center = camera.get_screen_center_position()
		zoom = camera.zoom.abs()
	var visible_size := Vector2(
		viewport_size.x / maxf(zoom.x, 0.001),
		viewport_size.y / maxf(zoom.y, 0.001)
	)
	var safe_rect := Rect2(center - visible_size * 0.5, visible_size).grow(-RANGED_SAFE_MARGIN)
	if world_bounds.size != Vector2.ZERO:
		safe_rect = safe_rect.intersection(world_bounds.grow(-body_radius))
	return safe_rect

func get_dynamic_ranged_min_distance(safe_rect: Rect2) -> float:
	return calculate_dynamic_ranged_min_distance(safe_rect, ranged_keep_min)

func get_dynamic_ranged_max_distance(safe_rect: Rect2) -> float:
	var minimum := get_dynamic_ranged_min_distance(safe_rect)
	var visible_span := minf(safe_rect.size.x, safe_rect.size.y)
	return minf(ranged_keep_max, maxf(minimum + 80.0, visible_span * RANGED_MAX_VIEW_FRACTION))

static func calculate_dynamic_ranged_min_distance(safe_rect: Rect2, configured_maximum: float = 320.0) -> float:
	var visible_span := minf(safe_rect.size.x, safe_rect.size.y)
	return minf(configured_maximum, maxf(RANGED_MIN_DISTANCE_FLOOR, visible_span * RANGED_MIN_VIEW_FRACTION))

static func calculate_dynamic_ranged_max_distance(
	safe_rect: Rect2,
	configured_minimum_max: float = 320.0,
	configured_maximum: float = 520.0
) -> float:
	var minimum := calculate_dynamic_ranged_min_distance(safe_rect, configured_minimum_max)
	var visible_span := minf(safe_rect.size.x, safe_rect.size.y)
	return minf(configured_maximum, maxf(minimum + 80.0, visible_span * RANGED_MAX_VIEW_FRACTION))

func _get_ranged_desired_velocity(to_player: Vector2, safe_rect: Rect2 = Rect2()) -> Vector2:
	if safe_rect.size == Vector2.ZERO:
		safe_rect = get_camera_safe_rect()
	if not safe_rect.has_point(global_position):
		var return_target := global_position.clamp(safe_rect.position, safe_rect.end)
		if return_target.distance_squared_to(global_position) <= 0.001:
			return_target = safe_rect.get_center()
		return (return_target - global_position).normalized()
	var distance := to_player.length()
	if distance <= 0.01:
		return constrain_ranged_direction(Vector2.RIGHT, safe_rect)
	var toward_player := to_player / distance
	var dynamic_minimum := get_dynamic_ranged_min_distance(safe_rect)
	var dynamic_maximum := get_dynamic_ranged_max_distance(safe_rect)
	if distance < dynamic_minimum:
		return constrain_ranged_direction(-toward_player, safe_rect)
	if distance > dynamic_maximum:
		return constrain_ranged_direction(toward_player * 0.65, safe_rect)
	var strafe_side := 1.0
	if int(Time.get_ticks_msec() / 1400 + get_instance_id()) % 2 == 0:
		strafe_side = -1.0
	return constrain_ranged_direction(toward_player.orthogonal() * strafe_side * 0.28, safe_rect)

func constrain_ranged_direction(direction: Vector2, safe_rect: Rect2) -> Vector2:
	if direction == Vector2.ZERO or safe_rect.size == Vector2.ZERO:
		return Vector2.ZERO
	var movement_rect := safe_rect.grow(-body_radius)
	if movement_rect.size.x <= 0.0 or movement_rect.size.y <= 0.0:
		return (safe_rect.get_center() - global_position).normalized()
	var lookahead := maxf(24.0, speed * 0.25)
	var target := global_position + direction.normalized() * lookahead
	var constrained_target := target.clamp(movement_rect.position, movement_rect.end)
	if constrained_target.distance_squared_to(target) <= 0.001:
		return direction
	var correction := constrained_target - global_position
	if correction.length_squared() <= 0.001:
		return (movement_rect.get_center() - global_position).normalized() * direction.length()
	return correction.normalized() * direction.length()

func _is_in_visible_engagement_zone(player: Node2D) -> bool:
	var safe_rect := get_camera_safe_rect()
	if safe_rect.size == Vector2.ZERO or not safe_rect.has_point(global_position):
		return false
	var distance := global_position.distance_to(player.global_position)
	return distance >= get_dynamic_ranged_min_distance(safe_rect) and distance <= get_dynamic_ranged_max_distance(safe_rect)

func _draw() -> void:
	var body_color := Color(0.84, 0.18, 0.16)
	var accent := Color(1.0, 0.72, 0.1)
	if kind == EnemyKind.DASHER:
		body_color = Color(0.96, 0.35, 0.75)
		accent = Color(0.2, 1.0, 0.95)
	elif kind == EnemyKind.SPITTER:
		body_color = Color(0.18, 0.9, 0.42)
		accent = Color(0.7, 0.2, 1.0)
	elif kind == EnemyKind.BRUISER:
		body_color = Color(0.46, 0.12, 0.68)
		accent = Color(0.25, 1.0, 0.35)
	if flash_timer > 0.0:
		body_color = Color.WHITE
	var size := body_radius * 1.7
	draw_rect(Rect2(Vector2(-size * 0.5, -size * 0.5), Vector2(size, size)), body_color)
	draw_rect(Rect2(-body_radius * 0.55, -body_radius - 3, body_radius * 1.1, 5), accent)
	draw_rect(Rect2(-body_radius - 2, -3, (body_radius + 2) * 2.0, 6), body_color.darkened(0.25))
	if is_attacking:
		var p := 1.0 - clampf(attack_timer / maxf(0.01, attack_windup), 0.0, 1.0)
		draw_arc(Vector2.ZERO, attack_range, -PI * 0.85, PI * 0.85, 24, Color(1.0, 0.55, 0.15, 0.25 + p * 0.45), 4.0)
	draw_rect(Rect2(-5, -5, 4, 4), Color.BLACK)
	draw_rect(Rect2(3, -5, 4, 4), Color.BLACK)

func take_damage(
	amount: float,
	source: StringName = DamageTypes.GENERIC,
	hit_direction: Vector2 = Vector2.ZERO
) -> bool:
	if health == null or death_resolved:
		return false
	var health_before: float = health.current_health
	if not health.damage(amount):
		return false
	var resolved_source: StringName = DamageTypes.resolve(source)
	var actual_damage: float = maxf(0.0, health_before - health.current_health)
	var killed: bool = health.current_health <= 0.0
	flash_timer = 0.08
	queue_redraw()
	damage_resolved.emit(
		self,
		resolved_source,
		actual_damage,
		global_position,
		hit_direction,
		killed
	)
	hit.emit(resolved_source)
	if killed:
		_die(resolved_source)
	return killed

func _add_health(max_health: float) -> void:
	health = HealthComponentScript.new()
	health.max_health = max_health
	add_child(health)

func get_feedback_weight() -> int:
	return feedback_weight

func _die(source: StringName) -> void:
	if death_resolved:
		return
	death_resolved = true
	died.emit(self, coin_value, source)
	queue_free()

func _update_melee_attack(delta: float, player: Node2D, distance: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if not is_attacking and attack_cooldown <= 0.0 and distance <= attack_range:
		is_attacking = true
		attack_anchor_position = global_position
		attack_timer = attack_windup
		attack_has_hit = false
	if not is_attacking:
		return
	attack_timer -= delta
	if not attack_has_hit and attack_timer <= 0.0:
		attack_has_hit = true
		if global_position.distance_to(player.global_position) <= attack_range + 8.0 and player.has_method("take_damage"):
			player.take_damage(contact_damage)
	if attack_timer <= -attack_recovery:
		is_attacking = false
		attack_cooldown = 0.15
		queue_redraw()

func _update_spitter(delta: float, player: Node2D) -> void:
	if not _is_in_visible_engagement_zone(player):
		return
	shoot_cooldown -= delta
	if shoot_cooldown > 0.0 or projectile_parent == null:
		return
	shoot_cooldown = randf_range(1.8, 2.7)
	var shot := ProjectileScript.new()
	shot.global_position = global_position
	shot.velocity = (player.global_position - global_position).normalized() * 260.0
	shot.damage = 7.0
	shot.radius = 5.0
	shot.lifetime = 6.0
	shot.target_group = &"player"
	shot.tint = Color(0.55, 1.0, 0.2)
	shot.world_bounds = world_bounds
	projectile_parent.add_child(shot)

func _clamp_to_world_bounds() -> void:
	if world_bounds.size == Vector2.ZERO:
		return
	var playable := world_bounds.grow(-body_radius)
	global_position = global_position.clamp(playable.position, playable.end)
