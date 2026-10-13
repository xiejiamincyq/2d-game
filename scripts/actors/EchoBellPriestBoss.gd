extends "res://scripts/actors/OverseerBoss.gd"
## Original native priest. No chapter factory entry until all combat gates pass.
const NATIVE_SCENE = preload("res://scenes/actors/native/bell_priest_paper_v2.tscn")
const Motion = preload("res://scripts/components/NativeBellPriestMotion.gd")
const Combat = preload("res://scripts/components/BellPriestAttackDirector.gd")
const OriginSafety = preload("res://scripts/components/NativeProjectileOriginSafety.gd")
const SOCKETS := {
	&"bell":"Torso/Bell/Clapper/BeatOrigin",
	&"crown":"Torso/Head/Crown/RecallOrigin",
	&"pendant_left":"Torso/ArmL/ForearmL/HandL/ChainL/PendantL/PendantOrigin",
	&"pendant_right":"Torso/ArmR/ForearmR/HandR/ChainR/PendantR/PendantOrigin"}
func setup(_wave_index: int,projectiles: Node,target: Node2D = null) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	projectile_parent = projectiles; target_player = target
	attack_director = Combat.new(); attack_director.name = "BellPriestAttackDirector"
	attack_director.combat_cue.connect(func(cue: StringName): combat_cue.emit(cue))
	add_child(attack_director); attack_director.configure(self,target,projectiles)
	health = HealthComponentScript.new(); health.max_health = BASE_MAX_HEALTH
	health.health_changed.connect(_on_health_component_changed); add_child(health)
	scale = Vector2.ONE; rotation = 0; modulate.a = 1
func get_display_name() -> String: return "钟骨司祭 · 钟槌 / 双坠 / 冠钟"
func _create_boss_visual() -> void:
	boss_visual = NATIVE_SCENE.instantiate(); boss_visual.name = "NativeBellPriest"
	boss_visual.show_behind_parent = true; add_child(boss_visual)
	boss_flash_material = ShaderMaterial.new(); boss_flash_material.shader = HIT_FLASH_SHADER
	boss_flash_material.set_shader_parameter("flash_amount",0.0)
	boss_visual.get_node("Facing/Skin").material = boss_flash_material
	boss_motion = Motion.new(boss_visual); boss_motion.update(self,0)
func get_action_origin(socket: StringName,radius: float) -> Vector2:
	var at: Vector2 = boss_visual.skeleton.get_node(SOCKETS[socket]).global_position
	return OriginSafety.resolve(self,at,radius)
func _update_visual_facing(player_position: Vector2) -> void:
	if boss_visual!=null:
		var at: Vector2 = global_position+attack_director.locked_direction*100 if attack_director.is_attacking() else player_position
		boss_visual.set_facing_left(at.x<global_position.x)
func get_target_player() -> Node2D:
	if not is_instance_valid(target_player) or not target_player.is_inside_tree() or target_player.is_queued_for_deletion(): return null
	var target_health = target_player.get("health")
	if not is_instance_valid(target_health) or target_health.current_health<=0 or target_player.is_stealthed(): return null
	return target_player
func should_show_attack_marker() -> bool:
	return attack_director!=null and attack_director.action_stage==attack_director.Stage.WARNING and not death_resolved and not attack_director.target_hidden
func get_attack_marker_top() -> float:
	return to_local(boss_visual.skeleton.get_node(SOCKETS[&"crown"]).global_position).y-20 if boss_visual!=null else -126
func get_combat_movement_direction(player: Node2D) -> Vector2:
	var safe_rect := get_combat_safe_rect()
	if safe_rect.size!=Vector2.ZERO and not safe_rect.has_point(global_position):
		return super.get_combat_movement_direction(player)
	var offset := player.global_position-global_position; var distance := offset.length()
	if distance>155: return _apply_arena_navigation(offset.normalized(),player.global_position)
	if distance<95: return _apply_arena_navigation(-offset.normalized(),global_position-offset.normalized()*120,false)
	var orbit := offset.normalized().orthogonal()*0.35
	return _apply_arena_navigation(orbit,global_position+orbit.normalized()*120,false)
