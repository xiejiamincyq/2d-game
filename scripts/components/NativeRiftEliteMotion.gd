extends "res://scripts/components/NativeScrapperMotion.gd"
## Visual-only hybrid clock: the release belongs to the actor, not these keys.
const MUZZLE := "Facing/Skeleton2D/Torso/ArmR/ForearmR/BladeR/Muzzle"
func update(actor: CharacterBody2D,delta: float) -> void:
	if not is_finite(delta) or delta<0: return
	super.update(actor,delta)
	var attack = actor.basic_attack
	if actor.spawn_impulse_remaining>0 or actor.get_target_player()==null: return
	if attack.is_active():
		view.set_facing_left(attack.direction.x<0)
	if attack.mode==attack.Mode.SHARDS and attack.stage in [attack.Stage.ACTIVE,attack.Stage.RECOVERY]:
		var active: float = clampf((attack.elapsed-attack.get_warning_duration())/attack.get_active_duration(),0,1)
		var recovery: float = clampf((attack.elapsed-attack.get_warning_duration()-attack.get_active_duration())/attack.RECOVERY,0,1)
		var duration: float = view.player.get_animation("shard_attack").length
		view.sample_clip("shard_attack",duration*(active*0.7+recovery*0.3))
func get_safe_muzzle(actor: CharacterBody2D) -> Vector2:
	var muzzle: Vector2 = view.get_node(MUZZLE).global_position
	if actor.world_bounds.size!=Vector2.ZERO and not actor.world_bounds.grow(-4).has_point(muzzle):
		return actor.global_position
	var space := actor.get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(actor.global_position,muzzle,actor.collision_mask,[actor.get_rid()])
	if not space.intersect_ray(ray).is_empty(): return actor.global_position
	var shape := CircleShape2D.new()
	shape.radius = 4
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0,muzzle)
	query.collision_mask = actor.collision_mask
	query.exclude = [actor.get_rid()]
	return actor.global_position if not space.intersect_shape(query,1).is_empty() else muzzle
