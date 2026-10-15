extends "res://scripts/actors/Enemy.gd"
## Sixth-region ordinary hybrid. No large-enemy attack work or old spit visual.
const ELITE_SCENE = preload("res://scenes/actors/native/rift_elite_paper_v1.tscn")
const Hybrid = preload("res://scripts/components/EliteHybridAttack.gd")
const EliteMotion = preload("res://scripts/components/NativeRiftEliteMotion.gd")
const Shard = preload("res://scripts/components/RiftShardProjectile.gd")
func setup(_enemy_kind: EnemyKind,wave_index: int,shots: Node,target: Node2D = null) -> void:
	super.setup(EnemyKind.SPITTER,wave_index,shots,target)
	health.max_health = 54*(1.0+float(wave_index)*0.13)
	body_radius = 16
	speed = 125
	contact_damage = 24
	ranged_keep_min = 90
	ranged_keep_max = 180
	basic_attack = Hybrid.new()
	basic_attack.cooldown = 0.8+posmod(formation_slot_index,6)*0.1
func _ready() -> void:
	super._ready()
	ground_warning.z_index = 1
func _create_native_visual(_scene: PackedScene = NATIVE_SCRAPPER) -> void:
	super._create_native_visual(ELITE_SCENE)
	static_visual_half_height = 55
	native_motion = EliteMotion.new(native_visual)
func _resolve_flock_velocity(desired: Vector2,to_player: Vector2,delta: float) -> Vector2:
	if basic_attack.stage in [basic_attack.Stage.WARNING,basic_attack.Stage.ACTIVE]: return Vector2.ZERO
	return super._resolve_flock_velocity(desired,to_player,delta)
func _update_spitter(delta: float,player: Node2D) -> void:
	var was_active: bool = basic_attack.is_active()
	basic_attack.consider(self,player,delta)
	# consider() creates the action now; delta describes time before that birth.
	if not was_active and basic_attack.is_active():
		_queue_visual_redraw()
		return
	basic_attack.advance(delta)
	if basic_attack.take_release():
		# Sample the release pose first so the real Bone2D muzzle is current.
		native_motion.update(self,0)
		_fire_shards()
	basic_attack.resolve_hit(self,player)
	_queue_visual_redraw()
func _fire_shards() -> void:
	if death_resolved or is_queued_for_deletion() or get_target_player()==null: return
	if not is_instance_valid(projectile_parent) or projectile_parent.is_queued_for_deletion() or not projectile_parent.is_inside_tree(): return
	var muzzle: Vector2 = native_motion.get_safe_muzzle(self)
	var direction: Vector2 = muzzle.direction_to(basic_attack.target_position)
	if direction==Vector2.ZERO: return
	for angle in [-12,12]:
		var shot := Shard.new()
		shot.velocity = direction.rotated(deg_to_rad(angle))*320
		shot.world_bounds = world_bounds
		projectile_parent.add_child(shot)
		shot.global_position = muzzle
func should_show_attack_marker() -> bool:
	return not death_resolved and not is_target_hidden() and basic_attack.stage==basic_attack.Stage.WARNING
func _draw_ground_warning() -> void:
	basic_attack.draw_strikes(ground_warning,self)
func _draw() -> void:
	pass # Native body and actor-owned WorldStatus draw separately.
func _die(source: StringName) -> void:
	if death_resolved: return
	basic_attack.cancel()
	super._die(source)
