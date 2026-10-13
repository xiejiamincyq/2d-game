extends Area2D
## Persistent destructible environmental nest, no enemy death/loot contract.
enum State { INACTIVE, COOLDOWN, WARNING, ACTIVE, BROKEN }
const Health = preload("res://scripts/components/HealthComponent.gd")
const RADIUS := 34.0
const WARNING_TIME := 0.45
const ACTIVE_TIME := 0.55
const COOLDOWN_TIME := 3.2
const DAMAGE := 18.0
const MAX_HEALTH := 36.0
const BODY_RADIUS := 12.0
var body_radius: float:
	get: return BODY_RADIUS # Existing weapon geometry reads this exact collision radius.
var state := State.INACTIVE
var enabled := false
var destroyed := false
var attempted := false
var remaining := 0.0
var initial_delay := COOLDOWN_TIME
var layout: Node2D
var target: Node2D
var linked_health: Node
var health: HealthComponent
var terrain_query := PhysicsShapeQueryParameters2D.new()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	collision_layer = 0; collision_mask = 0; monitoring = false; monitorable = true
	health = Health.new(); health.max_health = MAX_HEALTH; add_child(health)
	health.died.connect(_on_destroyed)
	var collider := CollisionShape2D.new(); var shape := CircleShape2D.new(); shape.radius = BODY_RADIUS
	collider.shape = shape; add_child(collider)
	var pulse := CircleShape2D.new(); pulse.radius = RADIUS
	terrain_query.shape = pulse; terrain_query.collision_mask = 1
	terrain_query.collide_with_areas = false; terrain_query.collide_with_bodies = true
func configure(terrain: Node2D,player: Node2D,at: Vector2,delay: float = COOLDOWN_TIME) -> void:
	set_enabled(false)
	if is_instance_valid(layout) and layout.tree_exiting.is_connected(_cancel): layout.tree_exiting.disconnect(_cancel)
	layout = terrain
	if is_instance_valid(layout): global_position = layout.to_global(at); layout.tree_exiting.connect(_cancel)
	initial_delay = maxf(COOLDOWN_TIME,delay); bind_player(player); queue_redraw()
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
	if value==enabled: return # Repeated COMBAT updates must not regrow a broken nest.
	enabled = value and _target_alive() and _safe_to_arm()
	state = State.INACTIVE; remaining = 0; attempted = false
	if enabled:
		destroyed = false; health.current_health = MAX_HEALTH
		_enter(State.COOLDOWN,initial_delay)
	else: _sync_targetability(); queue_redraw()
func _target_alive() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and is_instance_valid(linked_health) and linked_health.current_health>0
func _safe_to_arm() -> bool:
	if not is_instance_valid(layout) or not layout.is_inside_tree() or layout.is_queued_for_deletion(): return false
	if not global_scale.is_equal_approx(Vector2.ONE) or not layout.global_scale.is_equal_approx(Vector2.ONE) or not is_zero_approx(global_rotation) or not is_zero_approx(layout.global_rotation): return false
	var at := layout.to_local(global_position)
	if not at.is_finite() or not layout.is_position_walkable(at,RADIUS): return false
	var footprint := Rect2(at-Vector2.ONE*RADIUS,Vector2.ONE*RADIUS*2)
	if footprint.grow(13).intersects(layout.SPAWN_BUFFER) or footprint.grow(13).intersects(layout.BOSS_BUFFER): return false
	terrain_query.transform = Transform2D(0,global_position)
	return get_world_2d().direct_space_state.intersect_shape(terrain_query,1).is_empty()
func _can_be_targeted() -> bool:
	return enabled and not destroyed and state not in [State.INACTIVE,State.BROKEN] and _target_alive() and not get_tree().paused and not (target.has_method("is_entrance_active") and target.is_entrance_active())
func _sync_targetability() -> void:
	if _can_be_targeted(): add_to_group(&"enemies")
	elif is_in_group(&"enemies"): remove_from_group(&"enemies")
	# Deferred physics writes resolve current state, never a stale captured value.
	call_deferred("_sync_collision")
