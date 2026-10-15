extends "res://scripts/actors/OverseerBoss.gd"
## Genuine native Archivist Actor. Still author-only until all three attacks pass.
const NATIVE_SCENE = preload("res://scenes/actors/native/spore_archivist_paper_v2.tscn")
const Motion = preload("res://scripts/components/NativeSporeArchivistMotion.gd")
const Combat = preload("res://scripts/components/SporeArchivistAttackDirector.gd")
const OriginSafety = preload("res://scripts/components/NativeProjectileOriginSafety.gd")
const Page = preload("res://scripts/components/ArchivePageProjectile.gd")
func setup(_wave_index: int,projectiles: Node,target: Node2D = null) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	projectile_parent = projectiles; target_player = target
	attack_director = Combat.new(); attack_director.name = "SporeArchivistAttackDirector"
	attack_director.reinforcements_requested.connect(func(count: int): reinforcements_requested.emit(self,count))
	attack_director.combat_cue.connect(func(cue: StringName): combat_cue.emit(cue))
	add_child(attack_director); attack_director.configure(self,target,projectiles)
	health = HealthComponentScript.new(); health.max_health = BASE_MAX_HEALTH
	health.health_changed.connect(_on_health_component_changed); add_child(health)
	scale = Vector2.ONE; rotation = 0; modulate.a = 1
func get_display_name() -> String: return "藏孢书记 · 页刃 / 菌封 / 有限孢群"
func _create_boss_visual() -> void:
	boss_visual = NATIVE_SCENE.instantiate(); boss_visual.name = "NativeSporeArchivist"
	boss_visual.show_behind_parent = true; add_child(boss_visual)
	boss_flash_material = ShaderMaterial.new(); boss_flash_material.shader = HIT_FLASH_SHADER
	boss_flash_material.set_shader_parameter("flash_amount",0.0)
	boss_visual.get_node("Facing/Skin").material = boss_flash_material
	boss_motion = Motion.new(boss_visual); boss_motion.update(self,0)
func get_safe_page_origin() -> Vector2:
	if boss_visual==null: return global_position
	var at: Vector2 = boss_visual.get_node("Facing/Skeleton2D/Torso/Book/Spine/IndexOrigin").global_position
	return OriginSafety.resolve(self,at,Page.HIT_RADIUS)
func get_safe_seal_origin() -> Vector2:
	if boss_visual==null: return global_position
	var at: Vector2 = boss_visual.get_node("Facing/Skeleton2D/Torso/Head/Cap/SporeOrigin").global_position
	return OriginSafety.resolve(self,at,1)
func get_safe_brood_origin() -> Vector2:
	if boss_visual==null: return global_position
	var at: Vector2 = boss_visual.get_node("Facing/Skeleton2D/Torso/SporeSatchel/ColonyOrigin").global_position
	return OriginSafety.resolve(self,at,16)
func _update_visual_facing(player_position: Vector2) -> void:
	if boss_visual!=null:
		var at: Vector2 = global_position+attack_director.locked_direction*100 if attack_director.is_attacking() else player_position
		boss_visual.set_facing_left(at.x<global_position.x)
func get_target_player() -> Node2D:
	# No global player-group fallback: do not acquire another world's player.
	if not is_instance_valid(target_player) or not target_player.is_inside_tree() or target_player.is_queued_for_deletion(): return null
	var target_health = target_player.get("health")
	if not is_instance_valid(target_health) or target_health.current_health<=0: return null
	if target_player.has_method("is_stealthed") and target_player.is_stealthed(): return null
	return target_player
func should_show_attack_marker() -> bool:
	return attack_director!=null and attack_director.action_stage==attack_director.Stage.WARNING and not death_resolved and not attack_director.target_hidden
