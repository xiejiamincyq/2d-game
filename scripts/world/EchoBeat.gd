extends Node2D
## Fixed neighboring strikes. One clock/one attempt per pair, never animation damage.
const Terrain = preload("res://scripts/world/TerrainSweep.gd")
enum State { INACTIVE, COOLDOWN, WARNING_FIRST, PULSE_FIRST, WARNING_SECOND, PULSE_SECOND }
const RADIUS := 30.0
const OFFSET := 48.0
const WARNING_TIME := 0.4
const SECOND_WARNING_TIME := 0.4 # 0.15 reaction + 46.9/235 body exit + 30Hz ordering.
const PULSE_TIME := 0.12
const COOLDOWN_TIME := 3.4
const DAMAGE := 18.0
var state := State.INACTIVE
var remaining := 0.0
var enabled := false
var attempted := false
var initial_delay := COOLDOWN_TIME
var secondary_offset := Vector2.ZERO
var layout: Node2D
var target: Node2D
var linked_health: Node
var terrain_query := PhysicsShapeQueryParameters2D.new()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shape := CircleShape2D.new(); shape.radius = RADIUS
	terrain_query.shape = shape; terrain_query.collision_mask = 1|Terrain.QUERY_LAYER
	terrain_query.collide_with_areas = false; terrain_query.collide_with_bodies = true
# Anchor and direction are layout-local; translation is supported, scale/rotation rejected.
func configure(terrain: Node2D,player: Node2D,at: Vector2,direction: Vector2,delay: float = COOLDOWN_TIME) -> void:
	set_enabled(false)
	if is_instance_valid(layout) and layout.tree_exiting.is_connected(_cancel): layout.tree_exiting.disconnect(_cancel)
	layout = terrain
	if is_instance_valid(layout): global_position = layout.to_global(at); layout.tree_exiting.connect(_cancel)
	secondary_offset = direction.normalized()*OFFSET if direction.is_finite() else Vector2.ZERO
	initial_delay = maxf(COOLDOWN_TIME,delay) if is_finite(delay) else COOLDOWN_TIME
	bind_player(player); queue_redraw()
func get_beat_centers() -> Array[Vector2]: return [global_position,global_position+secondary_offset]
func get_current_center() -> Vector2:
	return global_position+secondary_offset if state in [State.WARNING_SECOND,State.PULSE_SECOND] else global_position
func bind_player(player: Node2D) -> void:
	set_enabled(false)
	if is_instance_valid(target) and target.tree_exiting.is_connected(_cancel): target.tree_exiting.disconnect(_cancel)
	if is_instance_valid(linked_health) and linked_health.has_signal("died") and linked_health.is_connected("died",_cancel): linked_health.disconnect("died",_cancel)
	target = player; linked_health = null; terrain_query.exclude = []
	if not is_instance_valid(player): return
	player.tree_exiting.connect(_cancel); linked_health = player.get("health")
	if is_instance_valid(linked_health) and linked_health.has_signal("died"): linked_health.connect("died",_cancel)
	if player is CollisionObject2D: terrain_query.exclude = [player.get_rid()]
func _cancel() -> void: set_enabled(false)
func _exit_tree() -> void: _cancel()
func set_enabled(value: bool) -> void:
	if value==enabled: return
	enabled = value and _target_alive() and _safe_to_arm()
	state = State.INACTIVE; remaining = 0; attempted = false
	if enabled: _enter(State.COOLDOWN,initial_delay)
	queue_redraw()
func _target_alive() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and is_instance_valid(linked_health) and linked_health.current_health>0
func _safe_to_arm() -> bool:
	if not is_instance_valid(layout) or not layout.is_inside_tree() or layout.is_queued_for_deletion(): return false
	if not global_scale.is_equal_approx(Vector2.ONE) or not layout.global_scale.is_equal_approx(Vector2.ONE) or not is_zero_approx(global_rotation) or not is_zero_approx(layout.global_rotation): return false
	if not global_position.is_finite() or not is_equal_approx(secondary_offset.length(),OFFSET): return false
	for center in get_beat_centers():
		var at := layout.to_local(center)
		if not layout.is_position_walkable(at,RADIUS): return false
		var area := Rect2(at-Vector2.ONE*RADIUS,Vector2.ONE*RADIUS*2)
		if area.grow(16.9).intersects(layout.SPAWN_BUFFER) or area.grow(16.9).intersects(layout.BOSS_BUFFER): return false
		terrain_query.transform = Transform2D(0,center)
		var contacts := get_world_2d().direct_space_state.intersect_shape(terrain_query,Terrain.MAX_CONTACTS)
		# Normal moving actors share layer 1; only terrain vetoes the clock.
		# A full result could hide a wall behind actors, so fail closed.
		if contacts.size()>=Terrain.MAX_CONTACTS: return false
		for contact in contacts:
			if _is_terrain(contact.get("collider")): return false
	return true
