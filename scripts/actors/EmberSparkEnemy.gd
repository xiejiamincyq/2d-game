extends "res://scripts/actors/Enemy.gd"
## Ordinary second-region scatterer, not a Boss or a palette-only spitter.
const SPARK_SCENE = preload("res://scenes/actors/native/ember_spark_paper_v1.tscn")
const SparkMotion = preload("res://scripts/components/NativeEmberSparkMotion.gd")
func setup(_enemy_kind: EnemyKind,wave_index: int,projectiles: Node,target: Node2D = null) -> void:
	super.setup(EnemyKind.SPITTER,wave_index,projectiles,target)
	health.max_health = 34.0*(1.0+float(wave_index)*0.13)
	body_radius = 16.0
	contact_damage = 15.0
	speed = 120.0
	ranged_keep_min = 200.0
	ranged_keep_max = 290.0
func _create_native_visual(_scene: PackedScene = NATIVE_SCRAPPER) -> void:
	super._create_native_visual(SPARK_SCENE)
	static_visual_half_height = 53.0
	native_motion = SparkMotion.new(native_visual)
func _is_in_visible_engagement_zone(player: Node2D) -> bool:
	return is_instance_valid(player) and global_position.distance_to(player.global_position)<=330.0 and get_camera_safe_rect().has_point(global_position)
func _cancel_native_ranged_windup() -> void:
	if ranged_is_winding_up:
		ranged_is_winding_up = false
		ranged_windup_remaining = 0.0
		shoot_cooldown = maxf(shoot_cooldown,0.25)
		_queue_visual_redraw()
func _draw() -> void:
	pass # Native body and actor-owned WorldStatus draw separately.
func _fire_spitter() -> void:
	if death_resolved or projectile_parent==null or get_target_player()==null:
		return
	var origin: Vector2 = native_motion.get_safe_muzzle(self)
	var direction := (ranged_target_position-origin).normalized()
	if direction==Vector2.ZERO:
		return
	for angle in [-15,0,15]:
		var shot := ProjectileScript.new()
		shot.velocity = direction.rotated(deg_to_rad(angle))*280.0
		shot.damage = 9.0
		shot.radius = 4.0
		shot.lifetime = 1.1
		shot.target_group = &"player"
		shot.tint = HostilePalette.CORAL
		shot.world_bounds = world_bounds
		projectile_parent.add_child(shot)
		shot.global_position = origin
	native_motion.notify_shot()
