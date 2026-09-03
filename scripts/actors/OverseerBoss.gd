extends CharacterBody2D
class_name OverseerBoss

signal died(boss: Node, coin_value: int, source: StringName)
signal hit(source: StringName)
signal health_changed(current: float, maximum: float, phase: int)
signal reinforcements_requested(boss: Node, count: int)
signal combat_cue(cue: StringName)
signal entrance_finished
signal damage_resolved(
	boss: Node,
	source: StringName,
	amount: float,
	world_position: Vector2,
	direction: Vector2,
	killed: bool
)

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const BurnStatusScript = preload("res://scripts/components/BurnStatus.gd")
const HealthComponentScript = preload("res://scripts/components/HealthComponent.gd")
const TentacleAttackScript = preload("res://scripts/components/TentacleAttack.gd")
const BossAttackDirectorScript = preload("res://scripts/components/BossAttackDirector.gd")
const OVERSEER_TEXTURE := preload("res://assets/art/actors/enemies/enemy_overseer.png")
const HIT_FLASH_SHADER := preload("res://assets/art/shaders/dasher_hit_flash.gdshader")

const DISPLAY_NAME := "深渊监工 / OVERSEER"
const BODY_RADIUS := 56.0
const VISUAL_RADIUS := 80.0
const BASE_MAX_HEALTH := 10800.0
const EXPECTED_STANDARD_TTK_SECONDS := 55.0
const KEEP_DISTANCE_MIN := 260.0
const KEEP_DISTANCE_MAX := 390.0
const MOVE_SPEED := 63.8
const CAMERA_SAFE_MARGIN := 112.0
const HIDDEN_DISPERSAL_SPEED_SCALE := 0.72
const OVERSEER_RUNTIME_SCALE := Vector2(1.25, 1.25)

var body_radius := BODY_RADIUS
var feedback_weight := 2
var coin_value := 60
var shield_drop_value := 30.0
var health: Node
var projectile_parent: Node
var target_player: Node2D
var world_bounds := Rect2()
var arena_navigation: Node
var flash_timer := 0.0
var death_resolved := false
var tentacle_attack: Node
var attack_director: Node
var entrance_progress := 0.0
var entrance_resolved := false
var burn_status: RefCounted = BurnStatusScript.new()
var hidden_dispersion_direction := Vector2.ZERO
var hidden_dispersion_timer := 0.0
var boss_visual: Sprite2D
var boss_flash_material: ShaderMaterial

func setup(_wave_index: int, projectiles: Node, target: Node2D = null) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	scale = Vector2.ONE * 0.12
	rotation = -0.28
	modulate.a = 0.0
	projectile_parent = projectiles
	target_player = target
	tentacle_attack = TentacleAttackScript.new()
	tentacle_attack.name = "TentacleAttack"
	tentacle_attack.configure(self, target_player, projectile_parent)
	add_child(tentacle_attack)
	attack_director = BossAttackDirectorScript.new()
	attack_director.name = "BossAttackDirector"
	attack_director.reinforcements_requested.connect(func(count: int) -> void: reinforcements_requested.emit(self, count))
	attack_director.combat_cue.connect(func(cue: StringName) -> void: combat_cue.emit(cue))
	add_child(attack_director)
	attack_director.configure(self, target_player, projectile_parent, tentacle_attack, 0x0B055)
	health = HealthComponentScript.new()
	health.max_health = BASE_MAX_HEALTH
	health.health_changed.connect(_on_health_component_changed)
	add_child(health)

func get_tentacle_attack() -> Node:
	return tentacle_attack

func get_attack_director() -> Node:
	return attack_director

func start_tentacle_sweep(target_position: Vector2) -> bool:
	return tentacle_attack != null and tentacle_attack.start_sweep(target_position)

func start_tentacle_slam(target_positions: Array[Vector2]) -> bool:
	return tentacle_attack != null and tentacle_attack.start_slam(target_positions)

func advance_tentacle_attack(delta: float) -> void:
	if tentacle_attack != null:
		tentacle_attack.advance_attack(delta)

func cancel_tentacle_attack() -> void:
	if tentacle_attack != null:
		tentacle_attack.cancel_attack()

func cancel_boss_attacks() -> void:
	if attack_director != null:
		attack_director.shutdown()

