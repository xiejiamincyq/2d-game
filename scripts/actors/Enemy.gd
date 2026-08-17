extends CharacterBody2D
class_name Enemy

signal died(enemy: Node, coin_value: int, source: StringName)
signal hit(source: StringName)
signal reinforcements_requested(enemy: Node, count: int)
signal damage_resolved(
	enemy: Node,
	source: StringName,
	amount: float,
	world_position: Vector2,
	direction: Vector2,
	killed: bool
)

const ProjectileScript = preload("res://scripts/components/Projectile.gd")
const LobbedProjectileScript = preload("res://scripts/components/LobbedProjectile.gd")
const HealthComponentScript = preload("res://scripts/components/HealthComponent.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const BurnStatusScript = preload("res://scripts/components/BurnStatus.gd")
const DASHER_TEXTURES := [
	preload("res://assets/art/actors/enemies/enemy_dasher_a_actions_runtime_v1.png"),
	preload("res://assets/art/actors/enemies/enemy_dasher_b_actions_runtime_v1.png"),
]
const DASHER_FLASH_SHADER := preload("res://assets/art/shaders/dasher_hit_flash.gdshader")

const DASHER_RUNTIME_SCALE := Vector2(0.125, 0.125)
const DASHER_RUN_FPS := 9.0
const DASHER_RUN_SEQUENCE := [0, 1, 2, 1]

const RANGED_SAFE_MARGIN := 48.0
const RANGED_MIN_DISTANCE_FLOOR := 160.0
const RANGED_MIN_VIEW_FRACTION := 0.38
const RANGED_MAX_VIEW_FRACTION := 0.48
const ENEMY_PROJECTILE_BASE_SPEED := 260.0
const MARKSMAN_PROJECTILE_SPEED_MULTIPLIER := 3.5
const MARKSMAN_TELEGRAPH_SECONDS := 0.5
const MARKSMAN_TELEGRAPH_LENGTH := 1400.0
const BASE_MOVE_SPEED_MULTIPLIER := 1.10
const MELEE_ENEMY_SPEED := 235.0 * 0.90
const DASHER_ENEMY_SPEED := 235.0 * 1.10
const RANGED_ENEMY_SPEED := 235.0 * 0.60
const HIDDEN_DISPERSAL_SPEED_SCALE := 0.72
const MELEE_SEPARATION_PADDING := 48.0
const MELEE_SEPARATION_WEIGHT := 3.00
const MELEE_SURROUND_DISTANCE := 560.0
const MELEE_SURROUND_MAX_BLEND := 1.20
const GOLDEN_ANGLE := 2.399963229728653

enum EnemyKind { SCRAPPER, DASHER, SPITTER, BRUISER, MARKSMAN, LOBBER, OVERSEER }
enum FeedbackWeight { LIGHT, MEDIUM, HEAVY }
enum DasherAnimationState { IDLE, MOVE, ATTACK }

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
var ranged_is_winding_up := false
var ranged_windup_duration := 0.5
var ranged_windup_remaining := 0.0
var ranged_target_position := Vector2.ZERO
var boss_reinforcement_mask := 0
var spawn_impulse_velocity := Vector2.ZERO
var spawn_impulse_remaining := 0.0
var burn_status: RefCounted = BurnStatusScript.new()
var hidden_dispersion_direction := Vector2.ZERO
var hidden_dispersion_timer := 0.0
var neighbor_provider: Callable
var dasher_variant_index: int = 0
var dasher_visual: Sprite2D
var dasher_flash_material: ShaderMaterial
var dasher_animation_state := DasherAnimationState.IDLE
var dasher_animation_elapsed := 0.0
var dasher_animation_phase_offset := 0.0

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
			dasher_variant_index = randi_range(0, DASHER_TEXTURES.size() - 1)
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
		EnemyKind.MARKSMAN:
			feedback_weight = FeedbackWeight.LIGHT
			speed = 62.0 + wave_index * 1.5
			contact_damage = 5.0
			coin_value = 5
			shoot_cooldown = randf_range(0.8, 1.4)
			ranged_windup_duration = MARKSMAN_TELEGRAPH_SECONDS
			ranged_keep_min = 260.0
			ranged_keep_max = 500.0
			_add_health(44.0 * scale_factor)
		EnemyKind.LOBBER:
			feedback_weight = FeedbackWeight.MEDIUM
			speed = 48.0 + wave_index * 1.2
			contact_damage = 8.0
			coin_value = 7
			shoot_cooldown = randf_range(1.0, 1.8)
			ranged_windup_duration = 0.72
			ranged_keep_min = 230.0
			ranged_keep_max = 460.0
			body_radius = 17.0
			_add_health(72.0 * scale_factor)
		EnemyKind.OVERSEER:
			feedback_weight = FeedbackWeight.HEAVY
			speed = 42.0
			contact_damage = 24.0
			coin_value = 60
			body_radius = 40.0
			attack_range = 64.0
			shoot_cooldown = 2.4
			ranged_windup_duration = 0.9
			_add_health(1800.0 * scale_factor)
	if kind in [EnemyKind.BRUISER, EnemyKind.OVERSEER]:
		speed *= BASE_MOVE_SPEED_MULTIPLIER
	elif kind == EnemyKind.DASHER:
		speed = DASHER_ENEMY_SPEED
	elif is_ranged_kind():
		speed = RANGED_ENEMY_SPEED
	else:
		speed = MELEE_ENEMY_SPEED

func _ready() -> void:
	add_to_group("enemies")
	if kind == EnemyKind.DASHER:
		_create_dasher_visual()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	_update_burn(delta)
	if death_resolved:
		return
	if spawn_impulse_remaining > 0.0:
		velocity = spawn_impulse_velocity
		move_and_slide()
		_clamp_to_world_bounds()
		_update_dasher_animation(delta)
		spawn_impulse_remaining = maxf(0.0, spawn_impulse_remaining - delta)
		if is_zero_approx(spawn_impulse_remaining):
			spawn_impulse_velocity = Vector2.ZERO
		return
	var player := get_target_player()
	if player == null:
		if is_target_hidden():
			_update_hidden_target_dispersion(delta)
		else:
			velocity = Vector2.ZERO
		_update_dasher_animation(delta)
		return
	hidden_dispersion_timer = 0.0
	var to_player: Vector2 = player.global_position - global_position
	var desired: Vector2 = to_player.normalized()
	_update_dasher_facing(player.global_position)
	if kind == EnemyKind.OVERSEER:
		_update_overseer(delta, player, to_player.length())
		if is_attacking or ranged_is_winding_up:
			desired = Vector2.ZERO
	elif is_ranged_kind():
		desired = _get_ranged_desired_velocity(to_player, get_camera_safe_rect())
	else:
		_update_melee_attack(delta, player, to_player.length())
		if is_attacking:
			velocity = Vector2.ZERO
			global_position = attack_anchor_position
			_update_dasher_animation(delta)
			if flash_timer > 0.0:
				flash_timer -= delta
			_update_dasher_hit_flash()
			queue_redraw()
			return
		desired = _get_melee_desired_velocity(to_player)
	velocity = desired * get_effective_move_speed()
	move_and_slide()
	_clamp_to_world_bounds()
	match kind:
		EnemyKind.SPITTER:
			_update_spitter(delta, player)
		EnemyKind.MARKSMAN:
			_update_marksman(delta, player)
		EnemyKind.LOBBER:
			_update_lobber(delta, player)
	if flash_timer > 0.0:
		flash_timer = maxf(0.0, flash_timer - delta)
		queue_redraw()
	_update_dasher_hit_flash()
	_update_dasher_animation(delta)

func apply_spawn_impulse(initial_velocity: Vector2, duration: float, elapsed: float = 0.0) -> void:
	var simulated_elapsed := clampf(elapsed, 0.0, maxf(0.0, duration))
	global_position += initial_velocity * simulated_elapsed
	spawn_impulse_velocity = initial_velocity
	spawn_impulse_remaining = maxf(0.0, duration - simulated_elapsed)
	velocity = initial_velocity if spawn_impulse_remaining > 0.0 else Vector2.ZERO

func get_target_player() -> Node2D:
	var target := target_player if is_instance_valid(target_player) else get_tree().get_first_node_in_group("player") as Node2D
	if target != null and target.has_method("is_stealthed") and bool(target.call("is_stealthed")):
		return null
	return target

func is_target_hidden() -> bool:
	return is_instance_valid(target_player) and target_player.has_method("is_stealthed") and bool(target_player.call("is_stealthed"))

func _update_hidden_target_dispersion(delta: float) -> void:
	hidden_dispersion_timer -= delta
	if hidden_dispersion_timer <= 0.0 or hidden_dispersion_direction == Vector2.ZERO:
		hidden_dispersion_direction = Vector2.RIGHT.rotated(randf() * TAU)
		hidden_dispersion_timer = randf_range(0.7, 1.35)
	velocity = hidden_dispersion_direction * get_effective_move_speed() * HIDDEN_DISPERSAL_SPEED_SCALE
	move_and_slide()
	_clamp_to_world_bounds()

func get_effective_move_speed() -> float:
	return speed * (1.0 - burn_status.get_slow_fraction())

func set_neighbor_provider(provider: Callable) -> void:
	neighbor_provider = provider

func _get_melee_desired_velocity(to_player: Vector2) -> Vector2:
	var distance := to_player.length()
	if distance <= 0.001:
		return _get_melee_separation_direction()
	var pursuit := to_player / distance
	var slot_angle := fposmod(float(get_instance_id() % 64) * GOLDEN_ANGLE, TAU)
	var current_radial := -pursuit
	var slot_angle_error := wrapf(slot_angle - current_radial.angle(), -PI, PI)
	var orbit_direction := current_radial.orthogonal() * signf(slot_angle_error)
	var surround_progress := 1.0 - clampf(
		(distance - attack_range) / maxf(1.0, MELEE_SURROUND_DISTANCE - attack_range),
		0.0,
		1.0
	)
	var angular_urgency := clampf(absf(slot_angle_error) / (PI * 0.5), 0.0, 1.0)
	var formation_direction := (
		pursuit
		+ orbit_direction * angular_urgency * surround_progress * MELEE_SURROUND_MAX_BLEND
	).normalized()
	var separation := _get_melee_separation_direction()
	return (formation_direction + separation * MELEE_SEPARATION_WEIGHT).normalized()

func _get_melee_separation_direction() -> Vector2:
	var separation := Vector2.ZERO
	for candidate in _get_neighbor_candidates():
		var other := candidate as Node2D
		if other == null or other == self or not is_instance_valid(other):
			continue
		var other_radius_value: Variant = other.get("body_radius")
		if other_radius_value == null:
			continue
		var desired_gap := body_radius + float(other_radius_value) + MELEE_SEPARATION_PADDING
		var offset := global_position - other.global_position
		var distance := offset.length()
		if distance >= desired_gap:
			continue
		if distance <= 0.001:
			offset = Vector2.RIGHT if get_instance_id() < other.get_instance_id() else Vector2.LEFT
			distance = 0.0
		separation += offset.normalized() * (1.0 - distance / desired_gap)
	return separation.limit_length(1.0)

func _get_neighbor_candidates() -> Array[Node]:
	if neighbor_provider.is_valid():
		var provided: Variant = neighbor_provider.call()
		if provided is Array:
			var neighbors: Array[Node] = []
			neighbors.assign(provided)
			return neighbors
	return get_tree().get_nodes_in_group("enemies")

func apply_burn_stack(
	base_attack: float,
	duration: float,
	slow_fraction: float = 0.0,
	damage_source: StringName = DamageTypes.BURN
) -> bool:
	return burn_status.apply_stack(base_attack, duration, slow_fraction, damage_source)

func get_burn_stack_count() -> int:
	return burn_status.get_stack_count()

func _update_burn(delta: float) -> void:
	var damage_by_source: Dictionary = burn_status.advance_by_source(delta)
	for damage_source in damage_by_source:
		var burn_damage := float(damage_by_source[damage_source])
		if burn_damage > 0.0:
			take_damage(burn_damage, damage_source)

func is_ranged_kind() -> bool:
	return kind in [EnemyKind.SPITTER, EnemyKind.MARKSMAN, EnemyKind.LOBBER]

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
	if kind == EnemyKind.DASHER and dasher_visual != null:
		if is_attacking:
			var dash_progress := 1.0 - clampf(attack_timer / maxf(0.01, attack_windup), 0.0, 1.0)
			draw_arc(Vector2.ZERO, attack_range, -PI * 0.85, PI * 0.85, 24, Color(1.0, 0.55, 0.15, 0.25 + dash_progress * 0.45), 4.0)
		return
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
	elif kind == EnemyKind.MARKSMAN:
		body_color = Color("24324d")
		accent = Color("33fff2")
	elif kind == EnemyKind.LOBBER:
		body_color = Color("5a214b")
		accent = Color("f559bf")
	elif kind == EnemyKind.OVERSEER:
		body_color = Color("190d2c")
		accent = Color("ff571f")
	if flash_timer > 0.0:
		body_color = Color.WHITE
	var size := body_radius * 1.7
	draw_rect(Rect2(Vector2(-size * 0.5, -size * 0.5), Vector2(size, size)), body_color)
	if kind in [EnemyKind.BRUISER, EnemyKind.OVERSEER]:
		var bar_width := body_radius * 1.6
		var bar_rect := Rect2(-bar_width * 0.5, -body_radius - 12.0, bar_width, 6.0)
		draw_rect(bar_rect, Color("061019"))
		draw_rect(Rect2(bar_rect.position + Vector2.ONE, Vector2((bar_width - 2.0) * get_health_ratio(), 4.0)), accent)
	else:
		draw_rect(Rect2(-body_radius * 0.55, -body_radius - 3, body_radius * 1.1, 5), accent)
	draw_rect(Rect2(-body_radius - 2, -3, (body_radius + 2) * 2.0, 6), body_color.darkened(0.25))
	if is_attacking:
		var p := 1.0 - clampf(attack_timer / maxf(0.01, attack_windup), 0.0, 1.0)
		draw_arc(Vector2.ZERO, attack_range, -PI * 0.85, PI * 0.85, 24, Color(1.0, 0.55, 0.15, 0.25 + p * 0.45), 4.0)
	if ranged_is_winding_up:
		var charge := 1.0 - clampf(ranged_windup_remaining / maxf(0.01, ranged_windup_duration), 0.0, 1.0)
		var warning_color := Color("ff571f") if kind in [EnemyKind.MARKSMAN, EnemyKind.OVERSEER] else accent
		var target_local := to_local(ranged_target_position)
		if kind == EnemyKind.MARKSMAN:
			draw_line(Vector2.ZERO, target_local, Color(0.02, 0.04, 0.06, 0.78), 5.0)
			draw_line(Vector2.ZERO, target_local, Color(warning_color, 0.32 + charge * 0.58), 1.5 + charge * 1.5)
		else:
			draw_line(Vector2.ZERO, target_local, Color(warning_color, 0.25 + charge * 0.55), 2.0 + charge * 2.0)
		if kind == EnemyKind.LOBBER:
			draw_circle(target_local, 72.0, Color(warning_color, 0.06 + charge * 0.08))
			draw_arc(target_local, 72.0, 0.0, TAU, 36, Color(warning_color, 0.5 + charge * 0.4), 2.0)
		elif kind == EnemyKind.OVERSEER:
			draw_arc(Vector2.ZERO, body_radius + 18.0 + charge * 12.0, 0.0, TAU, 40, Color(warning_color, 0.75), 4.0)
	draw_rect(Rect2(-5, -5, 4, 4), Color.BLACK)
	draw_rect(Rect2(3, -5, 4, 4), Color.BLACK)

func set_dasher_variant(index: int) -> void:
	dasher_variant_index = posmod(index, DASHER_TEXTURES.size())
	if dasher_visual != null:
		dasher_visual.texture = DASHER_TEXTURES[dasher_variant_index]

func _create_dasher_visual() -> void:
	dasher_visual = Sprite2D.new()
	dasher_visual.name = "DasherVisual"
	dasher_visual.centered = true
	dasher_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	dasher_visual.scale = DASHER_RUNTIME_SCALE
	dasher_visual.hframes = 3
	dasher_visual.vframes = 2
	dasher_visual.frame = 0
	dasher_visual.texture = DASHER_TEXTURES[dasher_variant_index]
	dasher_animation_phase_offset = float(posmod(int(get_instance_id()), DASHER_RUN_SEQUENCE.size())) / DASHER_RUN_FPS
	dasher_flash_material = ShaderMaterial.new()
	dasher_flash_material.shader = DASHER_FLASH_SHADER
	dasher_flash_material.set_shader_parameter("flash_amount", 0.0)
	dasher_visual.material = dasher_flash_material
	add_child(dasher_visual)

func _update_dasher_facing(target_global_position: Vector2) -> void:
	if dasher_visual == null:
		return
	dasher_visual.flip_h = target_global_position.x < global_position.x

func _update_dasher_hit_flash() -> void:
	if dasher_flash_material == null:
		return
	dasher_flash_material.set_shader_parameter("flash_amount", 1.0 if flash_timer > 0.0 else 0.0)

static func resolve_dasher_animation_frame(
	attacking: bool,
	attack_time: float,
	recovery: float,
	moving: bool,
	elapsed: float
) -> int:
	if attacking:
		if attack_time > 0.0:
			return 3
		if attack_time > -recovery * 0.55:
			return 4
		return 5
	if not moving:
		return 0
	var sequence_index := posmod(floori(maxf(0.0, elapsed) * DASHER_RUN_FPS), DASHER_RUN_SEQUENCE.size())
	return DASHER_RUN_SEQUENCE[sequence_index]

func _update_dasher_animation(delta: float) -> void:
	if dasher_visual == null:
		return
	var next_state := DasherAnimationState.ATTACK if is_attacking else (
		DasherAnimationState.MOVE if velocity.length_squared() > 1.0 else DasherAnimationState.IDLE
	)
	if next_state != dasher_animation_state:
		dasher_animation_state = next_state
		dasher_animation_elapsed = 0.0
	else:
		dasher_animation_elapsed += maxf(0.0, delta)
	dasher_visual.frame = resolve_dasher_animation_frame(
		is_attacking,
		attack_timer,
		attack_recovery,
		next_state == DasherAnimationState.MOVE,
		dasher_animation_elapsed + dasher_animation_phase_offset
	)

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
	_update_dasher_hit_flash()
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

func get_health_ratio() -> float:
	if health == null or float(health.max_health) <= 0.0:
		return 0.0
	return clampf(float(health.current_health) / float(health.max_health), 0.0, 1.0)

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

func _update_marksman(delta: float, player: Node2D) -> void:
	_update_ranged_windup(delta, player, EnemyKind.MARKSMAN)

func _update_lobber(delta: float, player: Node2D) -> void:
	_update_ranged_windup(delta, player, EnemyKind.LOBBER)

func _update_ranged_windup(delta: float, player: Node2D, attack_kind: int) -> void:
	if ranged_is_winding_up:
		ranged_windup_remaining -= delta
		queue_redraw()
		if ranged_windup_remaining <= 0.0:
			ranged_is_winding_up = false
			if attack_kind == EnemyKind.MARKSMAN:
				_fire_marksman(player)
			else:
				_fire_lobber(player)
			queue_redraw()
		return
	if not _is_in_visible_engagement_zone(player):
		return
	shoot_cooldown -= delta
	if shoot_cooldown > 0.0 or projectile_parent == null:
		return
	ranged_is_winding_up = true
	ranged_windup_remaining = ranged_windup_duration
	if attack_kind == EnemyKind.MARKSMAN:
		var aim_direction := (player.global_position - global_position).normalized()
		if aim_direction == Vector2.ZERO:
			aim_direction = Vector2.RIGHT
		ranged_target_position = global_position + aim_direction * MARKSMAN_TELEGRAPH_LENGTH
	else:
		ranged_target_position = player.global_position
	shoot_cooldown = randf_range(1.7, 2.4) if attack_kind == EnemyKind.MARKSMAN else randf_range(2.2, 3.0)
	queue_redraw()

func _fire_marksman(player: Node2D) -> void:
	if projectile_parent == null or not is_instance_valid(player):
		return
	var shot := ProjectileScript.new()
	projectile_parent.add_child(shot)
	shot.global_position = global_position
	shot.velocity = (ranged_target_position - global_position).normalized() * ENEMY_PROJECTILE_BASE_SPEED * MARKSMAN_PROJECTILE_SPEED_MULTIPLIER
	shot.damage = 12.0
	shot.radius = 3.0
	shot.lifetime = 2.0
	shot.target_group = &"player"
	shot.tint = Color("33fff2")
	shot.world_bounds = world_bounds

func _fire_lobber(player: Node2D) -> void:
	if projectile_parent == null or not is_instance_valid(player):
		return
	var shot := LobbedProjectileScript.new()
	projectile_parent.add_child(shot)
	shot.configure(global_position, ranged_target_position, player)
	shot.damage = 16.0
	shot.splash_radius = 72.0
	shot.flight_duration = 0.9

func _update_overseer(delta: float, player: Node2D, distance: float) -> void:
	_request_boss_reinforcements_at_health_thresholds()
	if ranged_is_winding_up:
		ranged_windup_remaining -= delta
		queue_redraw()
		if ranged_windup_remaining <= 0.0:
			ranged_is_winding_up = false
			_fire_overseer_burst()
			queue_redraw()
		return
	shoot_cooldown -= delta
	if shoot_cooldown <= 0.0 and projectile_parent != null and distance <= 520.0:
		ranged_is_winding_up = true
		ranged_windup_remaining = ranged_windup_duration
		ranged_target_position = player.global_position
		shoot_cooldown = 3.4
		queue_redraw()
		return
	_update_melee_attack(delta, player, distance)

func _request_boss_reinforcements_at_health_thresholds() -> void:
	if health == null or health.max_health <= 0.0:
		return
	var ratio: float = health.current_health / health.max_health
	if ratio <= 0.66 and (boss_reinforcement_mask & 1) == 0:
		boss_reinforcement_mask |= 1
		reinforcements_requested.emit(self, 18)
	if ratio <= 0.33 and (boss_reinforcement_mask & 2) == 0:
		boss_reinforcement_mask |= 2
		reinforcements_requested.emit(self, 24)

func _fire_overseer_burst() -> void:
	if projectile_parent == null:
		return
	for index in range(12):
		var shot := ProjectileScript.new()
		projectile_parent.add_child(shot)
		shot.global_position = global_position
		shot.velocity = Vector2.RIGHT.rotated(TAU * float(index) / 12.0) * 310.0
		shot.damage = 10.0
		shot.radius = 5.0
		shot.lifetime = 3.0
		shot.target_group = &"player"
		shot.tint = Color("ff571f")
		shot.world_bounds = world_bounds

func _clamp_to_world_bounds() -> void:
	if world_bounds.size == Vector2.ZERO:
		return
	var playable := world_bounds.grow(-body_radius)
	global_position = global_position.clamp(playable.position, playable.end)
