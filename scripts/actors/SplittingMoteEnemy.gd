extends "res://scripts/actors/Enemy.gd"
## One generation of actual enemies, prepared before parent death settlement.
signal offspring_prepared(children: Array[CharacterBody2D])
signal birth_cancelled(actor: Node)
const MOTE_SCENE = preload("res://scenes/actors/native/splitting_mote_paper_v1.tscn")
const Pulse = preload("res://scripts/components/MotePulseAttack.gd")
var is_fragment := false
var split_resolved := false
var death_in_progress := false
var difficulty_index := 0
func setup(_enemy_kind: EnemyKind,wave_index: int,projectiles: Node,target: Node2D = null) -> void:
	super.setup(EnemyKind.SCRAPPER,wave_index,projectiles,target)
	difficulty_index = wave_index
	health.max_health = (14.0 if is_fragment else 48.0)*(1.0+float(wave_index)*0.13)
	body_radius = 9.0 if is_fragment else 16.0
	contact_damage = 12.0 if is_fragment else 21.0
	speed = 155.0 if is_fragment else 105.0
	coin_value = 0 if is_fragment else 3
	basic_attack = Pulse.new()
	basic_attack.cooldown = 0.7+posmod(formation_slot_index,6)*0.1
func _create_native_visual(_scene: PackedScene = NATIVE_SCRAPPER) -> void:
	super._create_native_visual(MOTE_SCENE)
	native_visual.scale = Vector2.ONE*(0.62 if is_fragment else 1.0)
	static_visual_half_height = 52.0*(0.62 if is_fragment else 1.0)
func _update_melee_attack(_delta: float,_player: Node2D,_distance: float) -> void:
	pass # All near-range damage is owned by the cancellable pulse controller.
func _die(source: StringName) -> void:
	if death_resolved or death_in_progress or health==null or health.current_health>0: return
	death_in_progress = true
	if not is_fragment and not split_resolved:
		split_resolved = true
		var children := _prepare_fragments()
		if not children.is_empty(): offspring_prepared.emit(children)
	super._die(source)
func _prepare_fragments() -> Array[CharacterBody2D]:
	var result: Array[CharacterBody2D] = []
	var destination := get_parent() as Node2D
	if destination==null or destination.is_queued_for_deletion(): return result
	var positions: Array[Vector2] = []
	for radius in [30.0,48.0,66.0]:
		for index in 12:
			var at: Vector2 = global_position+Vector2.RIGHT.rotated(index*TAU/12)*radius
			if not _is_safe_birth(at): continue
			var overlaps := false
			for other in positions:
				if at.distance_to(other)<22: overlaps = true
			if overlaps: continue
			var child = get_script().new()
			child.is_fragment = true
			child.setup(EnemyKind.SCRAPPER,difficulty_index,projectile_parent,target_player)
			child.world_bounds = world_bounds
			child.set_arena_navigation(arena_navigation)
			child.position = destination.to_local(at)
			child.apply_spawn_impulse(Vector2.ZERO,0.18)
			# Child owns its deferred birth so a freed/queued owner cannot orphan it.
			child.call_deferred("_complete_split_birth",weakref(destination),at)
			positions.append(at)
			result.append(child)
			if result.size()==2: return result
	return result
func _is_safe_birth(at: Vector2) -> bool:
	if world_bounds.size!=Vector2.ZERO and not world_bounds.grow(-9).has_point(at): return false
	if arena_navigation!=null and arena_navigation.has_method("is_position_walkable") and not arena_navigation.is_position_walkable(at,9): return false
	var shape := CircleShape2D.new()
	shape.radius = 9
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0,at)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
func _complete_split_birth(owner_ref: WeakRef,at: Vector2) -> void:
	if is_queued_for_deletion(): return # Membership can reject a prepared birth.
	var destination = owner_ref.get_ref()
	if not is_instance_valid(destination) or not destination.is_inside_tree() or destination.is_queued_for_deletion():
		birth_cancelled.emit(self)
		queue_free() # A deferred method is object-locked until it returns.
		return
	position = destination.to_local(at)
	destination.add_child(self)
func _draw() -> void:
	pass # Native body and actor-owned WorldStatus draw separately.
