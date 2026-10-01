extends RefCounted

# Extra membership for terrain queries; existing layer 1 collisions stay intact.
const QUERY_LAYER := 1 << 1
const CONTACT_TOLERANCE := 0.05

static func resolve(collision: CollisionShape2D, motion: Vector2) -> Dictionary:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = QUERY_LAYER
	query.collide_with_areas = false
	var space := collision.get_world_2d().direct_space_state
	# Inflate only the contact query: exact-touch pairs otherwise have a zero
	# separation vector and cannot distinguish inward from outward motion.
	query.margin = CONTACT_TOLERANCE
	var contacts := space.collide_shape(query, 8)
	for index in range(0, contacts.size(), 2):
		var separation: Vector2 = contacts[index + 1] - contacts[index]
		if separation.length() > CONTACT_TOLERANCE * 2.0 + 0.0001:
			return {"motion": Vector2.ZERO, "blocked": true, "embedded": true}
		if motion.dot(separation) < -0.000001:
			return {"motion": Vector2.ZERO, "blocked": true, "embedded": false}
	query.margin = 0.0
	query.motion = motion
	var fractions := space.cast_motion(query)
	return {"motion": motion * fractions[0], "blocked": fractions[0] < 1.0, "embedded": false}
