extends RefCounted

# Extra membership for terrain queries; existing layer 1 collisions stay intact.
const QUERY_LAYER := 1 << 1
const CONTACT_TOLERANCE := 0.05
const MAX_CONTACTS := 32
const SAME_CONTACT_DISTANCE := 0.0001

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
	var contacts := space.collide_shape(query, MAX_CONTACTS)
	var query_count := 1
	var normals: Array[Vector2] = []
	var blocked := false
	if contacts.size() >= MAX_CONTACTS * 2:
		return _motion_result(motion, 0.0, true, false, [], true, query_count)
	for index in range(0, contacts.size(), 2):
		var separation: Vector2 = contacts[index + 1] - contacts[index]
		if separation.length() > CONTACT_TOLERANCE * 2.0 + 0.0001:
			return _motion_result(motion, 0.0, true, true, [], false, query_count)
		var normal := _contact_normal(query, contacts[index], separation)
		if not normal.is_zero_approx():
			normals.append(normal)
		if motion.dot(normal) * separation.length() < -0.000001:
			blocked = true
	if blocked:
		return _motion_result(motion, 0.0, true, false, normals, false, query_count)
	query.margin = 0.0
	query.motion = motion
	var fractions := space.cast_motion(query)
	query_count += 1
	var fraction := clampf(fractions[0], 0.0, 1.0)
	normals.clear()
	if fraction < 1.0:
		# cast_motion has no normal. Query the actual contact pairs at its unsafe
		# transform, including simultaneous corner contacts, before responding.
		query.transform.origin += motion * fractions[1]
		query.motion = Vector2.ZERO
		query.margin = CONTACT_TOLERANCE
		contacts = space.collide_shape(query, MAX_CONTACTS)
		query_count += 1
		if contacts.size() >= MAX_CONTACTS * 2:
			return _motion_result(motion, 0.0, true, false, [], true, query_count)
		for index in range(0, contacts.size(), 2):
			var separation: Vector2 = contacts[index + 1] - contacts[index]
			var normal := _contact_normal(query, contacts[index], separation)
			if not normal.is_zero_approx():
				normals.append(normal)
		if normals.is_empty():
			return _motion_result(motion, 0.0, true, false, [], false, query_count)
	return _motion_result(motion, fraction, fraction < 1.0, false, normals, false, query_count)

static func _motion_result(motion: Vector2, fraction: float, blocked: bool, embedded: bool, normals: Array, saturated: bool, query_count: int) -> Dictionary:
	return {"motion": motion * fraction, "fraction": fraction, "blocked": blocked,
		"embedded": embedded, "normals": normals, "query_saturated": saturated,
		"query_count": query_count}

static func _contact_normal(query: PhysicsShapeQueryParameters2D, on_player: Vector2, separation: Vector2) -> Vector2:
	# The first contact belongs to the query shape. For the player's circular
	# shape its inward radius is the separation normal, using a radius-sized
	# vector instead of subtracting almost coincident points (~0.05 px apart).
	# This also preserves curved corner normals; no axis or movement-direction snap.
	var transform := query.transform
	if query.shape is CircleShape2D and is_equal_approx(transform.x.length_squared(), transform.y.length_squared()) and is_zero_approx(transform.x.dot(transform.y)):
		return (transform.origin - on_player).normalized()
	return separation.normalized()

static func _body_query(collision: CollisionShape2D, mask: int) -> PhysicsShapeQueryParameters2D:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = mask
	query.collide_with_areas = false
	query.exclude = [collision.get_parent().get_rid()]
	return query

static func entity_contact_state(collision: CollisionShape2D, mask: int, margin: float) -> Dictionary:
	var query := _body_query(collision, mask)
	query.margin = margin
	var hits := collision.get_world_2d().direct_space_state.intersect_shape(query, MAX_CONTACTS)
	var overlap := false
	for hit in hits:
		if (hit.collider.get_collision_layer() & QUERY_LAYER) == 0:
			overlap = true
	return {"overlap": overlap, "saturated": hits.size() >= MAX_CONTACTS, "query_count": 1}

static func restrict_body_motion(collision: CollisionShape2D, motion: Vector2, mask: int) -> Dictionary:
	# Only for the enabled-body restoration window. Forbid deepening existing
	# overlaps and sweep new bodies using the existing normal body mask.
	var query := _body_query(collision, mask)
	var space := collision.get_world_2d().direct_space_state
	var contacts := space.collide_shape(query, MAX_CONTACTS)
	var query_count := 1
	var normals: Array[Vector2] = []
	if contacts.size() >= MAX_CONTACTS * 2:
		return _motion_result(motion, 0.0, true, false, [], true, query_count)
	for index in range(0, contacts.size(), 2):
		var normal := _contact_normal(query, contacts[index], contacts[index + 1] - contacts[index])
		if motion.dot(normal) < -0.000001:
			normals.append(normal)
	if not normals.is_empty():
		return _motion_result(motion, 0.0, true, false, normals, false, query_count)
	query.motion = motion
	var fractions := space.cast_motion(query)
	query_count += 1
	var fraction := clampf(fractions[0], 0.0, 1.0)
	if fraction < 1.0:
		query.transform.origin += motion * fractions[1]
		query.motion = Vector2.ZERO
		query.margin = CONTACT_TOLERANCE
		contacts = space.collide_shape(query, MAX_CONTACTS)
		query_count += 1
		if contacts.size() >= MAX_CONTACTS * 2:
			return _motion_result(motion, 0.0, true, false, [], true, query_count)
		for index in range(0, contacts.size(), 2):
			var normal := _contact_normal(query, contacts[index], contacts[index + 1] - contacts[index])
			if not normal.is_zero_approx():
				normals.append(normal)
		if normals.is_empty():
			return _motion_result(motion, 0.0, true, false, [], false, query_count)
	return _motion_result(motion, fraction, fraction < 1.0, false, normals, false, query_count)

static func constrain_restored_motion(collision: CollisionShape2D, motion: Vector2, mask: int) -> Dictionary:
	# Both queries inspect the SAME start and request. A farther collision must
	# not project away motion before the nearer collision has been reached.
	var terrain := resolve(collision, motion)
	var bodies := restrict_body_motion(collision, motion, mask)
	var saturated: bool = terrain.query_saturated or bodies.query_saturated
	var embedded: bool = terrain.embedded or bodies.embedded
	var fraction := minf(terrain.fraction, bodies.fraction)
	var normals: Array[Vector2] = []
	if saturated or embedded:
		fraction = 0.0
	else:
		for result in [terrain, bodies]:
			if not result.blocked or absf(result.fraction - fraction) * motion.length() > SAME_CONTACT_DISTANCE:
				continue
			for normal: Vector2 in result.normals:
				var duplicate := false
				for existing: Vector2 in normals:
					duplicate = duplicate or normal.distance_to(existing) <= 0.000001
				if not duplicate:
					normals.append(normal)
	var combined := _motion_result(motion, fraction, saturated or embedded or terrain.blocked or bodies.blocked,
		embedded, normals, saturated, terrain.query_count + bodies.query_count)
	# Preserve raw metadata: a later/secondary result cannot overwrite a prior
	# saturation, embedding or clamp event, even when both end at the same point.
	combined["terrain"] = terrain
	combined["bodies"] = bodies
	return combined
