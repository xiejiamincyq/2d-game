extends Area2D
class_name Projectile

const Palette = preload("res://scripts/effects/FriendlyEffectPalette.gd")
const HostilePalette = preload("res://scripts/effects/HostileEffectPalette.gd")

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const TerrainSweep = preload("res://scripts/world/TerrainSweep.gd")

var velocity: Vector2 = Vector2.ZERO
var damage: float = 1.0
var pierce: int = 0
var lifetime: float = 6.0
var target_group: StringName = &"enemies"
var hit_bodies: Array[Node] = []
var _resolving_hit := false
var _terrain_query := PhysicsShapeQueryParameters2D.new()
var _front_query := PhysicsShapeQueryParameters2D.new()
var tint: Color = Color.CYAN
var radius: float = 4.0
var world_bounds: Rect2 = Rect2()
var damage_source: StringName = DamageTypes.PROJECTILE
var damage_multiplier_provider: Callable
var overdrive_visual: bool = false
var overdrive_trail: Node2D

func _ready() -> void:
	monitoring = true
	# StaticBody overlap admission needs monitorable in this physics backend.
	# Layer zero keeps shots invisible to other areas/spawn queries, avoiding
	# projectile/projectile pairs while our mask still observes target layer 1.
	monitorable = true
	collision_layer = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	_terrain_query.shape = circle
	_terrain_query.collision_mask = TerrainSweep.QUERY_LAYER
	_terrain_query.collide_with_areas = false
	_terrain_query.exclude = [get_rid()]
	_front_query.shape = circle
	_front_query.collide_with_areas = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if overdrive_visual and target_group != &"player":
		overdrive_trail = Node2D.new()
		overdrive_trail.name = "OverdriveTrail"
		overdrive_trail.z_as_relative = false
		overdrive_trail.z_index = -1
		overdrive_trail.draw.connect(_draw_overdrive_trail)
		add_child(overdrive_trail)

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion() or not is_finite(delta) or delta <= 0: return
	var seconds := _legal_flight_seconds(delta)
	if seconds<=0:
		queue_free(); return
	if _stop_at_terrain(velocity*seconds): return
	_advance_unblocked(seconds)
	if seconds<delta: queue_free()

func _legal_flight_seconds(delta: float) -> float:
	# Restrict the sweep before querying: an expired/out-of-world segment must
	# never hit a wall the projectile had no legal flight time to reach.
	var seconds := minf(delta,maxf(lifetime,0))
	if world_bounds.size != Vector2.ZERO:
		if not world_bounds.has_point(global_position):
			return 0.0
		for axis in 2:
			if velocity[axis]>0: seconds = minf(seconds,(world_bounds.end[axis]-global_position[axis])/velocity[axis])
			elif velocity[axis]<0: seconds = minf(seconds,(world_bounds.position[axis]-global_position[axis])/velocity[axis])
	return maxf(0,seconds)