func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"bosses")
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	collision.shape = circle
	add_child(collision)
	_create_boss_visual()
	queue_redraw()

func _physics_process(delta: float) -> void:
	_update_burn(delta)
	if death_resolved:
		return
	var player := get_target_player()
	if player != null:
		_update_visual_facing(player.global_position)
	if attack_director != null:
		attack_director.set_target_hidden(player == null and entrance_resolved)
		attack_director.advance(delta)
	_update_entrance_reveal()
	if flash_timer > 0.0:
		flash_timer = maxf(0.0, flash_timer - delta)
		boss_flash_material.set_shader_parameter("flash_amount", 1.0 if flash_timer > 0.0 else 0.0)
		queue_redraw()
	if attack_director != null and attack_director.is_movement_locked():
		velocity = Vector2.ZERO
		return
	if player == null:
		if is_target_hidden():
			_update_hidden_target_dispersion(delta)
		else:
			velocity = Vector2.ZERO
		return
	hidden_dispersion_timer = 0.0
	var direction := get_combat_movement_direction(player)
	velocity = direction * MOVE_SPEED * (1.0 - burn_status.get_slow_fraction())
	move_and_slide()
	_clamp_to_world_bounds()

func get_combat_movement_direction(player: Node2D) -> Vector2:
	var safe_rect := get_combat_safe_rect()
	if safe_rect.size != Vector2.ZERO and not safe_rect.has_point(global_position):
		var return_target := global_position.clamp(safe_rect.position, safe_rect.end - Vector2(0.001, 0.001))
		if return_target.distance_squared_to(global_position) <= 0.001:
			return_target = safe_rect.get_center()
		return _apply_arena_navigation((return_target - global_position).normalized(), return_target)
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance <= 0.01:
		return Vector2.RIGHT
	var toward_player := to_player / distance
	if distance < KEEP_DISTANCE_MIN:
		return _apply_arena_navigation(-toward_player, global_position - toward_player * 240.0, false)
	if distance > KEEP_DISTANCE_MAX:
		return _apply_arena_navigation(toward_player, player.global_position)
	var orbit := toward_player.orthogonal() * 0.35
	return _apply_arena_navigation(orbit, global_position + orbit.normalized() * 240.0, false)

func set_arena_navigation(navigation: Node) -> void:
	arena_navigation = navigation

func _apply_arena_navigation(desired: Vector2, target: Vector2, use_flow_field: bool = true) -> Vector2:
	if desired == Vector2.ZERO or arena_navigation == null or not arena_navigation.has_method("get_navigation_direction"):
		return desired
	var navigation_direction: Vector2
	if use_flow_field:
		navigation_direction = arena_navigation.get_navigation_direction(global_position, target, body_radius)
	elif arena_navigation.has_method("get_avoidance_direction"):
		navigation_direction = arena_navigation.get_avoidance_direction(global_position, desired, body_radius)
	if navigation_direction == Vector2.ZERO:
		return desired
	var magnitude := desired.length()
	return (navigation_direction * 0.78 + desired.normalized() * 0.22).normalized() * magnitude

func get_combat_safe_rect() -> Rect2:
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	var camera := viewport.get_camera_2d()
	var center := target_player.global_position if is_instance_valid(target_player) else global_position
	var zoom := Vector2.ONE
	if camera != null:
		center = camera.get_screen_center_position()
		zoom = camera.zoom.abs()
	var visible_size := Vector2(
		viewport_size.x / maxf(zoom.x, 0.001),
		viewport_size.y / maxf(zoom.y, 0.001)
	)
	var safe_rect := Rect2(center - visible_size * 0.5, visible_size).grow(-CAMERA_SAFE_MARGIN)
	if world_bounds.size != Vector2.ZERO:
		safe_rect = safe_rect.intersection(world_bounds.grow(-body_radius))
	return safe_rect

