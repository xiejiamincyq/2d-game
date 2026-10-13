extends "res://scripts/actors/Enemy.gd"
## Ordinary third-region flanker, with native claws and collision-safe navigation.
const CRAB_SCENE = preload("res://scenes/actors/native/flanking_crab_paper_v1.tscn")
const Pincer = preload("res://scripts/components/CrabPincerAttack.gd")
func setup(_enemy_kind: EnemyKind,wave_index: int,projectiles: Node,target: Node2D = null) -> void:
	super.setup(EnemyKind.SCRAPPER,wave_index,projectiles,target)
	health.max_health = 42.0*(1.0+float(wave_index)*0.13)
	body_radius = 16.0
	contact_damage = 21.0
	speed = 140.0
	coin_value = 3
	basic_attack = Pincer.new()
	basic_attack.cooldown = 0.8+posmod(formation_slot_index,6)*0.12
func _create_native_visual(_scene: PackedScene = NATIVE_SCRAPPER) -> void:
	super._create_native_visual(CRAB_SCENE)
	static_visual_half_height = 49.0
func _get_melee_desired_velocity(to_player: Vector2) -> Vector2:
	var distance := to_player.length()
	if distance<0.001: return super._get_melee_desired_velocity(to_player)
	var radial := to_player/distance
	if distance<=80 or distance>=400: return radial
	var side := 1.0 if formation_slot_index%2==0 else -1.0
	return (radial*0.65+radial.orthogonal()*side*0.9).normalized()
func _apply_arena_navigation(desired: Vector2,player_position: Vector2) -> Vector2:
	if arena_navigation!=null and arena_navigation.has_method("get_avoidance_direction"):
		var safe: Vector2 = arena_navigation.get_avoidance_direction(global_position,desired,body_radius)
		if safe.is_equal_approx(desired.normalized()): return desired
	# Blocked actors share the target's flow field, never one goal per crab.
	return super._apply_arena_navigation(desired,player_position)
func _update_melee_attack(_delta: float,_player: Node2D,_distance: float) -> void:
	pass # All claw damage is owned by the cancellable pincer, including contact.
func _draw() -> void:
	pass # Native body and actor-owned WorldStatus draw separately.
