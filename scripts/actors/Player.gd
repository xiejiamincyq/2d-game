extends CharacterBody2D
class_name Player

signal health_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal died
signal fired(projectile: Node)
signal laser_active_changed(active: bool)

const ProjectileScript = preload("res://scripts/components/Projectile.gd")
const HealthComponentScript = preload("res://scripts/components/HealthComponent.gd")
const LaserBeamScript = preload("res://scripts/components/LaserBeam.gd")
const SpikeTrapScript = preload("res://scripts/components/SpikeTrap.gd")
const ArcPulseVisualScript = preload("res://scripts/components/ArcPulseVisual.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const ALL_DAMAGE_SOURCES: StringName = &"all"
const OVERDRIVE_MODIFIER: StringName = &"overdrive"
const DASH_IMMUNITY_SOURCE: StringName = &"dash"
const OVERDRIVE_FIRE_RATE_MULTIPLIER: float = 2.0
const OVERDRIVE_DAMAGE_MULTIPLIER: float = 1.2
const OVERDRIVE_SPIKE_DAMAGE_MULTIPLIER: float = 2.0
const OVERDRIVE_LASER_DAMAGE_MULTIPLIER: float = 2.0
const OVERDRIVE_ARC_DAMAGE_MULTIPLIER: float = 1.5
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
const ARC_EXPANSION_SPEED_SCALE: float = 0.5
const ARC_DAMAGE_PER_LEVEL: float = 6.0
const PLAYER_SIZE_SCALE: float = 1.3
const BASE_BODY_RADIUS: float = 13.0
const BODY_RADIUS: float = BASE_BODY_RADIUS * PLAYER_SIZE_SCALE
const PROJECTILE_SPAWN_OFFSET: float = 25.0 * PLAYER_SIZE_SCALE
const MAX_WEAPON_LINES: int = 8
const MAX_FIRE_RATE_MULTIPLIER: float = 4.0
const FAMILY_DAMAGE_PER_LEVEL: float = 1.05
const ORBITAL_STORM_INTERVAL: int = 5
const ORBITAL_STORM_PROJECTILES: int = 12
const ORBITAL_STORM_DAMAGE_SCALE: float = 0.55

var move_speed: float = 235.0
var pickup_radius: float = 92.0
var weapon_damage: float = 10.0
var fire_rate: float = 13.0
var projectile_speed: float = 620.0
var projectile_pierce: int = 0
var weapon_lines: int = 1
var drone_count: int = 0
var drone_damage: float = 24.0
var drone_fire_interval: float = 0.28
var arc_pulse_level: int = 0
var arc_damage: float = 17.0
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
var shield: float = 0.0
var max_shield: float = 60.0
var projectile_parent: Node
var drone_visuals: Array[Node2D] = []
var drone_lasers: Array[Node2D] = []
var drone_targets: Array[Node2D] = []
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
var fire_volley_count: int = 0
var overdrive_active: bool = false
var spawn_input_guard_active: bool = false

func _ready() -> void:
	add_to_group("player")
	var shape := CollisionShape2D.new()
	shape.name = "PlayerCollision"
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	shape.shape = circle
	add_child(shape)
	health = HealthComponentScript.new()
	health.max_health = 100.0
	add_child(health)
	health.health_changed.connect(func(current: float, maximum: float) -> void: health_changed.emit(current, maximum))
	health.died.connect(func() -> void: died.emit())

func _physics_process(delta: float) -> void:
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

func _update_movement(input_vector: Vector2) -> void:
	velocity = input_vector.limit_length(1.0) * get_effective_move_speed()
	move_and_slide()
	_clamp_to_world_bounds()

func begin_spawn_input_guard() -> void:
	spawn_input_guard_active = true
	velocity = Vector2.ZERO
	dash_active = false

func _filter_spawn_movement_input(input_vector: Vector2, dash_pressed: bool) -> Vector2:
	if not spawn_input_guard_active:
		return input_vector
	if input_vector == Vector2.ZERO and not dash_pressed:
		spawn_input_guard_active = false
	return Vector2.ZERO

func get_body_radius() -> float:
	return BODY_RADIUS

func get_effective_move_speed() -> float:
	return move_speed * (OVERDRIVE_MOVE_SPEED_MULTIPLIER if overdrive_active else 1.0)

func get_effective_dash_cooldown() -> float:
	return dash_cooldown * (OVERDRIVE_DASH_COOLDOWN_MULTIPLIER if overdrive_active else 1.0)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PLAYER_SIZE_SCALE)
	draw_rect(Rect2(-10, -14, 20, 28), Color(0.1, 0.85, 0.95))
	draw_rect(Rect2(-7, -18, 14, 7), Color(0.96, 0.92, 0.55))
	draw_rect(Rect2(-14, -6, 28, 8), Color(0.05, 0.28, 0.34))
	draw_rect(Rect2(-7, 8, 5, 10), Color(0.06, 0.08, 0.1))
	draw_rect(Rect2(2, 8, 5, 10), Color(0.06, 0.08, 0.1))
	draw_set_transform(Vector2.ZERO, gun_angle, Vector2.ONE * PLAYER_SIZE_SCALE)
	draw_rect(Rect2(8, -3, 22, 6), Color(1.0, 0.32, 0.12))
	draw_rect(Rect2(25, -2, 8, 4), Color(0.75, 1.0, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if dash_active:
		draw_arc(Vector2.ZERO, dash_melee_radius, -PI * 0.2, PI * 1.2, 28, Color(1.0, 0.76, 0.18, 0.65), 4.0)
		draw_line(-dash_direction * 28.0, dash_direction * 34.0, Color(0.25, 1.0, 1.0, 0.85), 4.0)
	if arc_pulse_level > 0:
		draw_arc(Vector2.ZERO, 78.0 + arc_pulse_level * 16.0, 0.0, TAU, 48, Color(0.25, 1.0, 1.0, 0.18), 2.0)

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

func get_effective_fire_rate() -> float:
	var effective_rate := fire_rate
	for modifier_id in _fire_rate_modifiers:
		effective_rate *= float(_fire_rate_modifiers[modifier_id])
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
			dash_cooldown = maxf(0.8, dash_cooldown * 0.70)
			dash_distance *= 1.15
			spike_spacing = maxf(22.0, spike_spacing * 0.70)
			spike_damage *= 1.28
			_reset_spike_path()
		"thunder_matrix":
			active_build_evolutions[evolution_id] = true
			drone_damage *= 2.0
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
	var spread_step := deg_to_rad(7.5)
	var active_weapon_lines := get_active_weapon_line_count()
	var start_offset := -spread_step * float(active_weapon_lines - 1) * 0.5
	for line in range(active_weapon_lines):
		_spawn_bullet(direction.rotated(start_offset + spread_step * line))
	fire_volley_count += 1
	if active_build_evolutions.has("orbital_storm") and fire_volley_count % ORBITAL_STORM_INTERVAL == 0:
		for radial_index in range(ORBITAL_STORM_PROJECTILES):
			var radial_direction := Vector2.RIGHT.rotated(TAU * float(radial_index) / float(ORBITAL_STORM_PROJECTILES))
			_spawn_bullet(radial_direction, ORBITAL_STORM_DAMAGE_SCALE)

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
	var shot := ProjectileScript.new()
	shot.global_position = global_position + direction * PROJECTILE_SPAWN_OFFSET
	shot.velocity = direction * projectile_speed
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
	if mine_level > 0 and active_build_evolutions.has("rift_overdrive"):
		_update_spike_path(true)

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
	if mine_level > 0 and active_build_evolutions.has("rift_overdrive"):
		_update_spike_path(true)
	if dash_timer <= 0.0:
		dash_active = false
		velocity = Vector2.ZERO

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
	if mine_level > 0:
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
			if index < drone_lasers.size():
				drone_lasers[index].visible = false
			continue
		assigned.append(target)
		any_laser_active = true
		target.take_damage(
			drone_damage * delta * get_effective_damage_multiplier(DamageTypes.LASER),
			DamageTypes.LASER
		)
		var beam := drone_lasers[index]
		beam.visible = true
		beam.setup(origin, target.global_position, get_drone_laser_color(), get_drone_laser_width())
	_set_laser_audio_active(any_laser_active)

func get_drone_laser_color() -> Color:
	if active_build_evolutions.has("thunder_matrix"):
		return THUNDER_MATRIX_LASER_COLOR
	return BASE_DRONE_LASER_COLOR

func get_drone_laser_width() -> float:
	return BASE_DRONE_LASER_WIDTH * (OVERDRIVE_LASER_WIDTH_MULTIPLIER if overdrive_active else 1.0)

func _damage_enemies_on_laser(origin: Vector2, direction: Vector2, length: float, damage: float, width: float) -> void:
	for enemy in _get_enemies():
		var node := enemy as Node2D
		if node == null or not enemy.has_method("take_damage"):
			continue
		var relative := node.global_position - origin
		var along := relative.dot(direction)
		if along < 0.0 or along > length:
			continue
		var closest := origin + direction * along
		if closest.distance_to(node.global_position) <= width:
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
	return arc_damage + arc_pulse_level * ARC_DAMAGE_PER_LEVEL

func get_arc_pulse_expansion_speed_scale() -> float:
	return ARC_EXPANSION_SPEED_SCALE

func _drop_spike_trap() -> void:
	var trap := SpikeTrapScript.new()
	trap.global_position = global_position
	trap.damage = spike_damage
	trap.damage_multiplier_provider = Callable(
		self,
		"get_effective_damage_multiplier"
	).bind(DamageTypes.SPIKE)
	trap.radius = spike_radius * (OVERDRIVE_SPIKE_RADIUS_MULTIPLIER if overdrive_active else 1.0)
	trap.tick_interval = spike_tick_interval
	trap.lifetime = spike_duration * (OVERDRIVE_SPIKE_DURATION_MULTIPLIER if overdrive_active else 1.0)
	projectile_parent.add_child(trap)

func _drop_spike_trap_at(position: Vector2, rift_dash_spike: bool = false) -> void:
	var trap := SpikeTrapScript.new()
	trap.global_position = position
	trap.rift_variant = rift_dash_spike
	trap.damage_source = DamageTypes.DASH if rift_dash_spike else DamageTypes.SPIKE
	trap.damage = spike_damage * (3.0 if rift_dash_spike else 1.0)
	trap.damage_multiplier_provider = Callable(
		self,
		"get_effective_damage_multiplier"
	).bind(DamageTypes.SPIKE)
	trap.radius = spike_radius * (OVERDRIVE_SPIKE_RADIUS_MULTIPLIER if overdrive_active else 1.0)
	trap.tick_interval = spike_tick_interval
	trap.lifetime = spike_duration * (OVERDRIVE_SPIKE_DURATION_MULTIPLIER if overdrive_active else 1.0)
	projectile_parent.add_child(trap)

func _update_spike_path(rift_dash_spike: bool = false) -> void:
	if not has_spike_position:
		last_spike_position = global_position
		has_spike_position = true
		_drop_spike_trap_at(last_spike_position, rift_dash_spike)
		return
	var travel := global_position - last_spike_position
	var distance := travel.length()
	if distance < spike_spacing:
		return
	var direction := travel / distance
	while distance >= spike_spacing:
		last_spike_position += direction * spike_spacing
		_drop_spike_trap_at(last_spike_position, rift_dash_spike)
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
