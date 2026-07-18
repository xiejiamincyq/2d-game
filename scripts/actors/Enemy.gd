extends CharacterBody2D
class_name Enemy

signal died(enemy: Node, xp_value: int, source: StringName)
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

enum EnemyKind { SCRAPPER, DASHER, SPITTER, BRUISER }

var kind: EnemyKind = EnemyKind.SCRAPPER
var speed: float = 90.0
var contact_damage: float = 8.0
var xp_value: int = 1
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

func setup(enemy_kind: EnemyKind, wave_index: int, projectiles: Node) -> void:
	kind = enemy_kind
	projectile_parent = projectiles
	var scale_factor := 1.0 + float(wave_index) * 0.13
	match kind:
		EnemyKind.SCRAPPER:
			speed = 80.0 + wave_index * 3.0
			contact_damage = 8.0
			xp_value = 1
			_add_health(36.0 * scale_factor)
		EnemyKind.DASHER:
			speed = 145.0 + wave_index * 4.0
			contact_damage = 6.0
			xp_value = 2
			_add_health(22.0 * scale_factor)
		EnemyKind.SPITTER:
			speed = 58.0 + wave_index * 2.0
			contact_damage = 5.0
			xp_value = 3
			shoot_cooldown = randf_range(1.0, 2.0)
			_add_health(28.0 * scale_factor)
		EnemyKind.BRUISER:
			speed = 54.0 + wave_index * 1.5
			contact_damage = 18.0
			xp_value = 8
			shield_drop_value = 17.0 + wave_index * 1.5
			body_radius = 24.0
			attack_range = 46.0
			attack_windup = 0.5
			attack_recovery = 0.75
			_add_health(250.0 * scale_factor)
	var wave_multiplier := 1.0 + 0.15 * float(maxi(1, wave_index) - 1)
	xp_value = maxi(1, int(round(float(xp_value) * wave_multiplier)))

func _ready() -> void:
	add_to_group("enemies")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
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
		desired = _get_ranged_desired_velocity(to_player)
	velocity = desired * speed
	move_and_slide()
	_clamp_to_world_bounds()
	if kind == EnemyKind.SPITTER:
		_update_spitter(delta, player)
	if flash_timer > 0.0:
		flash_timer = maxf(0.0, flash_timer - delta)
		queue_redraw()

func _get_ranged_desired_velocity(to_player: Vector2) -> Vector2:
	var distance := to_player.length()
	if distance <= 0.01:
		return Vector2.RIGHT
	var toward_player := to_player / distance
	if distance < ranged_keep_min:
		return -toward_player
	if distance > ranged_keep_max:
		return toward_player * 0.35
	var strafe_side := 1.0
	if int(Time.get_ticks_msec() / 1400 + get_instance_id()) % 2 == 0:
		strafe_side = -1.0
	return toward_player.orthogonal() * strafe_side * 0.28

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

func _die(source: StringName) -> void:
	if death_resolved:
		return
	death_resolved = true
	died.emit(self, xp_value, source)
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