func _update_entrance_reveal() -> void:
	if entrance_resolved or attack_director == null:
		return
	var duration: float = maxf(attack_director.ENTRANCE_SECONDS, 0.01)
	entrance_progress = clampf(float(attack_director.state_elapsed) / duration, 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, entrance_progress)
	var overshoot := sin(entrance_progress * PI) * 0.12
	var visual_scale := lerpf(0.12, 1.0, eased) + overshoot
	scale = Vector2.ONE * visual_scale
	rotation = lerpf(-0.28, 0.0, eased)
	modulate.a = clampf(entrance_progress * 2.6, 0.0, 1.0)
	queue_redraw()
	if attack_director.get_state_name() != "ENTRANCE":
		entrance_resolved = true
		entrance_progress = 1.0
		scale = Vector2.ONE
		rotation = 0.0
		modulate.a = 1.0
		process_mode = Node.PROCESS_MODE_PAUSABLE
		entrance_finished.emit()

func get_target_player() -> Node2D:
	var target := target_player if is_instance_valid(target_player) else get_tree().get_first_node_in_group(&"player") as Node2D
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
	velocity = hidden_dispersion_direction * MOVE_SPEED * HIDDEN_DISPERSAL_SPEED_SCALE * (1.0 - burn_status.get_slow_fraction())
	move_and_slide()
	_clamp_to_world_bounds()

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

func take_damage(
	amount: float,
	source: StringName = DamageTypes.GENERIC,
	hit_direction: Vector2 = Vector2.ZERO
) -> bool:
	if health == null or death_resolved or not entrance_resolved:
		return false
	var health_before: float = health.current_health
	if not health.damage(amount):
		return false
	var killed := float(health.current_health) <= 0.0
	if attack_director != null and not killed:
		var resolved_phase := _resolve_phase(float(health.current_health), float(health.max_health))
		attack_director.set_health_phase(resolved_phase)
	var resolved_source: StringName = DamageTypes.resolve(source)
	var actual_damage := maxf(0.0, health_before - float(health.current_health))
	flash_timer = 0.08
	if boss_flash_material != null:
		boss_flash_material.set_shader_parameter("flash_amount", 1.0)
	queue_redraw()
	damage_resolved.emit(self, resolved_source, actual_damage, global_position, hit_direction, killed)
	hit.emit(resolved_source)
	if killed:
		_die(resolved_source)
	return killed

func get_phase() -> int:
	if health == null or float(health.max_health) <= 0.0:
		return 1
	return _resolve_phase(float(health.current_health), float(health.max_health))

func _resolve_phase(current: float, maximum: float) -> int:
	if maximum <= 0.0:
		return 1
	var ratio := current / maximum
	if ratio > 0.70:
		return 1
	if ratio > 0.35:
		return 2
	return 3

func get_feedback_weight() -> int:
	return feedback_weight

func _on_health_component_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum, get_phase())

func _die(source: StringName) -> void:
	if death_resolved:
		return
	death_resolved = true
	cancel_boss_attacks()
	velocity = Vector2.ZERO
	set_physics_process(false)
	died.emit(self, coin_value, source)
	queue_free()

func _clamp_to_world_bounds() -> void:
	if world_bounds.size == Vector2.ZERO:
		return
	var playable := world_bounds.grow(-body_radius)
	global_position = global_position.clamp(playable.position, playable.end - Vector2(0.001, 0.001))

func _draw() -> void:
	var cyan := Color("33fff2")
	var magenta := Color("f559bf")
	if not entrance_resolved:
		var reveal_radius := lerpf(150.0, 88.0, entrance_progress)
		draw_arc(Vector2.ZERO, reveal_radius, -PI * 0.5, PI * 1.5, 64, Color(cyan, 0.9 - entrance_progress * 0.35), 5.0)
		draw_arc(Vector2.ZERO, reveal_radius + 18.0, PI * 0.5, PI * 2.5, 64, Color(magenta, 0.75 - entrance_progress * 0.25), 3.0)

func _create_boss_visual() -> void:
	boss_visual = Sprite2D.new()
	boss_visual.name = "OverseerVisual"
	boss_visual.texture = OVERSEER_TEXTURE
	boss_visual.scale = OVERSEER_RUNTIME_SCALE
	boss_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	boss_visual.show_behind_parent = true
	boss_flash_material = ShaderMaterial.new()
	boss_flash_material.shader = HIT_FLASH_SHADER
	boss_flash_material.set_shader_parameter("flash_amount", 0.0)
	boss_visual.material = boss_flash_material
	add_child(boss_visual)

func _update_visual_facing(player_position: Vector2) -> void:
	if boss_visual != null:
		boss_visual.flip_h = player_position.x < global_position.x
