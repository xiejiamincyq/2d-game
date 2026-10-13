extends RefCounted
## Admission only: never moves the player, changes stats or resolves damage.
## hazard(point, active_seconds) includes the player's physical radius.
const REACTION_SECONDS := 0.25
const INPUT_MARGIN := 2.0/30.0
const STEP := 1.0/120.0
const NORMAL_SPEED := 235.0
static func has_route(actor: Node2D,player: Node2D,warning: float,active: float,bounds: Rect2,hazard: Callable,witness: Dictionary = {}) -> bool:
	witness.clear()
	if not is_instance_valid(player) or not player.is_inside_tree(): return false
	var radius: float = player.get_body_radius() if player.has_method("get_body_radius") else 17.0
	var start := player.global_position
	if bounds.size!=Vector2.ZERO and not bounds.grow(-radius).has_point(start): return false
	var speed := NORMAL_SPEED
	if player.has_method("get_effective_move_speed"): speed = minf(speed,player.get_effective_move_speed())
	var space := actor.get_world_2d().direct_space_state
	var shape := CircleShape2D.new(); shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new(); query.shape = shape
	query.transform = Transform2D(0,start); query.collide_with_areas = false
	# Use the actual movement mask, not the Boss projectile/terrain mask.
	query.collision_mask = maxi(1,player.collision_mask) if player is CollisionObject2D else 1
	if player is CollisionObject2D: query.exclude = [player.get_rid()]
	if not space.intersect_shape(query,1).is_empty(): return false
	var delay := REACTION_SECONDS+INPUT_MARGIN
	var horizon := warning+active
	for direction_index in range(-1,8):
		var direction := Vector2.ZERO if direction_index<0 else Vector2.from_angle(TAU*direction_index/8.0)
		# Test stopping after the warning and continuing through the attack.
		for stop_time in [warning,horizon]:
			var walk_time := maxf(0,stop_time-delay)
			var motion := direction*speed*walk_time
			var end := start+motion
			if bounds.size!=Vector2.ZERO and not bounds.grow(-radius).has_point(end): continue
			query.motion = motion
			if not motion.is_zero_approx() and space.cast_motion(query)[0]<0.999: continue
			var safe := true
			var steps := maxi(1,int(ceil(active/STEP)))
			for index in range(steps+1):
				var age := active*index/steps
				var at := start+direction*speed*clampf(warning+age-delay,0,walk_time)
				if hazard.call(at,age): safe = false; break
			if safe:
				witness.merge({"start":start,"end":end,"radius":radius,"mask":query.collision_mask})
				return true
	return false

static func route_still_clear(actor: Node2D,player: Node2D,witness: Dictionary) -> bool:
	if witness.is_empty(): return true # Non-damaging reinforcement cue.
	var shape := CircleShape2D.new(); shape.radius = witness.radius
	var query := PhysicsShapeQueryParameters2D.new(); query.shape = shape
	query.transform = Transform2D(0,witness.start); query.motion = witness.end-witness.start
	query.collision_mask = witness.mask; query.collide_with_areas = false
	if player is CollisionObject2D: query.exclude = [player.get_rid()]
	var space := actor.get_world_2d().direct_space_state
	return space.intersect_shape(query,1).is_empty() and (query.motion.is_zero_approx() or space.cast_motion(query)[0]>=0.999)

static func segment_danger(point: Vector2,first: Vector2,last: Vector2,radius: float) -> bool:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point,first,last))<=radius+3.0

static func draw_path(canvas: Node2D,first: Vector2,last: Vector2,radius: float) -> void:
	var a := canvas.to_local(first); var b := canvas.to_local(last)
	var side := a.direction_to(b).orthogonal()*radius
	for sign in [-1,1]:
		canvas.draw_line(a+side*sign,b+side*sign,Color("172026"),3,true)
		canvas.draw_line(a+side*sign,b+side*sign,Color("f27a4b"),1.5,true)
	canvas.draw_arc(b,radius,0,TAU,24,Color("f27a4b"),1.5,true)
