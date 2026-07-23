extends CharacterBody2D
class_name OverseerBoss

signal died(boss: Node, coin_value: int, source: StringName)
signal hit(source: StringName)
signal health_changed(current: float, maximum: float, phase: int)
signal damage_resolved(
	boss: Node,
	source: StringName,
	amount: float,
	world_position: Vector2,
	direction: Vector2,
	killed: bool
)

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const HealthComponentScript = preload("res://scripts/components/HealthComponent.gd")
const TentacleAttackScript = preload("res://scripts/components/TentacleAttack.gd")

const DISPLAY_NAME := "深渊监工 / OVERSEER"
const BODY_RADIUS := 56.0
const VISUAL_RADIUS := 80.0
const BASE_MAX_HEALTH := 3000.0
const B1_PACING_PLACEHOLDER_SECONDS := 12.0
const KEEP_DISTANCE_MIN := 210.0
const KEEP_DISTANCE_MAX := 340.0
const MOVE_SPEED := 46.0

var body_radius := BODY_RADIUS
var feedback_weight := 2
var coin_value := 60
var shield_drop_value := 30.0
var health: Node
var projectile_parent: Node
var target_player: Node2D
var world_bounds := Rect2()
var flash_timer := 0.0
var death_resolved := false
var tentacle_attack: Node

func setup(_wave_index: int, projectiles: Node, target: Node2D = null) -> void:
	projectile_parent = projectiles
	target_player = target
	tentacle_attack = TentacleAttackScript.new()
	tentacle_attack.name = "TentacleAttack"
	tentacle_attack.configure(self, target_player, projectile_parent)
	add_child(tentacle_attack)
	health = HealthComponentScript.new()
	health.max_health = BASE_MAX_HEALTH
	health.health_changed.connect(_on_health_component_changed)
	add_child(health)

func get_tentacle_attack() -> Node:
	return tentacle_attack

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

func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"bosses")
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	collision.shape = circle
	add_child(collision)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer = maxf(0.0, flash_timer - delta)
		queue_redraw()
	var player := get_target_player()
	if player == null:
		velocity = Vector2.ZERO
		return
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var direction := Vector2.ZERO
	if distance > 0.01:
		if distance < KEEP_DISTANCE_MIN:
			direction = -to_player / distance
		elif distance > KEEP_DISTANCE_MAX:
			direction = to_player / distance
		else:
			direction = (to_player / distance).orthogonal() * 0.35
	velocity = direction * MOVE_SPEED
	move_and_slide()
	_clamp_to_world_bounds()

func get_target_player() -> Node2D:
	if is_instance_valid(target_player):
		return target_player
	return get_tree().get_first_node_in_group(&"player") as Node2D

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
	var actual_damage := maxf(0.0, health_before - float(health.current_health))
	var killed := float(health.current_health) <= 0.0
	flash_timer = 0.08
	queue_redraw()
	damage_resolved.emit(self, resolved_source, actual_damage, global_position, hit_direction, killed)
	hit.emit(resolved_source)
	if killed:
		_die(resolved_source)
	return killed

func get_phase() -> int:
	if health == null or float(health.max_health) <= 0.0:
		return 1
	var ratio: float = float(health.current_health) / float(health.max_health)
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
	cancel_tentacle_attack()
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
	var shell := Color("ffffff") if flash_timer > 0.0 else Color("101827")
	var inner_shell := Color("061019")
	var cyan := Color("33fff2")
	var magenta := Color("f559bf")
	var silhouette := PackedVector2Array()
	for index in range(16):
		var radius := VISUAL_RADIUS if index % 2 == 0 else VISUAL_RADIUS - 9.0
		silhouette.append(Vector2.RIGHT.rotated(TAU * float(index) / 16.0) * radius)
	draw_colored_polygon(silhouette, shell)
	draw_circle(Vector2.ZERO, 58.0, inner_shell)
	draw_arc(Vector2.ZERO, 69.0, 0.0, TAU, 48, Color(cyan, 0.88), 3.0)
	draw_circle(Vector2.ZERO, 25.0, Color(magenta, 0.82))
	draw_circle(Vector2.ZERO, 12.0, Color("240d31"))
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var start := Vector2.RIGHT.rotated(angle) * 35.0
		var finish := Vector2.RIGHT.rotated(angle) * 61.0
		draw_line(start, finish, Color(cyan, 0.72), 5.0)
