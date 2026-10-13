extends Node2D
## One finite moving footprint. Drawing and damage share the same clock and center.
const Terrain = preload("res://scripts/world/TerrainSweep.gd")
enum State { INACTIVE, COOLDOWN, WARNING, ACTIVE }
const RADIUS := 20.0
const HALF_PATH := 80.0
const WARNING_TIME := 0.4
const ACTIVE_TIME := 0.35
const COOLDOWN_TIME := 4.2
const MAX_ACTIVE_STEP := 1.0/15.0
const DAMAGE := 18.0
var state := State.INACTIVE
var remaining := 0.0
var enabled := false
var attempted := false
var initial_delay := COOLDOWN_TIME
var layout: Node2D
var target: Node2D
var linked_health: Node
var direction := Vector2.ZERO
var _configured := false
var _resolving_damage := false
var _previous_center := Vector2.ZERO
var _previous_target := Vector2.ZERO
var _terrain_query := PhysicsShapeQueryParameters2D.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shape := CapsuleShape2D.new()
	shape.radius = RADIUS; shape.height = HALF_PATH*2+RADIUS*2
	_terrain_query.shape = shape
	_terrain_query.collision_mask = 1|Terrain.QUERY_LAYER
	_terrain_query.collide_with_areas = false
	_terrain_query.collide_with_bodies = true

# Layout-local geometry supports translation, never silent scaling of damage radii.
func configure(terrain: Node2D,player: Node2D,at: Vector2,heading: Vector2,delay: float = COOLDOWN_TIME) -> void:
	set_enabled(false)
	if is_instance_valid(layout) and layout.tree_exiting.is_connected(_cancel): layout.tree_exiting.disconnect(_cancel)
	layout = terrain
	_configured = is_instance_valid(layout) and layout.is_inside_tree() and at.is_finite() and heading.is_finite() and heading.length_squared()>0.000001
	direction = heading.normalized() if _configured else Vector2.ZERO
	if is_instance_valid(layout):
		layout.tree_exiting.connect(_cancel)
		if _configured:
			var anchor := layout.to_global(at)
			_configured = anchor.is_finite()
			if _configured: global_position = anchor
	initial_delay = maxf(COOLDOWN_TIME,delay) if is_finite(delay) else COOLDOWN_TIME
	bind_player(player); queue_redraw()

func get_fault_path() -> Array[Vector2]:
	return [global_position-direction*HALF_PATH,global_position+direction*HALF_PATH]

func get_current_center() -> Vector2:
	var fraction := clampf((ACTIVE_TIME-remaining)/ACTIVE_TIME,0,1) if state==State.ACTIVE else 0.0
	return global_position+direction*lerpf(-HALF_PATH,HALF_PATH,fraction)

func bind_player(player: Node2D) -> void:
	set_enabled(false)
	if is_instance_valid(target) and target.tree_exiting.is_connected(_cancel): target.tree_exiting.disconnect(_cancel)
	if is_instance_valid(linked_health) and linked_health.has_signal("died") and linked_health.is_connected("died",_cancel): linked_health.disconnect("died",_cancel)
	target = player; linked_health = null; _terrain_query.exclude = []
	if not is_instance_valid(player): return
	player.tree_exiting.connect(_cancel); linked_health = player.get("health")
	if is_instance_valid(linked_health) and linked_health.has_signal("died"): linked_health.connect("died",_cancel)
	if player is CollisionObject2D: _terrain_query.exclude = [player.get_rid()]

func _cancel() -> void: set_enabled(false)
func _exit_tree() -> void: _cancel()

func set_enabled(value: bool) -> void:
	if value and _resolving_damage: return
	if value==enabled: return
	enabled = value and _target_alive() and _safe_to_arm()
	_enter(State.COOLDOWN,initial_delay) if enabled else _enter(State.INACTIVE,0)
	queue_redraw()

func _target_alive() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and target.global_position.is_finite() and is_instance_valid(linked_health) and linked_health.current_health>0

