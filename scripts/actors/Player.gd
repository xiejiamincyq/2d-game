extends CharacterBody2D
class_name Player

signal health_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal died
signal fired(projectile: Node)
signal laser_active_changed(active: bool)
signal entrance_finished

const ProjectileScript = preload("res://scripts/components/Projectile.gd")
const GrenadeProjectileScript = preload("res://scripts/components/GrenadeProjectile.gd")
const HealthComponentScript = preload("res://scripts/components/HealthComponent.gd")
const LaserBeamScript = preload("res://scripts/components/LaserBeam.gd")
const SpikeTrapScript = preload("res://scripts/components/SpikeTrap.gd")
const ArcPulseVisualScript = preload("res://scripts/components/ArcPulseVisual.gd")
const FlameTrailScript = preload("res://scripts/components/FlameTrail.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const ALL_DAMAGE_SOURCES: StringName = &"all"
const OVERDRIVE_MODIFIER: StringName = &"overdrive"
const DASH_IMMUNITY_SOURCE: StringName = &"dash"
const OVERDRIVE_FIRE_RATE_MULTIPLIER: float = 2.0
const OVERDRIVE_DAMAGE_MULTIPLIER: float = 1.2
const OVERDRIVE_SPIKE_DAMAGE_MULTIPLIER: float = 2.0
const OVERDRIVE_LASER_DAMAGE_MULTIPLIER: float = 2.0
const OVERDRIVE_ARC_DAMAGE_MULTIPLIER: float = 1.0
const OVERDRIVE_MOVE_SPEED_MULTIPLIER: float = 1.3
const OVERDRIVE_DASH_COOLDOWN_MULTIPLIER: float = 0.7
const OVERDRIVE_SPIKE_RADIUS_MULTIPLIER: float = 2.0
const OVERDRIVE_SPIKE_DURATION_MULTIPLIER: float = 1.5
const OVERDRIVE_LASER_WIDTH_MULTIPLIER: float = 1.5
const OVERDRIVE_ARC_RADIUS_MULTIPLIER: float = 2.0
const OVERDRIVE_ARC_FREQUENCY_MULTIPLIER: float = 1.5
const BASE_DRONE_LASER_WIDTH: float = 4.0
const BASE_DRONE_LASER_COLOR := Color(0.2, 1.0, 0.95)
const THUNDER_MATRIX_LASER_COLOR := Color("b45cff")
const THUNDER_MATRIX_DRONE_DAMAGE_MULTIPLIER := 1.8
const THUNDER_MATRIX_ARC_DAMAGE_MULTIPLIER := 0.70
const DRONE_BURN_STACK_INTERVAL := 0.20
const DRONE_BURN_SECONDS := 4.0
const DRONE_MAX_TURN_SPEED_RADIANS := PI / 6.0
const ARC_EXPANSION_SPEED_SCALE: float = 0.5
const ARC_DAMAGE_PER_LEVEL: float = 5.4
const PLAYER_SIZE_SCALE: float = 1.3
const BASE_BODY_RADIUS: float = 13.0
const BODY_RADIUS: float = BASE_BODY_RADIUS * PLAYER_SIZE_SCALE
const PROJECTILE_SPAWN_OFFSET: float = 25.0 * PLAYER_SIZE_SCALE
const MAX_WEAPON_LINES: int = 8
const MAX_FIRE_RATE_MULTIPLIER: float = 4.0
const FAMILY_DAMAGE_PER_LEVEL: float = 1.05
const GRENADE_RATE_MULTIPLIER := 0.20
const GRENADE_SPEED_MULTIPLIER := 0.40
const GRENADE_DAMAGE_MULTIPLIER := 3.0
const ASSASSIN_STEALTH_SECONDS := 1.2
const ASSASSIN_SPEED_MULTIPLIER := 1.30
const ASSASSIN_FLAME_SPACING := 30.0
const DASH_BAR_WIDTH := 54.0
const BASE_MOVE_SPEED := 235.0
const ENTRANCE_FALL_SECONDS := 0.72
const ENTRANCE_SMOKE_SECONDS := 0.38
const ENTRANCE_MIN_FALL_HEIGHT := 280.0

var move_speed: float = BASE_MOVE_SPEED
var pickup_radius: float = 92.0
var weapon_damage: float = 10.0
var fire_rate: float = 13.0
var projectile_speed: float = 620.0
var projectile_pierce: int = 0
var weapon_lines: int = 1
var drone_count: int = 0
var drone_damage: float = 28.8
var drone_fire_interval: float = 0.28
var arc_pulse_level: int = 0
var arc_damage: float = 20.4
var arc_radius: float = 140.0
var arc_base_interval: float = 1.85
var mine_level: int = 0
var spike_damage: float = 10.0
var spike_duration: float = 5.0
var spike_spacing: float = 96.0
var spike_radius: float = 26.0
var spike_tick_interval: float = 0.32
var dash_distance: float = 165.0
var dash_duration: float = 0.16
var dash_cooldown: float = 2.0
var dash_melee_damage: float = 52.0
var dash_melee_radius: float = 36.0

var fire_timer: float = 0.0
var laser_audio_active: bool = false
var arc_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_remaining: float = 0.0
var gun_angle: float = 0.0
var health: Node
var player_collision: CollisionShape2D
var shield: float = 0.0
var max_shield: float = 20.0
var projectile_parent: Node
var drone_visuals: Array[Node2D] = []
var drone_lasers: Array[Node2D] = []
var drone_targets: Array[Node2D] = []
var drone_aim_directions: Array[Vector2] = []
var drone_lock_target_ids: Array[int] = []
var drone_lock_durations: Array[float] = []
var drone_laser_piercing := false
var world_bounds: Rect2 = Rect2()
var last_spike_position: Vector2 = Vector2.ZERO
var has_spike_position: bool = false
var dash_active: bool = false
var dash_direction: Vector2 = Vector2.RIGHT
var dash_hit_bodies: Array[Node] = []
var enemy_provider: Callable
var _fire_rate_modifiers: Dictionary = {}
var _damage_modifiers: Dictionary = {}
var _damage_immunity_sources: Dictionary = {}
var build_family_levels: Dictionary = {
	"ballistics": 1,
	"mobility": 1,
	"automation": 1,
}
var active_build_evolutions: Dictionary = {}
var overdrive_active: bool = false
var spawn_input_guard_active: bool = false
var stealth_remaining := 0.0
var last_assassin_flame_position := Vector2.ZERO
var has_assassin_flame_position := false
var entrance_active := false
var entrance_elapsed := 0.0
var entrance_visual_offset := 0.0
var entrance_fall_height := ENTRANCE_MIN_FALL_HEIGHT
var normal_collision_layer: int = 1
var normal_collision_mask: int = 1

func _ready() -> void:
	add_to_group("player")
	normal_collision_layer = collision_layer
	normal_collision_mask = collision_mask
	player_collision = CollisionShape2D.new()
	player_collision.name = "PlayerCollision"
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	player_collision.shape = circle
	add_child(player_collision)
	health = HealthComponentScript.new()
	health.max_health = 100.0
	add_child(health)
	health.health_changed.connect(func(current: float, maximum: float) -> void: health_changed.emit(current, maximum))
	health.died.connect(func() -> void: died.emit())

func _physics_process(delta: float) -> void:
	_update_stealth(delta)
	gun_angle = (get_global_mouse_position() - global_position).angle()
	dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var wants_dash := Input.is_action_just_pressed("dash_melee")
	var controls_were_guarded := spawn_input_guard_active
	input_vector = _filter_spawn_movement_input(input_vector, Input.is_action_pressed("dash_melee"))
	if controls_were_guarded:
		wants_dash = false
	if not dash_active and wants_dash:
		_start_dash((get_global_mouse_position() - global_position).normalized())
	if dash_active:
		_update_dash(delta)
	else:
		_update_movement(input_vector)
	_update_fire(delta, Input.is_action_pressed("fire"))
	_update_passives(delta)
	queue_redraw()

func _process(delta: float) -> void:
	if entrance_active:
		advance_entrance(delta)

func _update_movement(input_vector: Vector2) -> void:
	velocity = input_vector.limit_length(1.0) * get_effective_move_speed()
	move_and_slide()
	_clamp_to_world_bounds()

func begin_spawn_input_guard() -> void:
	spawn_input_guard_active = true
	velocity = Vector2.ZERO
	dash_active = false

func begin_entrance() -> void:
	entrance_active = true
	entrance_elapsed = 0.0
	entrance_fall_height = maxf(ENTRANCE_MIN_FALL_HEIGHT, get_viewport_rect().size.y * 0.52)
	entrance_visual_offset = -entrance_fall_height
	velocity = Vector2.ZERO
	queue_redraw()

func advance_entrance(delta: float) -> void:
	if not entrance_active or delta <= 0.0:
		return
	entrance_elapsed = minf(get_entrance_duration(), entrance_elapsed + delta)
	if entrance_elapsed < ENTRANCE_FALL_SECONDS:
		var progress := entrance_elapsed / ENTRANCE_FALL_SECONDS
		var eased := 1.0 - pow(1.0 - progress, 3.0)
		entrance_visual_offset = lerpf(-entrance_fall_height, 0.0, eased)
	else:
		entrance_visual_offset = 0.0
	queue_redraw()
	if entrance_elapsed >= get_entrance_duration():
		entrance_active = false
		entrance_finished.emit()

func get_entrance_duration() -> float:
	return ENTRANCE_FALL_SECONDS + ENTRANCE_SMOKE_SECONDS

func is_entrance_active() -> bool:
	return entrance_active

func _filter_spawn_movement_input(input_vector: Vector2, dash_pressed: bool) -> Vector2:
	if not spawn_input_guard_active:
		return input_vector
	if input_vector == Vector2.ZERO and not dash_pressed:
		spawn_input_guard_active = false
	return Vector2.ZERO

func get_body_radius() -> float:
	return BODY_RADIUS

func get_effective_move_speed() -> float:
	var multiplier := OVERDRIVE_MOVE_SPEED_MULTIPLIER if overdrive_active else 1.0
	if is_stealthed():
		multiplier *= ASSASSIN_SPEED_MULTIPLIER
	return move_speed * multiplier

func get_effective_dash_cooldown() -> float:
	return dash_cooldown * (OVERDRIVE_DASH_COOLDOWN_MULTIPLIER if overdrive_active else 1.0)

func _draw() -> void:
	draw_set_transform(Vector2(0.0, entrance_visual_offset), 0.0, Vector2.ONE * PLAYER_SIZE_SCALE)
	draw_rect(Rect2(-10, -14, 20, 28), Color(0.1, 0.85, 0.95))
	draw_rect(Rect2(-7, -18, 14, 7), Color(0.96, 0.92, 0.55))
	draw_rect(Rect2(-14, -6, 28, 8), Color(0.05, 0.28, 0.34))
	draw_rect(Rect2(-7, 8, 5, 10), Color(0.06, 0.08, 0.1))
	draw_rect(Rect2(2, 8, 5, 10), Color(0.06, 0.08, 0.1))
	draw_set_transform(Vector2(0.0, entrance_visual_offset), gun_angle, Vector2.ONE * PLAYER_SIZE_SCALE)
	draw_rect(Rect2(8, -3, 22, 6), Color(1.0, 0.32, 0.12))
	draw_rect(Rect2(25, -2, 8, 4), Color(0.75, 1.0, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if entrance_elapsed >= ENTRANCE_FALL_SECONDS and entrance_elapsed < get_entrance_duration():
		_draw_landing_smoke((entrance_elapsed - ENTRANCE_FALL_SECONDS) / ENTRANCE_SMOKE_SECONDS)
	if dash_active:
		draw_arc(Vector2.ZERO, dash_melee_radius, -PI * 0.2, PI * 1.2, 28, Color(1.0, 0.76, 0.18, 0.65), 4.0)
		draw_line(-dash_direction * 28.0, dash_direction * 34.0, Color(0.25, 1.0, 1.0, 0.85), 4.0)
	if arc_pulse_level > 0:
		draw_arc(Vector2.ZERO, 78.0 + arc_pulse_level * 16.0, 0.0, TAU, 48, Color(0.25, 1.0, 1.0, 0.18), 2.0)
	if entrance_active:
		return
	var dash_ratio := get_dash_charge_ratio()
	var bar_position := Vector2(-DASH_BAR_WIDTH * 0.5, BODY_RADIUS + 9.0)
	draw_rect(Rect2(bar_position, Vector2(DASH_BAR_WIDTH, 5.0)), Color("061019"))
	draw_rect(Rect2(bar_position, Vector2(DASH_BAR_WIDTH * dash_ratio, 5.0)), Color("ff571f") if dash_ratio >= 0.999 else Color("33fff2"))
	draw_rect(Rect2(bar_position - Vector2.ONE, Vector2(DASH_BAR_WIDTH + 2.0, 7.0)), Color(0.71, 0.36, 1.0, 0.72), false, 1.0)

func _draw_landing_smoke(progress: float) -> void:
	var resolved := clampf(progress, 0.0, 1.0)
	var alpha := 1.0 - resolved
	var foot := Vector2(0.0, BODY_RADIUS + 5.0)
	draw_arc(foot, lerpf(12.0, 58.0, resolved), PI, TAU, 40, Color(0.2, 1.0, 0.95, alpha * 0.72), 3.0)
	for index in range(7):
		var side := -1.0 if index % 2 == 0 else 1.0
		var lane := float(index / 2 + 1)
		var center := foot + Vector2(side * lane * lerpf(7.0, 18.0, resolved), -resolved * (8.0 + lane * 2.0))
		var radius := lerpf(7.0, 15.0, resolved) - lane * 0.6
		draw_circle(center, maxf(3.0, radius), Color(0.35, 0.42, 0.52, alpha * 0.42))

func take_damage(amount: float, _source: StringName = DamageTypes.GENERIC) -> bool:
	if health == null or amount <= 0.0 or is_damage_immune() or not health.can_accept_damage():
		return false
	var remaining := amount
	if shield > 0.0:
		var absorbed := minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		shield_changed.emit(shield, max_shield)
	if remaining > 0.0:
		health.damage(remaining, true)
	health.begin_invulnerability(0.35)
	return true

func add_shield(amount: float) -> void:
	shield = minf(max_shield, shield + amount)
	shield_changed.emit(shield, max_shield)

func increase_max_health(amount: float) -> void:
	health.increase_max(amount)

func heal(amount: float) -> void:
	health.heal(amount)

func get_snapshot_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"health": health.current_health,
		"max_health": health.max_health,
		"shield": shield,
		"max_shield": max_shield,
	}

func restore_snapshot_state(state: Dictionary) -> bool:
	if health == null or not state.has("position") or not state["position"] is Array:
		return false
	var position: Array = state["position"]
	if position.size() != 2:
		return false
	var restored_max_health := float(state.get("max_health", 0.0))
	var restored_health := float(state.get("health", -1.0))
	var restored_max_shield := float(state.get("max_shield", -1.0))
	var restored_shield := float(state.get("shield", -1.0))
	if restored_max_health <= 0.0 or restored_health < 0.0 or restored_health > restored_max_health:
		return false
	if restored_max_shield < 0.0 or restored_shield < 0.0 or restored_shield > restored_max_shield:
		return false
	global_position = Vector2(float(position[0]), float(position[1]))
	health.max_health = restored_max_health
	health.current_health = restored_health
	max_shield = restored_max_shield
	shield = restored_shield
	health.health_changed.emit(health.current_health, health.max_health)
	shield_changed.emit(shield, max_shield)
	return true

func increase_max_shield(amount: float, refill: bool = true) -> void:
	max_shield = maxf(0.0, max_shield + amount)
	if refill:
		shield = max_shield
	else:
		shield = minf(shield, max_shield)
	shield_changed.emit(shield, max_shield)

func get_dash_charge_ratio() -> float:
	return clampf(1.0 - dash_cooldown_remaining / maxf(0.001, get_effective_dash_cooldown()), 0.0, 1.0)

func get_effective_fire_rate() -> float:
	var effective_rate := fire_rate
	for modifier_id in _fire_rate_modifiers:
		effective_rate *= float(_fire_rate_modifiers[modifier_id])
	if active_build_evolutions.has("orbital_storm"):
		effective_rate *= GRENADE_RATE_MULTIPLIER
	return minf(effective_rate, fire_rate * MAX_FIRE_RATE_MULTIPLIER)

func get_active_weapon_line_count() -> int:
	var multiplier := 2 if overdrive_active else 1
	return mini(MAX_WEAPON_LINES, maxi(1, weapon_lines * multiplier))

func set_fire_rate_modifier(modifier_id: StringName, multiplier: float) -> void:
	if multiplier <= 0.0:
		clear_fire_rate_modifier(modifier_id)
		return
	_fire_rate_modifiers[modifier_id] = multiplier

func clear_fire_rate_modifier(modifier_id: StringName) -> void:
	_fire_rate_modifiers.erase(modifier_id)

func get_effective_damage_multiplier(source: StringName) -> float:
	var multiplier := _multiply_damage_modifiers(ALL_DAMAGE_SOURCES)
	if source != ALL_DAMAGE_SOURCES:
		multiplier *= _multiply_damage_modifiers(source)
	multiplier *= _get_build_family_damage_multiplier(source)
	return multiplier

func set_build_family_levels(levels: Dictionary) -> void:
	for family_id in build_family_levels:
		build_family_levels[family_id] = maxi(1, int(levels.get(family_id, 1)))

func _get_build_family_damage_multiplier(source: StringName) -> float:
	var family_id := ""
	match source:
		DamageTypes.PROJECTILE:
			family_id = "ballistics"
		DamageTypes.DASH, DamageTypes.SPIKE:
			family_id = "mobility"
		DamageTypes.LASER, DamageTypes.ARC:
			family_id = "automation"
	if family_id.is_empty():
		return 1.0
	return pow(FAMILY_DAMAGE_PER_LEVEL, float(int(build_family_levels.get(family_id, 1)) - 1))

func activate_build_evolution(evolution_id: String) -> bool:
	if active_build_evolutions.has(evolution_id):
		return false
	match evolution_id:
		"orbital_storm":
			active_build_evolutions[evolution_id] = true
		"rift_overdrive":
			active_build_evolutions[evolution_id] = true
			mine_level = maxi(1, mine_level)
			dash_cooldown *= 1.20
			dash_distance *= 1.20
			spike_spacing = maxf(22.0, spike_spacing * 0.70)
			spike_damage *= 1.28
			_reset_spike_path()
		"thunder_matrix":
			active_build_evolutions[evolution_id] = true
			drone_damage *= THUNDER_MATRIX_DRONE_DAMAGE_MULTIPLIER
			arc_pulse_level = maxi(1, arc_pulse_level)
		_:
			return false
	queue_redraw()
	return true

func set_damage_modifier(
	modifier_id: StringName,
	multiplier: float,
	source: StringName = ALL_DAMAGE_SOURCES
) -> void:
	if multiplier <= 0.0:
		clear_damage_modifier(modifier_id, source)
		return
	var source_modifiers: Dictionary = _damage_modifiers.get(source, {})
	source_modifiers[modifier_id] = multiplier
	_damage_modifiers[source] = source_modifiers

func clear_damage_modifier(
	modifier_id: StringName,
	source: StringName = ALL_DAMAGE_SOURCES
) -> void:
	var source_modifiers: Dictionary = _damage_modifiers.get(source, {})
	source_modifiers.erase(modifier_id)
	if source_modifiers.is_empty():
		_damage_modifiers.erase(source)
	else:
		_damage_modifiers[source] = source_modifiers

func set_damage_immunity(source: StringName, active: bool) -> void:
	if active:
		_damage_immunity_sources[source] = true
	else:
		_damage_immunity_sources.erase(source)

func set_dash_immunity_active(active: bool) -> void:
	set_damage_immunity(DASH_IMMUNITY_SOURCE, active)

func is_damage_immune() -> bool:
	return not _damage_immunity_sources.is_empty()

func set_overdrive_active(active: bool) -> void:
	overdrive_active = active
	if active:
		set_fire_rate_modifier(OVERDRIVE_MODIFIER, OVERDRIVE_FIRE_RATE_MULTIPLIER)
		set_damage_modifier(OVERDRIVE_MODIFIER, OVERDRIVE_DAMAGE_MULTIPLIER)
		set_damage_modifier(
			OVERDRIVE_MODIFIER,
			OVERDRIVE_SPIKE_DAMAGE_MULTIPLIER / OVERDRIVE_DAMAGE_MULTIPLIER,
			DamageTypes.SPIKE
		)
		set_damage_modifier(
			OVERDRIVE_MODIFIER,
			OVERDRIVE_LASER_DAMAGE_MULTIPLIER / OVERDRIVE_DAMAGE_MULTIPLIER,
			DamageTypes.LASER
		)
		set_damage_modifier(
			OVERDRIVE_MODIFIER,
			OVERDRIVE_ARC_DAMAGE_MULTIPLIER / OVERDRIVE_DAMAGE_MULTIPLIER,
			DamageTypes.ARC
		)
	else:
		clear_fire_rate_modifier(OVERDRIVE_MODIFIER)
		clear_damage_modifier(OVERDRIVE_MODIFIER)
		clear_damage_modifier(OVERDRIVE_MODIFIER, DamageTypes.SPIKE)
		clear_damage_modifier(OVERDRIVE_MODIFIER, DamageTypes.LASER)
		clear_damage_modifier(OVERDRIVE_MODIFIER, DamageTypes.ARC)
	set_damage_immunity(OVERDRIVE_MODIFIER, active)

func clear_runtime_modifiers() -> void:
	overdrive_active = false
	_fire_rate_modifiers.clear()
	_damage_modifiers.clear()
	_damage_immunity_sources.clear()
	stealth_remaining = 0.0
	self_modulate.a = 1.0
	_set_stealth_collision_disabled(false)

func _multiply_damage_modifiers(source: StringName) -> float:
	var multiplier := 1.0
	if not _damage_modifiers.has(source):
		return multiplier
	var source_modifiers: Dictionary = _damage_modifiers[source]
	for modifier_id in source_modifiers:
		multiplier *= float(source_modifiers[modifier_id])
	return multiplier

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		clear_runtime_modifiers()

func _exit_tree() -> void:
	clear_runtime_modifiers()

func _fire() -> void:
	if not _can_fire_primary():
		return
	var direction := (get_global_mouse_position() - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	_break_stealth()
	var spread_step := deg_to_rad(7.5)
	var active_weapon_lines := get_active_weapon_line_count()
	var start_offset := -spread_step * float(active_weapon_lines - 1) * 0.5
	for line in range(active_weapon_lines):
		_spawn_bullet(direction.rotated(start_offset + spread_step * line))

func _update_fire(delta: float, wants_fire: bool) -> int:
	var fired_count := 0
	var interval := 1.0 / maxf(get_effective_fire_rate(), 0.001)
	fire_timer -= delta
	if not wants_fire or not _can_fire_primary():
		fire_timer = maxf(fire_timer, -interval)
		return fired_count
	while fire_timer <= 0.0 and fired_count < 4:
		_fire()
		fire_timer += interval
		fired_count += 1
	return fired_count

func _spawn_bullet(direction: Vector2, damage_scale: float = 1.0) -> void:
	if active_build_evolutions.has("orbital_storm"):
		var grenade := GrenadeProjectileScript.new()
		grenade.global_position = global_position + direction * PROJECTILE_SPAWN_OFFSET
		grenade.velocity = velocity + direction * projectile_speed * GRENADE_SPEED_MULTIPLIER
		grenade.damage = weapon_damage * GRENADE_DAMAGE_MULTIPLIER * maxf(0.0, damage_scale)
		grenade.damage_multiplier_provider = Callable(self, "get_effective_damage_multiplier").bind(DamageTypes.PROJECTILE)
		grenade.enemy_provider = Callable(self, "_get_enemies")
		grenade.world_bounds = world_bounds
		fired.emit(grenade)
		return
	var shot := ProjectileScript.new()
	shot.global_position = global_position + direction * PROJECTILE_SPAWN_OFFSET
	shot.velocity = velocity + direction * projectile_speed
	shot.damage = weapon_damage * maxf(0.0, damage_scale)
	shot.damage_multiplier_provider = Callable(
		self,
		"get_effective_damage_multiplier"
	).bind(DamageTypes.PROJECTILE)
	shot.pierce = projectile_pierce
	shot.lifetime = 6.0
	shot.target_group = &"enemies"
	shot.overdrive_visual = overdrive_active
	shot.tint = Color("b45cff") if overdrive_active else Color(1.0, 0.35, 0.08)
	shot.world_bounds = world_bounds
	fired.emit(shot)

func _can_fire_primary() -> bool:
	return not dash_active

func _start_dash(direction: Vector2) -> void:
	if dash_active or dash_cooldown_remaining > 0.0:
		return
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(gun_angle)
	dash_direction = direction.normalized()
	dash_active = true
	dash_timer = dash_duration
	dash_cooldown_remaining = get_effective_dash_cooldown()
	dash_hit_bodies.clear()
	_apply_dash_melee_sweep(global_position, global_position)
	if active_build_evolutions.has("rift_overdrive"):
		has_assassin_flame_position = false
		_update_assassin_flame_path()

func _update_dash(delta: float) -> void:
	if not dash_active:
		return
	var step_time := minf(delta, dash_timer)
	var start := global_position
	velocity = dash_direction * (dash_distance / dash_duration)
	global_position += velocity * step_time
	_clamp_to_world_bounds()
	dash_timer -= step_time
	_apply_dash_melee_sweep(start, global_position)
	if active_build_evolutions.has("rift_overdrive"):
		_update_assassin_flame_path()
	if dash_timer <= 0.0:
		dash_active = false
		velocity = Vector2.ZERO
		if active_build_evolutions.has("rift_overdrive"):
			_activate_assassin_stealth()
		if mine_level > 0:
			last_spike_position = global_position
			has_spike_position = true

func _activate_assassin_stealth() -> void:
	stealth_remaining = ASSASSIN_STEALTH_SECONDS
	self_modulate.a = 0.42
	_set_stealth_collision_disabled(true)

func _break_stealth() -> void:
	if stealth_remaining <= 0.0:
		return
	stealth_remaining = 0.0
	self_modulate.a = 1.0
	_set_stealth_collision_disabled(false)

func _update_stealth(delta: float) -> void:
	if stealth_remaining <= 0.0:
		return
	stealth_remaining = maxf(0.0, stealth_remaining - delta)
	if stealth_remaining <= 0.0:
		self_modulate.a = 1.0
		_set_stealth_collision_disabled(false)

func is_stealthed() -> bool:
	return stealth_remaining > 0.0

func _set_stealth_collision_disabled(disabled: bool) -> void:
	collision_layer = 0 if disabled else normal_collision_layer
	collision_mask = 0 if disabled else normal_collision_mask
	if is_instance_valid(player_collision):
		player_collision.set_deferred("disabled", disabled)

func _update_assassin_flame_path() -> void:
	if projectile_parent == null:
		return
	if not has_assassin_flame_position:
		last_assassin_flame_position = global_position
		has_assassin_flame_position = true
		_drop_assassin_flame(last_assassin_flame_position)
		return
	var travel := global_position - last_assassin_flame_position
	var remaining := travel.length()
	if remaining < ASSASSIN_FLAME_SPACING:
		return
	var direction := travel / remaining
	while remaining >= ASSASSIN_FLAME_SPACING:
		last_assassin_flame_position += direction * ASSASSIN_FLAME_SPACING
		_drop_assassin_flame(last_assassin_flame_position)
		remaining = global_position.distance_to(last_assassin_flame_position)

func _drop_assassin_flame(world_position: Vector2) -> void:
	var flame := FlameTrailScript.new()
	flame.position = projectile_parent.to_local(world_position)
	flame.burn_base_attack = weapon_damage * get_effective_damage_multiplier(DamageTypes.DASH)
	projectile_parent.add_child(flame)

func _apply_dash_melee_sweep(start: Vector2, end: Vector2) -> void:
	for enemy in _get_enemies():
		var node := enemy as Node2D
		if node == null or dash_hit_bodies.has(enemy) or not enemy.has_method("take_damage"):
			continue
		if _distance_to_segment(node.global_position, start, end) <= dash_melee_radius:
			dash_hit_bodies.append(enemy)
			enemy.take_damage(
				dash_melee_damage * get_effective_damage_multiplier(DamageTypes.DASH),
				DamageTypes.DASH
			)

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)

func _update_passives(delta: float) -> void:
	if projectile_parent == null:
		return
	_sync_drone_visuals()
	_update_drone_positions()
	if drone_count > 0:
		_update_drone_lasers(delta)
	else:
		_clear_drone_lasers()
	if arc_pulse_level > 0:
		arc_timer -= delta
		if arc_timer <= 0.0:
			arc_timer = get_arc_pulse_interval()
			_emit_arc_pulse()
	if mine_level > 0 and not dash_active:
		_update_spike_path()

func _update_drone_lasers(delta: float) -> void:
	_sync_drone_lasers()
	drone_targets.clear()
	var assigned: Array[Node2D] = []
	var enemies := _get_enemies()
	var any_laser_active := false
	for index in range(drone_count):
		var origin := global_position
		if index < drone_visuals.size():
			origin = drone_visuals[index].global_position
		var target := _nearest_unassigned_enemy(origin, assigned, enemies)
		drone_targets.append(target)
		if target == null:
			_reset_drone_burn_lock(index)
			if index < drone_lasers.size():
				drone_lasers[index].visible = false
			continue
		assigned.append(target)
		any_laser_active = true
		var desired_direction := (target.global_position - origin).normalized()
		if desired_direction == Vector2.ZERO:
			desired_direction = Vector2.RIGHT.rotated(gun_angle)
		var direction := _turn_drone_toward(index, desired_direction, delta)
		if index < drone_visuals.size():
			drone_visuals[index].rotation = direction.angle()
		var target_distance := origin.distance_to(target.global_position)
		var target_radius_value: Variant = target.get("body_radius")
		var target_radius := float(target_radius_value) if target_radius_value != null else 0.0
		var beam_length := target_distance + target_radius
		if drone_laser_piercing:
			beam_length = get_drone_pierce_length()
			_damage_enemies_on_laser(origin, direction, beam_length, drone_damage * delta, get_drone_laser_width(), enemies)
		var primary_target_hit := _is_target_on_laser(target, origin, direction, beam_length, get_drone_laser_width())
		if not drone_laser_piercing and primary_target_hit:
			target.take_damage(
				drone_damage * delta * get_effective_damage_multiplier(DamageTypes.LASER),
				DamageTypes.LASER
			)
		if primary_target_hit:
			_update_drone_burn_lock(index, target, delta)
		else:
			_reset_drone_burn_lock(index)
		var beam := drone_lasers[index]
		beam.visible = true
		beam.setup(origin, origin + direction * beam_length, get_drone_laser_color(), get_drone_laser_width())
	_set_laser_audio_active(any_laser_active)

func _turn_drone_toward(index: int, desired_direction: Vector2, delta: float) -> Vector2:
	while drone_aim_directions.size() <= index:
		drone_aim_directions.append(Vector2.RIGHT)
	var current_direction: Vector2 = drone_aim_directions[index]
	if current_direction == Vector2.ZERO:
		current_direction = Vector2.RIGHT
	var angle_delta := current_direction.angle_to(desired_direction)
	var max_delta := DRONE_MAX_TURN_SPEED_RADIANS * maxf(0.0, delta)
	var resolved := current_direction.rotated(clampf(angle_delta, -max_delta, max_delta)).normalized()
	drone_aim_directions[index] = resolved
	return resolved

func _is_target_on_laser(
	target: Node2D,
	origin: Vector2,
	direction: Vector2,
	length: float,
	width: float
) -> bool:
	var relative := target.global_position - origin
	var along := relative.dot(direction)
	if along < 0.0 or along > length:
		return false
	var radius_value: Variant = target.get("body_radius")
	var target_radius := float(radius_value) if radius_value != null else 0.0
	return (origin + direction * along).distance_to(target.global_position) <= width + target_radius

func get_drone_laser_color() -> Color:
	if active_build_evolutions.has("thunder_matrix"):
		return THUNDER_MATRIX_LASER_COLOR
	return BASE_DRONE_LASER_COLOR

func get_drone_laser_width() -> float:
	return BASE_DRONE_LASER_WIDTH * (OVERDRIVE_LASER_WIDTH_MULTIPLIER if overdrive_active else 1.0)

func get_drone_pierce_length() -> float:
	if world_bounds.size != Vector2.ZERO:
		return world_bounds.size.length()
	return maxf(1200.0, get_viewport_rect().size.length() * 1.5)

func _update_drone_burn_lock(index: int, target: Node2D, delta: float) -> void:
	while drone_lock_target_ids.size() <= index:
		drone_lock_target_ids.append(0)
		drone_lock_durations.append(0.0)
	var target_id := target.get_instance_id()
	if drone_lock_target_ids[index] != target_id:
		drone_lock_target_ids[index] = target_id
		drone_lock_durations[index] = 0.0
	drone_lock_durations[index] += delta
	while drone_lock_durations[index] >= DRONE_BURN_STACK_INTERVAL:
		drone_lock_durations[index] -= DRONE_BURN_STACK_INTERVAL
		if target.has_method("apply_burn_stack"):
			target.apply_burn_stack(
				drone_damage * get_effective_damage_multiplier(DamageTypes.LASER),
				DRONE_BURN_SECONDS,
				0.0
			)

func _reset_drone_burn_lock(index: int) -> void:
	if index >= drone_lock_target_ids.size():
		return
	drone_lock_target_ids[index] = 0
	drone_lock_durations[index] = 0.0

func _damage_enemies_on_laser(
	origin: Vector2,
	direction: Vector2,
	length: float,
	damage: float,
	width: float,
	candidates: Array = []
) -> void:
	var enemies: Array = candidates if not candidates.is_empty() else _get_enemies()
	for enemy in enemies:
		var node := enemy as Node2D
		if node == null or not enemy.has_method("take_damage"):
			continue
		var relative := node.global_position - origin
		var along := relative.dot(direction)
		if along < 0.0 or along > length:
			continue
		var closest := origin + direction * along
		var radius_value: Variant = enemy.get("body_radius")
		var target_radius := float(radius_value) if radius_value != null else 0.0
		if closest.distance_to(node.global_position) <= width + target_radius:
			enemy.take_damage(
				damage * get_effective_damage_multiplier(DamageTypes.LASER),
				DamageTypes.LASER
			)

func _emit_arc_pulse() -> void:
	var radius := get_arc_pulse_radius()
	var wave := ArcPulseVisualScript.new()
	wave.global_position = global_position
	wave.setup(
		radius,
		get_arc_pulse_damage() * get_effective_damage_multiplier(DamageTypes.ARC),
		Callable(self, "_get_enemies"),
		get_arc_pulse_expansion_speed_scale()
	)
	projectile_parent.add_child(wave)

func get_arc_pulse_interval() -> float:
	var interval := maxf(0.7, arc_base_interval - arc_pulse_level * 0.20)
	if overdrive_active:
		interval /= OVERDRIVE_ARC_FREQUENCY_MULTIPLIER
	return interval

func get_arc_pulse_radius() -> float:
	var radius := arc_radius + arc_pulse_level * 18.0
	if active_build_evolutions.has("thunder_matrix"):
		radius = maxf(radius, get_viewport_rect().size.length())
	if overdrive_active:
		radius *= OVERDRIVE_ARC_RADIUS_MULTIPLIER
	return radius

func get_arc_pulse_damage() -> float:
	var resolved := arc_damage + arc_pulse_level * ARC_DAMAGE_PER_LEVEL
	if active_build_evolutions.has("thunder_matrix"):
		resolved *= THUNDER_MATRIX_ARC_DAMAGE_MULTIPLIER
	return resolved

func get_arc_pulse_expansion_speed_scale() -> float:
	return ARC_EXPANSION_SPEED_SCALE

func _drop_spike_trap_at(position: Vector2) -> void:
	var trap := SpikeTrapScript.new()
	trap.global_position = position
	trap.damage_source = DamageTypes.SPIKE
	trap.damage = spike_damage
	trap.damage_multiplier_provider = Callable(
		self,
		"get_effective_damage_multiplier"
	).bind(DamageTypes.SPIKE)
	trap.radius = spike_radius * (OVERDRIVE_SPIKE_RADIUS_MULTIPLIER if overdrive_active else 1.0)
	trap.tick_interval = spike_tick_interval
	trap.lifetime = spike_duration * (OVERDRIVE_SPIKE_DURATION_MULTIPLIER if overdrive_active else 1.0)
	projectile_parent.add_child(trap)

func _update_spike_path() -> void:
	if not has_spike_position:
		last_spike_position = global_position
		has_spike_position = true
		_drop_spike_trap_at(last_spike_position)
		return
	var travel := global_position - last_spike_position
	var distance := travel.length()
	if distance < spike_spacing:
		return
	var direction := travel / distance
	while distance >= spike_spacing:
		last_spike_position += direction * spike_spacing
		_drop_spike_trap_at(last_spike_position)
		distance = global_position.distance_to(last_spike_position)

func _reset_spike_path() -> void:
	has_spike_position = false

func _sync_drone_visuals() -> void:
	while drone_visuals.size() < drone_count:
		var drone := Node2D.new()
		drone.set_script(load("res://scripts/actors/DroneVisual.gd"))
		add_child(drone)
		drone_visuals.append(drone)
	while drone_visuals.size() > drone_count:
		var drone: Node2D = drone_visuals.pop_back()
		drone.queue_free()
	while drone_aim_directions.size() < drone_count:
		drone_aim_directions.append(Vector2.RIGHT)
	while drone_aim_directions.size() > drone_count:
		drone_aim_directions.pop_back()
	_sync_drone_lasers()

func _sync_drone_lasers() -> void:
	if projectile_parent == null:
		return
	while drone_lasers.size() < drone_count:
		var beam := LaserBeamScript.new()
		beam.persistent = true
		beam.visible = false
		projectile_parent.add_child(beam)
		drone_lasers.append(beam)
	while drone_lasers.size() > drone_count:
		var beam: Node2D = drone_lasers.pop_back()
		beam.queue_free()

func _clear_drone_lasers() -> void:
	_set_laser_audio_active(false)
	for beam in drone_lasers:
		if is_instance_valid(beam):
			beam.queue_free()
	drone_lasers.clear()
	drone_targets.clear()
	drone_lock_target_ids.clear()
	drone_lock_durations.clear()

func _set_laser_audio_active(active: bool) -> void:
	if laser_audio_active == active:
		return
	laser_audio_active = active
	laser_active_changed.emit(active)

func _update_drone_positions() -> void:
	if drone_visuals.is_empty():
		return
	var orbit := 48.0
	var spin := Time.get_ticks_msec() / 520.0
	for index in range(drone_visuals.size()):
		var angle := spin + float(index) * TAU / float(drone_visuals.size())
		drone_visuals[index].position = Vector2.RIGHT.rotated(angle) * orbit

func _nearest_enemy(from_position: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for enemy in _get_enemies():
		var node := enemy as Node2D
		var distance := from_position.distance_squared_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best

func _nearest_unassigned_enemy(
	from_position: Vector2,
	assigned: Array[Node2D],
	enemies: Array[Node]
) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for enemy in enemies:
		var node := enemy as Node2D
		if node == null or assigned.has(node):
			continue
		var distance := from_position.distance_squared_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	if best != null:
		return best
	# All live enemies are already claimed. Reuse the nearest one so surplus
	# drones still contribute against a lone Boss or the last enemy in a wave.
	for enemy in enemies:
		var node := enemy as Node2D
		if node == null:
			continue
		var distance := from_position.distance_squared_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best

func set_enemy_provider(provider: Callable) -> void:
	enemy_provider = provider

func _get_enemies() -> Array[Node]:
	if enemy_provider.is_valid():
		var provided: Variant = enemy_provider.call()
		if provided is Array:
			var enemies: Array[Node] = []
			enemies.assign(provided)
			return enemies
	return get_tree().get_nodes_in_group("enemies")

func _clamp_to_world_bounds() -> void:
	if world_bounds.size == Vector2.ZERO:
		return
	var playable := world_bounds.grow(-BODY_RADIUS)
	global_position = global_position.clamp(playable.position, playable.end)
