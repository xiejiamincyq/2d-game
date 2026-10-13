extends "res://scripts/actors/Enemy.gd"
## Ordinary fifth-region flanker, visible at all times; actual collision dash.
const SHADE_SCENE = preload("res://scenes/actors/native/circling_shade_paper_v1.tscn")
const Ambush = preload("res://scripts/components/ShadeAmbushAttack.gd")
func _ready() -> void:
	super._ready()
	# This actor draws only compact strike strokes, not a ground danger field.
	# Keep the hit visible when the player overlaps the hook.
	ground_warning.z_index = 1
func setup(_enemy_kind: EnemyKind,wave_index: int,shots: Node,target: Node2D = null) -> void:
	super.setup(EnemyKind.SCRAPPER,wave_index,shots,target)
	health.max_health = 32*(1.0+float(wave_index)*0.13)
	body_radius = 15
	speed = 160
	contact_damage = 18
	basic_attack = Ambush.new()
	basic_attack.cooldown = 0.7+posmod(formation_slot_index,6)*0.1
func _create_native_visual(_scene: PackedScene = NATIVE_SCRAPPER) -> void:
	super._create_native_visual(SHADE_SCENE)
	static_visual_half_height = 58
func _get_melee_desired_velocity(to_player: Vector2) -> Vector2:
	var distance := to_player.length()
	if distance<0.001: return Vector2.ZERO
	var radial := to_player/distance
	if distance<=145 or distance>=430: return radial
	var side := 1.0 if formation_slot_index%2==0 else -1.0
	return (radial*0.5+radial.orthogonal()*side).normalized()
func _apply_arena_navigation(desired: Vector2,player_position: Vector2) -> Vector2:
	if arena_navigation!=null and arena_navigation.has_method("get_avoidance_direction"):
		var safe: Vector2 = arena_navigation.get_avoidance_direction(global_position,desired,body_radius)
		if safe.is_equal_approx(desired.normalized()): return desired
	return super._apply_arena_navigation(desired,player_position)
func _update_melee_attack(_delta: float,_player: Node2D,_distance: float) -> void:
	pass # Ambush owns all damage; never an additional legacy contact strike.
func _die(source: StringName) -> void:
	if death_resolved: return
	basic_attack.cancel()
	super._die(source)
func _draw() -> void:
	pass # Native body and actor-owned WorldStatus draw separately.
