extends "res://scripts/actors/Enemy.gd"
## Ordinary compass surveyor; stationary locked ground cut, never teleport.
const CUTTER_SCENE = preload("res://scenes/actors/native/space_cutter_paper_v1.tscn")
const Cut = preload("res://scripts/components/SpaceCutAttack.gd")
const CutMotion = preload("res://scripts/components/NativeScrapperMotion.gd")
func setup(_enemy_kind: EnemyKind,wave_index: int,shots: Node,target: Node2D = null) -> void:
	super.setup(EnemyKind.SPITTER,wave_index,shots,target)
	health.max_health = 38*(1.0+float(wave_index)*0.13)
	body_radius = 14
	speed = 112
	contact_damage = 21
	ranged_keep_min = 110
	ranged_keep_max = 170
	basic_attack = Cut.new()
	basic_attack.cooldown = 1.0+posmod(formation_slot_index,6)*0.1
func _ready() -> void:
	super._ready()
	ground_warning.z_index = 1
func _create_native_visual(_scene: PackedScene = NATIVE_SCRAPPER) -> void:
	super._create_native_visual(CUTTER_SCENE)
	static_visual_half_height = 48
	native_motion = CutMotion.new(native_visual)
func _update_enemy_facing(target_position: Vector2) -> void:
	if basic_attack.is_active():
		target_position = global_position+basic_attack.direction*100
	super._update_enemy_facing(target_position)
func _resolve_flock_velocity(desired: Vector2,to_player: Vector2,delta: float) -> Vector2:
	if basic_attack.stage in [basic_attack.Stage.WARNING,basic_attack.Stage.ACTIVE]: return Vector2.ZERO
	return super._resolve_flock_velocity(desired,to_player,delta)
func _update_spitter(delta: float,player: Node2D) -> void:
	basic_attack.consider(self,player,delta)
	basic_attack.advance(delta)
	basic_attack.resolve_hit(self,player)
	_queue_visual_redraw()
func should_show_attack_marker() -> bool:
	return not death_resolved and not is_target_hidden() and basic_attack.stage==basic_attack.Stage.WARNING
func _draw_ground_warning() -> void:
	basic_attack.draw_line_cut(ground_warning,self)
func _draw() -> void:
	pass # Native body and actor-owned WorldStatus draw separately.
func _die(source: StringName) -> void:
	if death_resolved: return
	basic_attack.cancel()
	super._die(source)
