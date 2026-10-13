extends "res://scripts/actors/OverseerBoss.gd"
## Sixth native Actor; automatic combat is tested separately from the gated chapter entry.
const NATIVE_SCENE = preload("res://scenes/actors/native/rift_observer_paper_v2.tscn")
const Motion = preload("res://scripts/components/NativeRiftObserverMotion.gd")
const Combat = preload("res://scripts/components/RiftObserverAttackDirector.gd")
const OriginSafety = preload("res://scripts/components/NativeProjectileOriginSafety.gd")
const SOCKETS := {
	&"beam":"Torso/Lens/Pupil/AimOrigin",
	&"probes_left":"Torso/ScopeArmL/ElbowL/ProbeL/SensorOrigin",
	&"probes_right":"Torso/ScopeArmR/ElbowR/ProbeR/SensorOrigin",
	&"refract":"Torso/Beacon/PhaseOrigin"}
func setup(_wave_index: int,projectiles: Node,target: Node2D = null) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS; projectile_parent = projectiles; target_player = target
	health = HealthComponentScript.new(); health.max_health = BASE_MAX_HEALTH
	health.health_changed.connect(_on_health_component_changed); add_child(health)
	attack_director = Combat.new(); attack_director.name = "RiftObserverAttackDirector"
	attack_director.combat_cue.connect(func(cue: StringName): combat_cue.emit(cue))
	add_child(attack_director); attack_director.configure(self,target,projectiles)
	scale = Vector2.ONE; rotation = 0; modulate.a = 1
func get_display_name() -> String: return "裂隙观测者 · 窄束 / 探针 / 折射"
func _create_boss_visual() -> void:
	boss_visual = NATIVE_SCENE.instantiate(); boss_visual.name = "NativeRiftObserver"
	boss_visual.show_behind_parent = true; add_child(boss_visual)
	boss_flash_material = ShaderMaterial.new(); boss_flash_material.shader = HIT_FLASH_SHADER
	boss_flash_material.set_shader_parameter("flash_amount",0.0); boss_visual.get_node("Facing/Skin").material = boss_flash_material
	boss_motion = Motion.new(boss_visual); boss_motion.update(self,0)
func get_action_origin(socket: StringName,radius: float,require_socket: bool = false) -> Vector2:
	var at: Vector2 = boss_visual.skeleton.get_node(SOCKETS[socket]).global_position
	var safe := OriginSafety.resolve(self,at,radius)
	# Strict articulated birth never substitutes the centre for a blocked bone.
	return Vector2.INF if require_socket and not safe.is_equal_approx(at) else safe
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
	return to_local(boss_visual.skeleton.get_node(SOCKETS[&"refract"]).global_position).y-20 if boss_visual!=null else -126
func get_combat_movement_direction(player: Node2D) -> Vector2:
	var safe_rect := get_combat_safe_rect()
	if safe_rect.size!=Vector2.ZERO and not safe_rect.has_point(global_position): return super.get_combat_movement_direction(player)
	var offset := player.global_position-global_position; var distance := offset.length()
	if distance>290: return _apply_arena_navigation(offset.normalized(),player.global_position)
	if distance<190: return _apply_arena_navigation(-offset.normalized(),global_position-offset.normalized()*120,false)
	var orbit := offset.normalized().orthogonal()*0.35
	return _apply_arena_navigation(orbit,global_position+orbit.normalized()*120,false)
