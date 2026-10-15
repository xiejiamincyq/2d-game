extends "res://scripts/actors/Enemy.gd"
## Regional ranged path-denial actor, not the old instant explosive lobber.
const PLANTER_SCENE = preload("res://scenes/actors/native/capsule_planter_paper_v1.tscn")
const Plant = preload("res://scripts/components/CapsulePlantHazard.gd")
const PlantMotion = preload("res://scripts/components/NativeCapsulePlanterMotion.gd")
signal plant_prepared(plant: Node)
var difficulty_index := 0
var planned_plant_position := Vector2.ZERO
var pending_plant := false
var owned_plants: Array[WeakRef] = []
func setup(_enemy_kind: EnemyKind,wave_index: int,shots: Node,target: Node2D = null) -> void:
	super.setup(EnemyKind.SPITTER,wave_index,shots,target)
	difficulty_index = wave_index
	health.max_health = 40.0*(1.0+float(wave_index)*0.13)
	body_radius = 16
	speed = 118
	ranged_keep_min = 170
	ranged_keep_max = 260
	ranged_windup_duration = AttackTiming.RANGED_WARNING
func _create_native_visual(_scene: PackedScene = NATIVE_SCRAPPER) -> void:
	super._create_native_visual(PLANTER_SCENE)
	static_visual_half_height = 57
	native_motion = PlantMotion.new(native_visual)
func _get_ranged_desired_velocity(to_player: Vector2,safe_rect: Rect2 = Rect2()) -> Vector2:
	return Vector2.ZERO if ranged_is_winding_up else super._get_ranged_desired_velocity(to_player,safe_rect)
func _is_in_visible_engagement_zone(player: Node2D) -> bool:
	return is_instance_valid(player) and global_position.distance_to(player.global_position)<=360 and get_camera_safe_rect().has_point(global_position)
func _update_spitter(delta: float,player: Node2D) -> void:
	if ranged_is_winding_up:
		ranged_windup_remaining -= delta
		if ranged_windup_remaining<=0:
			ranged_is_winding_up = false
			_fire_spitter()
		_queue_visual_redraw()
		return
	shoot_cooldown = maxf(0,shoot_cooldown-delta)
	if shoot_cooldown>0 or get_owned_plant_count()>=2 or not _is_in_visible_engagement_zone(player): return
	if not projectile_parent is Node2D or projectile_parent.is_queued_for_deletion(): return
	var forward := global_position.direction_to(player.global_position)
	if forward==Vector2.ZERO: forward = Vector2.RIGHT
	for distance in [56.0,48.0]:
		for angle in [0.0,40.0,-40.0]:
			var at: Vector2 = global_position+forward.rotated(deg_to_rad(angle))*distance
			if not _is_safe_plant_position(at): continue
			planned_plant_position = at
			pending_plant = true
			ranged_is_winding_up = true
			ranged_windup_remaining = ranged_windup_duration
			shoot_cooldown = 2.6
			_queue_visual_redraw()
			return
func _fire_spitter() -> void:
	if not pending_plant: return
	pending_plant = false # Consume before callbacks/deferred admission.
	if not can_commit_plant(planned_plant_position) or get_owned_plant_count()>=2: return
	var plant := Plant.new()
	plant.target_player = get_target_player()
	plant.difficulty_index = difficulty_index
	owned_plants.append(weakref(plant)) # Pending births count toward the cap.
	plant_prepared.emit(plant)
	plant.call_deferred("complete_placement",weakref(self),weakref(projectile_parent),planned_plant_position)
	native_motion.notify_shot()
func can_commit_plant(at: Vector2) -> bool:
	if death_resolved or is_queued_for_deletion() or not is_inside_tree() or spawn_impulse_remaining>0: return false
	if not is_instance_valid(projectile_parent) or not projectile_parent.is_inside_tree() or projectile_parent.is_queued_for_deletion(): return false
	var target := get_target_player()
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion(): return false
	var target_health = target.get("health")
	if target_health!=null and target_health.current_health<=0: return false
	return _is_safe_plant_position(at)
func _is_safe_plant_position(at: Vector2) -> bool:
	if world_bounds.size!=Vector2.ZERO and not world_bounds.grow(-32).has_point(at): return false
	if arena_navigation!=null and arena_navigation.has_method("is_position_walkable") and not arena_navigation.is_position_walkable(at,32): return false
	var space := get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(global_position,at,collision_mask,[get_rid()])
	if not space.intersect_ray(ray).is_empty(): return false
	var circle := CircleShape2D.new()
	circle.radius = 32 # Entire danger rim, not only the 9px destructible body.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0,at)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	return space.intersect_shape(query,1).is_empty()
func get_owned_plant_count() -> int:
	# Retire expired leases as well as counting live/pending births.
	for index in range(owned_plants.size()-1,-1,-1):
		var plant = owned_plants[index].get_ref()
		if not is_instance_valid(plant) or plant.resolved or plant.is_queued_for_deletion(): owned_plants.remove_at(index)
	return owned_plants.size()
func _cancel_native_ranged_windup() -> void:
	pending_plant = false
	if ranged_is_winding_up:
		ranged_is_winding_up = false
		ranged_windup_remaining = 0
		shoot_cooldown = maxf(shoot_cooldown,0.3)
		_queue_visual_redraw()
func _disarm_owned_plants() -> void:
	for reference in owned_plants:
		var plant = reference.get_ref()
		# The chapter, not a defeated launcher, owns an admitted incubation pod.
		if is_instance_valid(plant) and not (plant.chapter_owned and plant.is_inside_tree()): plant.disarm()
	owned_plants.clear()
func _exit_tree() -> void: _disarm_owned_plants()
func _die(source: StringName) -> void:
	_cancel_native_ranged_windup()
	_disarm_owned_plants()
	super._die(source)
func _draw_ground_warning() -> void: pass # Only compact head cue; no old acid/lob warning.
func _draw() -> void:
	pass # Native body and actor-owned WorldStatus draw separately.
