extends RefCounted
## World-space visual sockets must not release projectiles past a wall/border.
## Radius is the actual projectile's footprint, not a shared magic margin.
const Terrain = preload("res://scripts/world/TerrainSweep.gd")
static func resolve(actor: CharacterBody2D, socket: Vector2, radius: float) -> Vector2:
	if actor.world_bounds.size!=Vector2.ZERO and not actor.world_bounds.grow(-radius).has_point(socket):
		return actor.global_position
	var space := actor.get_world_2d().direct_space_state
	var terrain_mask: int = actor.collision_mask|Terrain.QUERY_LAYER
	var ray := PhysicsRayQueryParameters2D.create(actor.global_position,socket,terrain_mask,[actor.get_rid()])
	if not space.intersect_ray(ray).is_empty():
		return actor.global_position
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0,socket)
	query.collision_mask = terrain_mask
	query.exclude = [actor.get_rid()]
	return actor.global_position if not space.intersect_shape(query,1).is_empty() else socket