func _is_terrain(body: Object) -> bool:
	return not body is CollisionObject2D or body is StaticBody2D or (body.collision_layer&Terrain.QUERY_LAYER)!=0
func _terrain_blocks_ray(center: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(center,target.global_position,1|Terrain.QUERY_LAYER)
	if target is CollisionObject2D: query.exclude = [target.get_rid()]
	for _index in Terrain.MAX_CONTACTS:
		var contact := get_world_2d().direct_space_state.intersect_ray(query)
		if contact.is_empty(): return false
		if _is_terrain(contact.get("collider")): return true
		var excluded := query.exclude; excluded.append(contact.rid); query.exclude = excluded
	return true # Saturation must not silently bypass unseen terrain.
func _enter(next: State,duration: float) -> void:
	state = next; remaining = duration
	if next==State.COOLDOWN: attempted = false
func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	if not enabled: return
	if not _target_alive() or not _safe_to_arm(): set_enabled(false); return
	if get_tree().paused or (target.has_method("is_entrance_active") and target.is_entrance_active()):
		_enter(State.INACTIVE,0); queue_redraw(); return
	if state==State.INACTIVE: _enter(State.COOLDOWN,COOLDOWN_TIME); queue_redraw(); return
	if not is_finite(delta) or delta<=0: return
	remaining -= delta
	# One transition per step preserves both visible warnings after a frame hitch.
	if remaining<=0.000001:
		match state:
			State.COOLDOWN: _enter(State.WARNING_FIRST,WARNING_TIME)
			State.WARNING_FIRST: _enter(State.PULSE_FIRST,PULSE_TIME)
			State.PULSE_FIRST: _enter(State.WARNING_SECOND,SECOND_WARNING_TIME)
			State.WARNING_SECOND: _enter(State.PULSE_SECOND,PULSE_TIME)
			State.PULSE_SECOND: _enter(State.COOLDOWN,COOLDOWN_TIME)
	if state in [State.PULSE_FIRST,State.PULSE_SECOND]: _try_damage()
	queue_redraw()
func _try_damage() -> void:
	if attempted or (target.has_method("is_stealthed") and target.is_stealthed()): return
	var center := get_current_center()
	var radius: float = target.get_body_radius() if target.has_method("get_body_radius") else 0
	if center.distance_squared_to(target.global_position)>pow(RADIUS+radius,2): return
	if _terrain_blocks_ray(center): return
	attempted = true # Before damage/death callbacks. Do not retry immunity on beat2.
	target.take_damage(DAMAGE,&"echo_beat")
func _draw() -> void:
	var ink := Color("292435")
	# Small persistent bronze pedestal; never a movement collider or reward target.
	draw_rect(Rect2(-9,-7,18,14),ink); draw_rect(Rect2(-6,-4,12,8),Color("a08a68"))
	draw_line(Vector2(-4,0),Vector2(4,0),Color("d0c5b6"),2)
	if state not in [State.WARNING_FIRST,State.PULSE_FIRST,State.WARNING_SECOND,State.PULSE_SECOND]: return
	var center := to_local(get_current_center())
	var pulse := state in [State.PULSE_FIRST,State.PULSE_SECOND]
	draw_circle(center,RADIUS,Color("b56e64") if pulse else Color(0.76,0.63,0.42,0.13))
	draw_arc(center,RADIUS,0,TAU,48,ink,3,true)
	draw_arc(center,RADIUS-1.5,0,TAU,48,Color("d8b47b") if not pulse else Color("e6b6a2"),1.5,true)
	if pulse:
		for axis in [Vector2.RIGHT,Vector2.DOWN]:
			draw_line(center-axis*14,center+axis*14,Color("e6b6a2"),2,true)
	else:
		# Compact stroke number distinguishes the first and offset second warning.
		for index in (2 if state==State.WARNING_SECOND else 1):
			var at := center+Vector2((index-0.5)*8 if state==State.WARNING_SECOND else 0,-5)
			draw_line(at,at+Vector2(0,10),Color("d8b47b"),3,true)
