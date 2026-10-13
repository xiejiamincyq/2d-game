extends "res://scripts/actors/OverseerBoss.gd"
## New Salt combat/body, shared health/navigation/death/HUD contracts only.
const NATIVE_SCENE = preload("res://scenes/actors/native/tide_shell_paper_v2.tscn")
const Motion = preload("res://scripts/components/NativeTideShellMotion.gd")
const TideCombat = preload("res://scripts/components/TideShellAttackDirector.gd")
const OriginSafety = preload("res://scripts/components/NativeProjectileOriginSafety.gd")
func setup(_wave_index: int,projectiles: Node,target: Node2D = null) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	projectile_parent = projectiles; target_player = target
	attack_director = TideCombat.new(); attack_director.name = "TideShellAttackDirector"
	attack_director.reinforcements_requested.connect(func(count: int): reinforcements_requested.emit(self,count))
	attack_director.combat_cue.connect(func(cue: StringName): combat_cue.emit(cue))
	add_child(attack_director); attack_director.configure(self,target,projectiles)
	health = HealthComponentScript.new(); health.max_health = BASE_MAX_HEALTH
	health.health_changed.connect(_on_health_component_changed); add_child(health)
	scale = Vector2.ONE; rotation = 0; modulate.a = 1
func get_display_name() -> String: return "潮壳巨兽 · 空心环潮 / 侧钳横扫 / 盐壳喷射"
func _create_boss_visual() -> void:
	boss_visual = NATIVE_SCENE.instantiate(); boss_visual.name = "NativeTideShell"
	boss_visual.show_behind_parent = true; add_child(boss_visual)
	boss_flash_material = ShaderMaterial.new(); boss_flash_material.shader = HIT_FLASH_SHADER
	boss_flash_material.set_shader_parameter("flash_amount",0.0)
	boss_visual.get_node("Facing/Skin").material = boss_flash_material
	boss_motion = Motion.new(boss_visual); boss_motion.update(self,0)
func get_safe_salt_origin() -> Vector2:
	if boss_visual==null: return global_position
	var socket: Vector2 = boss_visual.get_node("Facing/Skeleton2D/Torso/Head/Jaw/SaltOrigin").global_position
	return OriginSafety.resolve(self,socket,6)
func get_claw_origins() -> Array[Vector2]:
	if boss_visual==null: return []
	return [boss_visual.get_node("Facing/Skeleton2D/Torso/ShoulderL/ArmL/PincerL/ClawOrigin").global_position,boss_visual.get_node("Facing/Skeleton2D/Torso/ShoulderR/ArmR/PincerR/ClawOrigin").global_position]
func _update_visual_facing(player_position: Vector2) -> void:
	if boss_visual!=null:
		var at: Vector2 = global_position+attack_director.locked_direction*100 if attack_director.is_attacking() else player_position
		boss_visual.set_facing_left(at.x<global_position.x)
func get_combat_movement_direction(player: Node2D) -> Vector2:
	var safe := get_combat_safe_rect()
	if safe.size!=Vector2.ZERO and not safe.has_point(global_position): return super.get_combat_movement_direction(player)
	# Approach a lateral claw position instead of rotating a frontal crab rig 360°.
	var side := -1.0 if global_position.x<player.global_position.x else 1.0
	var destination := player.global_position+Vector2(side*120,28)
	var offset := destination-global_position
	return _apply_arena_navigation(offset.normalized(),destination) if offset.length()>15 else Vector2.ZERO
func should_show_attack_marker() -> bool:
	return attack_director!=null and attack_director.action_stage==attack_director.Stage.WARNING and not death_resolved and not attack_director.target_hidden
