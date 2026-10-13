extends "res://scripts/actors/Enemy.gd"
## Ordinary fifth-region spacing sentry, not a reskinned projectile spitter.
const SENTINEL_SCENE = preload("res://scenes/actors/native/echo_sentinel_paper_v1.tscn")
const Ring = preload("res://scripts/components/EchoRingAttack.gd")
const RingMotion = preload("res://scripts/components/NativeScrapperMotion.gd")
func setup(_enemy_kind: EnemyKind,wave_index: int,shots: Node,target: Node2D = null) -> void:
	super.setup(EnemyKind.SPITTER,wave_index,shots,target)
	health.max_health = 38.0*(1.0+float(wave_index)*0.13)
	body_radius = 16
	speed = 132
	contact_damage = 15
	ranged_keep_min = 90
	ranged_keep_max = 190
	basic_attack = Ring.new()
	basic_attack.cooldown = 0.6+posmod(formation_slot_index,6)*0.08
func _create_native_visual(_scene: PackedScene = NATIVE_SCRAPPER) -> void:
	super._create_native_visual(SENTINEL_SCENE)
	static_visual_half_height = 55
	native_motion = RingMotion.new(native_visual)
func _get_ranged_desired_velocity(to_player: Vector2,safe_rect: Rect2 = Rect2()) -> Vector2:
	if basic_attack.stage in [basic_attack.Stage.WARNING,basic_attack.Stage.ACTIVE]: return Vector2.ZERO
	return super._get_ranged_desired_velocity(to_player,safe_rect)
func _update_spitter(delta: float,player: Node2D) -> void:
	basic_attack.consider(self,player,delta)
	if basic_attack.is_active():
		basic_attack.advance(delta)
		basic_attack.resolve_hit(self,player)
	_queue_visual_redraw()
func _die(source: StringName) -> void:
	if death_resolved: return
	basic_attack.cancel()
	super._die(source)
func should_show_attack_marker() -> bool:
	return not death_resolved and not is_target_hidden() and basic_attack.stage==basic_attack.Stage.WARNING
func _draw_ground_warning() -> void: basic_attack.draw_warning(ground_warning,self)
func _draw() -> void:
	pass # Native body and actor-owned WorldStatus draw separately.