func _stop_at_terrain(motion: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var origin := global_position
	_terrain_query.transform = global_transform
	_terrain_query.margin = 0.01
	_terrain_query.motion = Vector2.ZERO
	# cast_motion ignores an initial overlap, so blocked births are separate.
	var initial := space.intersect_shape(_terrain_query,1)
	if not initial.is_empty():
		_on_body_entered(initial[0].collider)
		queue_free()
		return true
	_terrain_query.motion = motion
	var fractions := space.cast_motion(_terrain_query)
	if fractions[0]>=1: return false
	# The wall limits this segment, but a closer legitimate target owns the
	# first hit. Resolve only the prefix; never query targets beyond the wall.
	if _hit_targets_before_wall(motion*fractions[1]): return true
	global_position = origin+motion*fractions[1]
	_terrain_query.transform = global_transform
	_terrain_query.motion = Vector2.ZERO
	_terrain_query.margin = 0.08
	var impact := space.get_rest_info(_terrain_query)
	if not impact.is_empty():
		var body := instance_from_id(impact.collider_id) as Node
		# Resolve the receiver at the unsafe probe, but publish the last safe
		# body position. cast_motion's unsafe endpoint may penetrate thin walls.
		global_position = origin+motion*fractions[0]
		if is_instance_valid(body): _on_body_entered(body)
	# Enemy pierce is not permission to cross solid terrain. Never move beyond
	# the detected first wall, even if the contact receiver disappears in a signal.
	queue_free()
	return true

func _hit_targets_before_wall(motion: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var origin := global_transform
	var excluded: Array[RID] = [get_rid()]
	_front_query.collision_mask = collision_mask
	# Bound even ignored bodies: saturation retires the shot rather than
	# guessing that a closer target was absent. Clear-flight ticks do not run it.
	for _contact in TerrainSweep.MAX_CONTACTS:
		_front_query.exclude = excluded
		_front_query.transform = origin
		_front_query.motion = Vector2.ZERO
		_front_query.margin = 0.01
		var initial := space.intersect_shape(_front_query,1)
		var candidate: Dictionary
		var body: Node
		var hit_at := origin.origin
		if not initial.is_empty():
			candidate = initial[0]; body = candidate.collider
		else:
			_front_query.motion = motion
			var fractions := space.cast_motion(_front_query)
			if fractions[0]>=1: return false
			hit_at += motion*fractions[1]
			_front_query.transform.origin = hit_at
			_front_query.motion = Vector2.ZERO
			_front_query.margin = 0.08
			candidate = space.get_rest_info(_front_query)
			if candidate.is_empty():
				queue_free(); return true
			body = instance_from_id(candidate.collider_id) as Node
		excluded.append(candidate.rid)
		if not _is_eligible_target(body): continue
		if body is CollisionObject2D and (body.collision_layer & TerrainSweep.QUERY_LAYER)!=0: continue
		global_position = hit_at
		_try_hit(body)
		if is_queued_for_deletion(): return true
	queue_free()
	return true

func _advance_unblocked(delta: float) -> void:
	global_position += velocity * delta
	if world_bounds.size != Vector2.ZERO and not world_bounds.has_point(global_position):
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	if target_group == &"player":
		# Visual padding only: the physics circle remains the configured radius.
		_draw_hostile_trail()
		draw_circle(Vector2.ZERO, radius + 1.5, HostilePalette.OUTLINE)
		draw_circle(Vector2.ZERO, radius, tint)
		draw_circle(Vector2(-radius * 0.2, -radius * 0.2), radius * 0.4, HostilePalette.CREAM)
		return
	draw_rect(Rect2(Vector2(-radius, -radius), Vector2(radius * 2.0, radius * 2.0)), tint)
	draw_rect(Rect2(Vector2(-radius * 0.5, -radius * 0.5), Vector2(radius, radius)), Color.WHITE)

func get_hostile_trail_points() -> PackedVector2Array:
	if target_group != &"player" or velocity.length_squared() < 0.001:
		return PackedVector2Array()
	var direction := velocity.normalized()
	var side := direction.orthogonal()
	return PackedVector2Array([-direction * radius * 4.2, -direction * radius * 0.7 + side * radius * 0.65, -direction * radius * 0.7 - side * radius * 0.65])

func _draw_hostile_trail() -> void:
	var points := get_hostile_trail_points()
	if points.is_empty():
		return
	draw_colored_polygon(points, Color(tint, 0.35))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(HostilePalette.OUTLINE, 0.80), 1.5, true)

func _draw_overdrive_trail() -> void:
	if overdrive_visual and target_group != &"player":
		var direction := velocity.normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		var side := direction.orthogonal()
		var trail := PackedVector2Array([
			-direction * radius * 7.0,
			-direction * radius * 1.2 + side * radius * 1.1,
			direction * radius * 0.5,
			-direction * radius * 1.2 - side * radius * 1.1,
		])
		overdrive_trail.draw_colored_polygon(trail, Color(Palette.TEAL, 0.26))
		overdrive_trail.draw_line(-direction * radius * 6.0, direction * radius * 0.5, Color(Palette.CREAM, 0.68), 1.5)
		overdrive_trail.draw_circle(Vector2.ZERO, radius * 3.0, Color(Palette.MINT, 0.14))
		overdrive_trail.draw_circle(Vector2.ZERO, radius * 1.75, Color(Palette.MINT, 0.32))

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)

func _try_hit(node: Node) -> void:
	if is_queued_for_deletion() or _resolving_hit: return
	if not _is_eligible_target(node): return
	hit_bodies.append(node)
	# Multipliers and Health signals can synchronously reenter a different target.
	# Later ordinary callbacks may pierce; nested callbacks cannot spend this hit.
	_resolving_hit = true
	if node.has_method("take_damage"):
		var resolved_damage := get_resolved_damage()
		if is_queued_for_deletion() or not is_instance_valid(node) or node.is_queued_for_deletion():
			_resolving_hit = false
			return
		if node.is_in_group(&"enemies"):
			node.take_damage(resolved_damage, damage_source, velocity.normalized())
		else:
			node.take_damage(resolved_damage, damage_source)
	_resolving_hit = false
	if is_queued_for_deletion(): return
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1

func _is_eligible_target(node: Node) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion() and not hit_bodies.has(node) and (node.is_in_group(target_group) or node.is_in_group(&"destructible_terrain"))

func get_resolved_damage() -> float:
	var multiplier := 1.0
	if damage_multiplier_provider.is_valid():
		multiplier = maxf(0.0, float(damage_multiplier_provider.call()))
	return damage * multiplier