func _sync_collision() -> void: collision_layer = 1 if _can_be_targeted() else 0
func get_body_radius() -> float: return BODY_RADIUS
func take_damage(amount: float,_source: StringName = &"generic",_direction: Vector2 = Vector2.ZERO) -> bool:
	if not is_finite(amount) or amount<=0 or not _can_be_targeted(): return false
	health.damage(amount,true); queue_redraw()
	return destroyed
func _on_destroyed() -> void:
	if destroyed: return
	destroyed = true; state = State.BROKEN; remaining = 0; attempted = true
	_sync_targetability(); queue_redraw()
func _enter(next: State,duration: float) -> void:
	state = next; remaining = duration
	if next==State.ACTIVE: attempted = false
	_sync_targetability(); queue_redraw()
func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	if not enabled: return
	if not _target_alive() or not _safe_to_arm(): set_enabled(false); return
	if destroyed: return
	if get_tree().paused or (target.has_method("is_entrance_active") and target.is_entrance_active()): _enter(State.INACTIVE,0); return
	if state==State.INACTIVE: _enter(State.COOLDOWN,COOLDOWN_TIME); return
	if not is_finite(delta) or delta<=0: return
	remaining -= delta
	# A hitch consumes only one transition; visible warning can never disappear.
	if remaining<=0.000001:
		match state:
			State.COOLDOWN: _enter(State.WARNING,WARNING_TIME)
			State.WARNING: _enter(State.ACTIVE,ACTIVE_TIME)
			State.ACTIVE: _enter(State.COOLDOWN,COOLDOWN_TIME)
	if state==State.ACTIVE: _try_damage()
	queue_redraw()
func _try_damage() -> void:
	if attempted: return
	var radius: float = target.get_body_radius() if target.has_method("get_body_radius") else 0.0
	if global_position.distance_squared_to(target.global_position)>pow(RADIUS+radius,2): return
	var query := PhysicsRayQueryParameters2D.create(global_position,target.global_position,1)
	if target is CollisionObject2D: query.exclude = [target.get_rid()]
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): return
	attempted = true # Before immunity/death callbacks; never retry in one emission.
	target.take_damage(DAMAGE,&"archive_spore")
func _draw() -> void:
	var ink := Color("1c2926"); var paper := Color("d6c8a4")
	var alive := not destroyed
	if state in [State.WARNING,State.ACTIVE]:
		for index in 6:
			var angle := index*TAU/6
			draw_arc(Vector2.ZERO,RADIUS,angle,angle+0.65,8,ink,3,true)
			draw_arc(Vector2.ZERO,RADIUS-1,angle,angle+0.65,8,Color("be9e62") if state==State.WARNING else Color("adbc79"),1.5,true)
		if state==State.ACTIVE:
			for index in 6:
				var at := Vector2.from_angle(index*TAU/6+remaining*1.5)*(17+(index%2)*7)
				draw_circle(at,3.5,ink); draw_circle(at,2,Color("adbc79"))
	draw_rect(Rect2(-17,-8,34,18),ink); draw_rect(Rect2(-14,-5,28,12),Color("8e9479"))
	if alive:
		for index in 3:
			var at := Vector2((index-1)*10,-13-abs(index-1)*2)
			draw_line(at+Vector2(0,8),at,ink,5); draw_line(at+Vector2(0,7),at,paper,2)
			var cap := PackedVector2Array([Vector2(-8,2),Vector2(-7,-3),Vector2(-3,-7),Vector2(2,-8),Vector2(6,-5),Vector2(8,1),Vector2(3,3),Vector2(-3,2)])
			for vertex in cap.size(): cap[vertex] += at
			draw_colored_polygon(cap,Color("a2ad77")); draw_polyline(cap+PackedVector2Array([cap[0]]),ink,2,true)
			draw_line(at+Vector2(-5,0),at+Vector2(5,1),paper,1)
			draw_circle(at+Vector2(-2,-4),1.4,paper)
		if enabled:
			draw_rect(Rect2(-19,-32,38,5),ink); draw_rect(Rect2(-18,-31,36*health.current_health/MAX_HEALTH,3),Color("d79073"))
	else:
		for side in [-1,1]: draw_line(Vector2(side*3,-9),Vector2(side*12,-14),paper,3)