func _safe_to_arm() -> bool:
	if not _configured or not is_instance_valid(layout) or not layout.is_inside_tree() or layout.is_queued_for_deletion(): return false
	if not global_scale.is_equal_approx(Vector2.ONE) or not layout.global_scale.is_equal_approx(Vector2.ONE) or not is_zero_approx(global_rotation) or not is_zero_approx(layout.global_rotation): return false
	if not global_position.is_finite() or not direction.is_finite() or not is_equal_approx(direction.length(),1): return false
	# Check the whole capsule, not merely two safe endpoints. Fixed bounded sampling
	# supplements the actual shape query and keeps layout-only fixtures conservative.
	var ends := get_fault_path()
	for index in 11:
		var at := layout.to_local(ends[0].lerp(ends[1],index/10.0))
		if not layout.is_position_walkable(at,RADIUS): return false
		var area := Rect2(at-Vector2.ONE*RADIUS,Vector2.ONE*RADIUS*2)
		if area.grow(16.9).intersects(layout.SPAWN_BUFFER) or area.grow(16.9).intersects(layout.BOSS_BUFFER): return false
	_terrain_query.transform = Transform2D(direction.angle()-PI/2,global_position)
	var contacts := get_world_2d().direct_space_state.intersect_shape(_terrain_query,Terrain.MAX_CONTACTS)
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
	return true

func _enter(next: State,duration: float) -> void:
	state = next; remaining = duration
	if next in [State.INACTIVE,State.COOLDOWN]:
		attempted = false; _previous_center = Vector2.ZERO; _previous_target = Vector2.ZERO
	elif next==State.ACTIVE:
		_previous_center = get_current_center(); _previous_target = target.global_position

func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	if not enabled or not is_finite(delta) or delta<=0: return
	if not _target_alive() or not _safe_to_arm(): set_enabled(false); return
	if get_tree().paused or (target.has_method("is_entrance_active") and target.is_entrance_active()) or (target.has_method("is_stealthed") and target.is_stealthed()):
		_enter(State.INACTIVE,0); queue_redraw(); return
	if state==State.INACTIVE:
		_enter(State.COOLDOWN,initial_delay); queue_redraw(); return
	if state==State.ACTIVE:
		if remaining<=0.000001 or delta>MAX_ACTIVE_STEP:
			_enter(State.COOLDOWN,COOLDOWN_TIME); queue_redraw(); return
		remaining = maxf(0,remaining-delta)
		_try_damage()
	elif state==State.COOLDOWN:
		remaining -= delta
		if remaining<=0.000001: _enter(State.WARNING,WARNING_TIME)
	elif state==State.WARNING:
		remaining -= delta
		if remaining<=0.000001:
			_enter(State.ACTIVE,ACTIVE_TIME); _try_damage()
	# Endpoint remains visible for its impact frame; no catch-up across states.
	if enabled and state==State.ACTIVE:
		_previous_center = get_current_center(); _previous_target = target.global_position
	queue_redraw()

func _try_damage() -> void:
	if attempted: return
	var center := get_current_center()
	var radius: float = target.get_body_radius() if target.has_method("get_body_radius") else 0
	if not is_finite(radius) or radius<0: return
	var previous_relative := _previous_center-_previous_target
	var current_relative := center-target.global_position
	var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,previous_relative,current_relative)
	if closest.length_squared()>pow(RADIUS+radius,2) or _terrain_blocks_ray(center): return
	attempted = true # Includes immunity; set before callbacks that may cancel us.
	_resolving_damage = true
	target.take_damage(DAMAGE,&"rift_fault")
	_resolving_damage = false

func _draw() -> void:
	var ink := Color("292435")
	# A small fixed paper-and-brass driver, not a collision or reward object.
	draw_rect(Rect2(-8,-6,16,12),ink)
	draw_rect(Rect2(-5,-3,10,6),Color("a39172"))
	draw_line(Vector2(-3,0),Vector2(3,0),Color("dad0bd"),2)
	if state==State.WARNING:
		for index in 10:
			var at := direction*(-HALF_PATH+index*16)
			draw_line(at,at+direction*8,Color(0.7,0.52,0.42,0.5),1.5,true)
		draw_line(Vector2(0,-17),Vector2(0,-11),Color("d8b47b"),2,true)
		draw_circle(Vector2(0,-8),1.2,Color("d8b47b"))
	elif state==State.ACTIVE:
		var center := to_local(get_current_center())
		draw_line(center-direction*27,center,Color("946461"),3,true)
		draw_circle(center,RADIUS,ink)
		draw_circle(center,RADIUS-3,Color("b56e64"))
		var normal := direction.orthogonal()
		var crack := PackedVector2Array([center-normal*12,center-normal*4+direction*5,center+normal*3-direction*5,center+normal*12])
		draw_polyline(crack,Color("edd0b5"),2,true)
