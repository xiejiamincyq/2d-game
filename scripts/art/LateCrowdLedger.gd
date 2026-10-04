extends RefCounted

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const BossScript = preload("res://scripts/actors/OverseerBoss.gd")
var previous_values := {}
var events: Array[Dictionary] = []
var health_loss := 0.0
var shield_loss := 0.0
var peak := {}
var visible_peak := {}
var ring: Array[Dictionary] = []
var candidate: Array[Dictionary] = []
var max_retained := 0

func consider_peak(info: Dictionary) -> void:
	if not info.eligible:
		return
	if visible_peak.is_empty() or int(info.visible) > int(visible_peak.visible):
		visible_peak = info.duplicate(false)
	if peak.is_empty() or int(info.live) > int(peak.live):
		peak = info.duplicate(false)
		candidate.clear()
		for entry in ring:
			if entry.record.segment == peak.segment and entry.record.wall >= peak.wall - 3.0:
				candidate.append(entry)

func retain_capture(entry: Dictionary) -> void:
	var record: Dictionary = entry.record
	while not ring.is_empty() and (ring[0].record.wall < record.wall - 3.0 or ring[0].record.segment != record.segment):
		ring.pop_front()
	ring.append(entry)
	if not peak.is_empty() and record.segment == peak.segment and absf(record.wall - peak.wall) <= 3.0:
		candidate.append(entry)
	var identities := {}
	for retained in ring + candidate:
		identities[retained.id] = true
	max_retained = maxi(max_retained, identities.size())

static func eligible(info: Dictionary) -> bool:
	return info.state == "PLAYING" and int(info.wave) in [4, 5, 6] and not info.boss and not info.collection

static func entities(actors: Array, canvas: Transform2D, screen: Rect2, player: Vector2, player_radius: float) -> Dictionary:
	var bodies: Array[Dictionary] = []
	var kinds := {}
	var seen := {}
	var visible := 0
	var nearest_gap := INF
	for actor in actors:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_inside_tree():
			continue
		if not (actor is EnemyScript or actor is BossScript) or not is_instance_valid(actor.health) or actor.health.current_health <= 0.0 or actor.death_resolved:
			continue
		var identity: int = actor.get_instance_id()
		if seen.has(identity):
			continue
		seen[identity] = true
		var kind: String = "BOSS" if actor is BossScript else EnemyScript.EnemyKind.keys()[actor.kind]
		var radius: float = actor.body_radius
		var position: Vector2 = actor.global_position
		var world: Transform2D = actor.global_transform
		var rect: Rect2 = canvas * world * Rect2(Vector2(-radius, -radius), Vector2.ONE * radius * 2.0)
		var on_screen := screen.intersects(rect, true)
		visible += int(on_screen)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		nearest_gap = minf(nearest_gap, player.distance_to(position) - radius - player_radius)
		bodies.append({"id": identity, "kind": kind, "position": [position.x, position.y], "radius": radius,
			"health": actor.health.current_health, "visible": on_screen, "transform": transform_values(world),
			"screen_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
		if actor is EnemyScript and actor.kind == EnemyScript.EnemyKind.LOBBER and actor.ranged_is_winding_up:
			bodies[-1]["windup"] = {"position": [actor.ranged_target_position.x, actor.ranged_target_position.y], "radius": 72.0, "remaining": actor.ranged_windup_remaining}
	return {"bodies": bodies, "visible": visible, "kinds": kinds, "canvas": transform_values(canvas), "nearest_gap": nearest_gap if not bodies.is_empty() else null}

static func transform_values(value: Transform2D) -> Array:
	return [value.x.x, value.x.y, value.y.x, value.y.y, value.origin.x, value.origin.y]

func observe_value(kind: String, current: float, context: Dictionary) -> void:
	if previous_values.has(kind) and current != float(previous_values[kind]):
		var loss := maxf(0.0, float(previous_values[kind]) - current)
		var record := context.duplicate(true)
		record.merge({"kind": kind, "previous": previous_values[kind], "current": current, "loss": loss})
		events.append(record)
		if context.state == "PLAYING":
			if kind == "health":
				health_loss += loss
			elif kind == "shield":
				shield_loss += loss
	previous_values[kind] = current
