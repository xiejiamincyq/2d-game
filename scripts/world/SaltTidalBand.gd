extends Node2D
## Fixed ground strip; one authoritative clock drives collision and later drawing.
enum State { INACTIVE, COOLDOWN, WARNING, ACTIVE }
const WIDTH := 60.0
const WARNING_TIME := 0.4 # Includes 0.15s reaction + body exit + physics ordering.
const ACTIVE_TIME := 0.6
const COOLDOWN_TIME := 1.8
const DAMAGE := 18.0
var state := State.INACTIVE
var remaining := 0.0
var enabled := false
var attempted := false
var initial_delay := COOLDOWN_TIME
var footprint := Rect2()
var layout: Node2D
var target: Node2D
var linked_health: Node
var terrain_query := PhysicsShapeQueryParameters2D.new()
func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS
# Area is in layout-local pixels; translation is supported, rotation/scale is not.
func configure(terrain: Node2D,player: Node2D,area: Rect2,delay: float = COOLDOWN_TIME) -> void:
	set_enabled(false)
	if is_instance_valid(layout) and layout.tree_exiting.is_connected(_cancel): layout.tree_exiting.disconnect(_cancel)
	layout = terrain
	if is_instance_valid(layout):
		global_position = layout.to_global(area.get_center())
		layout.tree_exiting.connect(_cancel)
	footprint = Rect2(-area.size/2,area.size)
	initial_delay = maxf(COOLDOWN_TIME,delay)
	var shape := RectangleShape2D.new(); shape.size = area.size.max(Vector2.ONE)
	terrain_query.shape = shape; terrain_query.collision_mask = 1
	terrain_query.collide_with_areas = false; terrain_query.collide_with_bodies = true
	bind_player(player); queue_redraw()
func bind_player(player: Node2D) -> void:
	set_enabled(false)
	if is_instance_valid(target) and target.tree_exiting.is_connected(_cancel): target.tree_exiting.disconnect(_cancel)
	if is_instance_valid(linked_health) and linked_health.has_signal("died") and linked_health.is_connected("died",_cancel): linked_health.disconnect("died",_cancel)
	target = player; linked_health = null; terrain_query.exclude = []
	if not is_instance_valid(player): return
	player.tree_exiting.connect(_cancel)
	linked_health = player.get("health")
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
	if not is_inside_tree() or not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion(): return false
	if target.has_method("is_alive"): return target.is_alive()
	return is_instance_valid(linked_health) and linked_health.current_health>0
func _safe_to_arm() -> bool:
	if not is_instance_valid(layout) or not layout.is_inside_tree() or layout.is_queued_for_deletion(): return false
	if not global_scale.is_equal_approx(Vector2.ONE) or not layout.global_scale.is_equal_approx(Vector2.ONE) or not is_zero_approx(global_rotation) or not is_zero_approx(layout.global_rotation): return false
	if not footprint.size.is_finite() or minf(footprint.size.x,footprint.size.y)<=0 or minf(footprint.size.x,footprint.size.y)>WIDTH or maxf(footprint.size.x,footprint.size.y)<120: return false
	var area := Rect2(layout.to_local(global_position)+footprint.position,footprint.size)
	if not layout.world_bounds.encloses(area) or area.grow(13).intersects(layout.SPAWN_BUFFER) or area.grow(13).intersects(layout.BOSS_BUFFER): return false
	for entry in layout.get_obstacle_descriptors():
		if area.intersects(entry.rect): return false
	# An unexpected physical wall vetoes the complete strip, not invisible damage
	# through that wall. Generated strips never intersect actual terrain.
	terrain_query.transform = Transform2D(0,global_position)
	return get_world_2d().direct_space_state.intersect_shape(terrain_query,1).is_empty()
func _enter(next: State,duration: float) -> void:
	state = next; remaining = duration
	if next==State.ACTIVE: attempted = false
func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	if not enabled: return
	if not _target_alive() or not _safe_to_arm(): set_enabled(false); return
	if get_tree().paused or (target.has_method("is_entrance_active") and target.is_entrance_active()):
		_enter(State.INACTIVE,0); queue_redraw(); return
	if state==State.INACTIVE:
		_enter(State.COOLDOWN,COOLDOWN_TIME); queue_redraw(); return
	remaining -= maxf(delta,0)
	# No catch-up transitions may erase the visible warning after a stall.
	if remaining<=0.000001:
		match state:
			State.COOLDOWN: _enter(State.WARNING,WARNING_TIME)
			State.WARNING: _enter(State.ACTIVE,ACTIVE_TIME)
			State.ACTIVE: _enter(State.COOLDOWN,COOLDOWN_TIME)
	if state==State.ACTIVE: _try_damage()
	queue_redraw()
func _try_damage() -> void:
	if attempted: return
	var local := to_local(target.global_position)
	var closest := local.clamp(footprint.position,footprint.end)
	var radius: float = target.get_body_radius() if target.has_method("get_body_radius") else 0
	if local.distance_squared_to(closest)>radius*radius: return
	attempted = true # Set before damage/death callbacks; immunity is never retried.
	target.take_damage(DAMAGE,&"salt_tide")
func _draw() -> void:
	if footprint.size==Vector2.ZERO: return
	var ink := Color("172026")
	var long_axis := Vector2.DOWN if footprint.size.x<footprint.size.y else Vector2.RIGHT
	var cross_axis := long_axis.rotated(PI/2)
	var span := maxf(footprint.size.x,footprint.size.y)
	# Inactive/cooldown channels are modest fixed ground marks, not a live warning.
	for side in [-1,1]:
		var cap: Vector2 = long_axis*side*(span/2-8)
		draw_line(cap-cross_axis*20,cap+cross_axis*20,Color("7b8e83"),2,true)
	if state not in [State.WARNING,State.ACTIVE]: return
	var wet := state==State.ACTIVE
	draw_rect(footprint,Color("638991") if wet else Color(0.59,0.53,0.37,0.25))
	draw_rect(footprint,ink,false,3)
	draw_rect(footprint.grow(-3),Color("e4d5a4"),false,1)
	var offset := fposmod((ACTIVE_TIME-remaining)*70,48) if wet else 0.0
	for step in range(12,int(span)-12,48):
		var along := -span/2+step+offset
		if along>span/2-14: continue
		var at := long_axis*along
		var points := PackedVector2Array([at-cross_axis*18,at+long_axis*5,at+cross_axis*18])
		draw_polyline(points,Color("d1ddc5") if wet else Color("d9bc82"),3 if wet else 2,true)
