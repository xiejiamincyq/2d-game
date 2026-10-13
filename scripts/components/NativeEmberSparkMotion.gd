extends "res://scripts/components/NativeSporelingMotion.gd"
## Reuses only ranged visual clocks/lifecycle; distinct joint keys and safe nozzle.
const NOZZLE := "Facing/Skeleton2D/Torso/ArmR/Nozzle"
func update(actor: CharacterBody2D,delta: float) -> void:
	if not is_finite(delta) or delta<0:
		return
	var barrel: Bone2D = view.get_node(NOZZLE)
	var arm: Bone2D = barrel.get_parent()
	arm.apply_rest()
	barrel.apply_rest()
	super.update(actor,delta)
	var target: Node2D = actor.get_target_player()
	if target==null or actor.spawn_impulse_remaining>0:
		return
	var at: Vector2 = actor.ranged_target_position if actor.ranged_is_winding_up or shot_remaining>0 else target.global_position
	view.set_facing_left(at.x<actor.global_position.x)
	var facing: Node2D = view.get_node("Facing")
	var axis := facing.to_local(arm.to_global(Vector2.RIGHT))-facing.to_local(arm.global_position)
	var desired := facing.to_local(at)-facing.to_local(barrel.global_position)
	arm.rotation = clampf(wrapf(desired.angle()-axis.angle(),-PI,PI),-PI/3,PI/3)
	desired = arm.to_local(at)-barrel.position
	barrel.rotation = clampf(desired.angle(),-deg_to_rad(35),deg_to_rad(35))
func get_safe_muzzle(actor: CharacterBody2D) -> Vector2:
	var muzzle: Vector2 = view.get_node(NOZZLE+"/Muzzle").global_position
	if actor.world_bounds.size!=Vector2.ZERO and not actor.world_bounds.grow(-4).has_point(muzzle):
		return actor.global_position
	var ray := PhysicsRayQueryParameters2D.create(actor.global_position,muzzle,actor.collision_mask,[actor.get_rid()])
	var space := actor.get_world_2d().direct_space_state
	if not space.intersect_ray(ray).is_empty():
		return actor.global_position
	var circle := CircleShape2D.new()
	circle.radius = 4
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0,muzzle)
	query.collision_mask = actor.collision_mask
	query.exclude = [actor.get_rid()]
	return actor.global_position if not space.intersect_shape(query,1).is_empty() else muzzle
