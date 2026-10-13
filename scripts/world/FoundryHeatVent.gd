extends Node2D
## Fixed environmental danger. One authoritative clock; no independent art tween.
enum State { INACTIVE, COOLDOWN, WARNING, ACTIVE }
const RADIUS := 46.0
const WARNING_TIME := 0.65
const ACTIVE_TIME := 0.6
const COOLDOWN_TIME := 1.5
const DAMAGE := 18.0
var state := State.INACTIVE
var remaining := 0.0
var enabled := false
var layout: Node2D
var target: Node2D
var linked_health: Node
var attempted := false
var initial_delay := COOLDOWN_TIME
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
func configure(terrain: Node2D,player: Node2D,at: Vector2,delay: float = COOLDOWN_TIME) -> void:
	set_enabled(false)
	layout = terrain; bind_player(player); position = at
	initial_delay = maxf(COOLDOWN_TIME,delay)
	queue_redraw()
func bind_player(player: Node2D) -> void:
	set_enabled(false)
	if is_instance_valid(target) and target.tree_exiting.is_connected(_cancel): target.tree_exiting.disconnect(_cancel)
	if is_instance_valid(linked_health) and linked_health.has_signal("died") and linked_health.is_connected("died",_cancel): linked_health.disconnect("died",_cancel)
	target = player; linked_health = null
	if not is_instance_valid(player): return
	player.tree_exiting.connect(_cancel)
	linked_health = player.get("health")
	if is_instance_valid(linked_health) and linked_health.has_signal("died"): linked_health.connect("died",_cancel)
func _cancel() -> void: set_enabled(false)
func _exit_tree() -> void: _cancel()
func set_enabled(value: bool) -> void:
	if value==enabled: return
	enabled = value and _target_alive() and _safe_to_arm()
	state = State.INACTIVE; remaining = 0; attempted = false
	if enabled: _enter(State.COOLDOWN,initial_delay)
	queue_redraw()
func _target_alive() -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion(): return false
	if target.has_method("is_alive"): return target.is_alive()
	var health = target.get("health")
	return is_instance_valid(health) and health.current_health>0
func _safe_to_arm() -> bool:
	return is_instance_valid(layout) and layout.is_inside_tree() and not layout.is_queued_for_deletion() and layout.is_position_walkable(layout.to_local(global_position),RADIUS)
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
	if state==State.WARNING and delta>1.0/15.0:
		_enter(State.COOLDOWN,COOLDOWN_TIME); queue_redraw(); return
	remaining -= maxf(delta,0)
	# At most one transition. A stall must never consume the visible warning.
	if remaining<=0.000001:
		match state:
			State.COOLDOWN: _enter(State.WARNING,WARNING_TIME)
			State.WARNING: _enter(State.ACTIVE,ACTIVE_TIME)
			State.ACTIVE: _enter(State.COOLDOWN,COOLDOWN_TIME)
	if state==State.ACTIVE: _try_damage()
	queue_redraw()
func _try_damage() -> void:
	if attempted: return
	var body_radius: float = target.get_body_radius() if target.has_method("get_body_radius") else 0.0
	if global_position.distance_to(target.global_position)>RADIUS+body_radius: return
	var query := PhysicsRayQueryParameters2D.create(global_position,target.global_position,1)
	# Player shares terrain layer 1; the destination body is not a wall.
	if target is CollisionObject2D: query.exclude = [target.get_rid()]
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): return
	# Environment is not a tracking enemy: stealth does not hide from floor heat.
	# Player.take_damage still owns shield, invulnerability and immunity.
	attempted = true
	target.take_damage(DAMAGE,&"foundry_heat")
func _draw() -> void:
	var ink := Color("172026")
	var hot := state==State.ACTIVE
	var warning := state==State.WARNING
	if hot or warning:
		draw_circle(Vector2.ZERO,RADIUS,Color("a54e32") if hot else Color("62563f"))
		draw_arc(Vector2.ZERO,RADIUS,0,TAU,48,ink,4,true)
		draw_arc(Vector2.ZERO,RADIUS-3,0,TAU,48,Color("f0c579"),2,true)
	draw_circle(Vector2.ZERO,19,ink)
	draw_circle(Vector2.ZERO,16,Color("77766a"))
	for x in [-8.0,0.0,8.0]:
		draw_line(Vector2(x,-11),Vector2(x,11),ink,4,true)
	if warning:
		draw_arc(Vector2.ZERO,RADIUS*clampf(remaining/WARNING_TIME,0,1),0,TAU,40,Color("f3eddc"),2,true)
		for angle in [0.0,PI/2,PI,PI*1.5]:
			var point := Vector2.from_angle(angle)*(RADIUS-8)
			draw_line(point,point+Vector2.from_angle(angle)*5,Color("f4ddb0"),3,true)
	if hot:
		for x in [-13.0,0.0,13.0]:
			var lift := 3*sin((ACTIVE_TIME-remaining)*15+x)
			var points := PackedVector2Array([Vector2(x-5,7),Vector2(x-4,-18+lift),Vector2(x+1,-28+lift),Vector2(x+5,4)])
			draw_colored_polygon(points,Color("edaa62"))
			draw_polyline(points,ink,2,true)
