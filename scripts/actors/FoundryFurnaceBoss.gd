extends "res://scripts/actors/OverseerBoss.gd"
## Reuses Boss health/navigation contracts, none of the legacy attack nodes.
const NATIVE_SCENE = preload("res://scenes/actors/native/furnace_foreman_paper_v2.tscn")
const Motion = preload("res://scripts/components/NativeFurnaceForemanMotion.gd")
const FurnaceCombat = preload("res://scripts/components/FurnaceForemanAttackDirector.gd")
const OriginSafety = preload("res://scripts/components/NativeProjectileOriginSafety.gd")
var native_visual: Node2D
var native_motion: RefCounted
func setup(_wave_index: int,projectiles: Node,target: Node2D = null) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	projectile_parent = projectiles; target_player = target
	attack_director = FurnaceCombat.new(); attack_director.name = "FurnaceForemanAttackDirector"
	attack_director.reinforcements_requested.connect(func(count: int): reinforcements_requested.emit(self,count))
	attack_director.combat_cue.connect(func(cue: StringName): combat_cue.emit(cue))
	add_child(attack_director); attack_director.configure(self,target,projectiles)
	health = HealthComponentScript.new(); health.max_health = BASE_MAX_HEALTH
	health.health_changed.connect(_on_health_component_changed); add_child(health)
	scale = Vector2.ONE; rotation = 0; modulate.a = 1
func get_display_name() -> String: return "炉心督工 · 短扇喷 / 冲撞 / 热喷口"
func get_safe_heat_origin() -> Vector2:
	if native_visual==null: return global_position
	var socket: Vector2 = native_visual.get_node("Facing/Skeleton2D/Torso/Chest/VentR/VentOrigin").global_position
	return OriginSafety.resolve(self,socket,3)
func get_visual_node() -> Node2D: return native_visual
func get_visual_rect() -> Rect2:
	return native_visual.get_node("Facing").transform*native_visual.body_rect if native_visual!=null else Rect2()
func _create_boss_visual() -> void:
	native_visual = NATIVE_SCENE.instantiate(); native_visual.name = "NativeFurnaceForeman"
	native_visual.show_behind_parent = true; add_child(native_visual)
	boss_flash_material = ShaderMaterial.new(); boss_flash_material.shader = HIT_FLASH_SHADER
	boss_flash_material.set_shader_parameter("flash_amount",0.0)
	native_visual.get_node("Facing/Skin").material = boss_flash_material
	native_motion = Motion.new(native_visual); native_motion.update(self,0)
func _update_visual_facing(player_position: Vector2) -> void:
	if native_visual!=null:
		var at: Vector2 = global_position+attack_director.locked_direction*100 if attack_director.is_attacking() else player_position
		native_visual.set_facing_left(at.x<global_position.x)
func _update_boss_motion(delta: float) -> void:
	if native_visual!=null: native_motion.update(self,delta)
	queue_redraw()
func _update_entrance_reveal() -> void:
	if entrance_resolved or attack_director==null: return
	if attack_director.get_state_name()=="ENTRANCE":
		entrance_progress = clampf(float(attack_director.state_elapsed)/attack_director.ENTRANCE_SECONDS,0,1)
	else:
		entrance_resolved = true; entrance_progress = 1
		process_mode = Node.PROCESS_MODE_PAUSABLE; entrance_finished.emit()
func take_damage(amount: float,source: StringName = DamageTypes.GENERIC,hit_direction: Vector2 = Vector2.ZERO) -> bool:
	var before: float = health.current_health if health!=null else 0
	var killed := super.take_damage(amount,source,hit_direction)
	if not death_resolved and health!=null and health.current_health<before and native_visual!=null:
		native_motion.notify_hit(); native_motion.update(self,0)
	return killed
func _release_death_visual() -> void:
	if native_visual!=null:
		boss_flash_material.set_shader_parameter("flash_amount",0.0)
		native_motion.release_death(get_parent()); native_visual = null
func should_show_attack_marker() -> bool:
	return attack_director!=null and attack_director.action_stage==attack_director.Stage.WARNING and not death_resolved and not attack_director.target_hidden
