extends Area2D
## Common stepped mechanism. Chapter visual/placement adapters are separate;
## this component alone does not imply that all six map fields are migrated.
const Health = preload("res://scripts/components/HealthComponent.gd")
const TerrainSweep = preload("res://scripts/world/TerrainSweep.gd")
enum Stage { READY, WARNING, COOLDOWN, DESTROYED }
const WARNING_SECONDS := 0.50
const COOLDOWN_SECONDS := 1.50
const DAMAGE := 20.0
var health: HealthComponent
var target_player: Node2D
var body_radius := 12.0
var trigger_radius := 28.0
var stage := Stage.READY
var elapsed := 0.0
var enabled := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 1; collision_mask = 0
	monitoring = false; monitorable = true
	add_to_group(&"destructible_terrain")
	health = Health.new(); health.max_health = 80; add_child(health)
	var collider := CollisionShape2D.new(); collider.name = "CollisionShape2D"
	var shape := CircleShape2D.new(); shape.radius = body_radius
	collider.shape = shape; add_child(collider)

func set_active(value: bool) -> void:
	if stage==Stage.DESTROYED: return
	enabled = value
	if not value: stage = Stage.READY; elapsed = 0
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not enabled or stage==Stage.DESTROYED or not is_finite(delta) or delta<0: return
	if health.current_health<=0 or not is_instance_valid(target_player) or not target_player.is_inside_tree() or target_player.is_queued_for_deletion():
		set_active(false); return
	var target_health = target_player.get("health")
	if target_health!=null and target_health.current_health<=0:
		set_active(false); return
	if stage==Stage.READY:
		if _player_on_trap(): stage = Stage.WARNING; elapsed = 0
	elif stage==Stage.WARNING:
		elapsed += delta
		if elapsed>=WARNING_SECONDS:
			stage = Stage.COOLDOWN; elapsed = 0 # Reserve before damage callbacks.
			if _player_on_trap() and target_player.has_method("take_damage"):
				target_player.take_damage(DAMAGE)
	elif stage==Stage.COOLDOWN:
		elapsed += delta
		if elapsed>=COOLDOWN_SECONDS: stage = Stage.READY; elapsed = 0
	queue_redraw() # At most one transition/hit per tick; no catch-up burst.

func _player_on_trap() -> bool:
	# Floor pressure is not a tracking enemy. Receiver owns shield/immunity;
	# invisibility alone does not erase a player's physical pressure footprint.
	var radius: float = target_player.get_body_radius() if target_player.has_method("get_body_radius") else 0.0
	if global_position.distance_to(target_player.global_position)>trigger_radius+radius: return false
	# Pressure and the delayed hit must both remain on the same side of terrain.
	var query := PhysicsRayQueryParameters2D.create(global_position,target_player.global_position,TerrainSweep.QUERY_LAYER)
	query.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _exit_tree() -> void:
	set_active(false)

func take_damage(amount: float,_source: StringName = &"generic",_direction: Vector2 = Vector2.ZERO) -> bool:
	if stage==Stage.DESTROYED or health==null or not is_finite(amount) or amount<=0: return false
	health.damage(amount,true)
	if stage==Stage.DESTROYED or is_queued_for_deletion(): return false
	queue_redraw()
	if health.current_health>0: return false
	stage = Stage.DESTROYED; enabled = false
	collision_layer = 0; set_deferred("monitorable",false)
	remove_from_group(&"destructible_terrain")
	queue_free()
	return true

func _draw() -> void:
	# Quiet enamel pressure plate; only its real warning gains a bright border.
	# Draw bounds do not change the receiver or the stepped danger radius.
	var outline := Color("123b3b")
	var accent := Color("35b8ac") if enabled else Color("82988b")
	var warning := stage==Stage.WARNING
	if warning:
		var progress := clampf(elapsed/WARNING_SECONDS,0,1)
		draw_circle(Vector2.ZERO,trigger_radius,Color(0.95,0.48,0.29,0.14))
		draw_arc(Vector2.ZERO,trigger_radius,0,TAU,48,outline,5,true)
		draw_arc(Vector2.ZERO,trigger_radius,0,TAU,48,Color("f27a4b"),2.5,true)
		draw_arc(Vector2.ZERO,trigger_radius-4,-PI/2,-PI/2+TAU*progress,48,Color("f3eddc"),2,true)
	draw_circle(Vector2(0,3),20,Color(0.07,0.23,0.23,0.24))
	var hull := PackedVector2Array([Vector2(-14,-10),Vector2(14,-10),Vector2(19,0),Vector2(14,12),Vector2(-14,12),Vector2(-19,0)])
	draw_colored_polygon(hull,accent.darkened(0.25) if stage==Stage.COOLDOWN else Color("f3eddc"))
	var border := hull.duplicate(); border.append(hull[0])
	draw_polyline(border,outline,2.5,true)
	draw_circle(Vector2(0,1),10,outline)
	draw_circle(Vector2(0,0),7,Color("f27a4b") if warning else accent)
	draw_line(Vector2(-4,0),Vector2(4,0),outline,2,true)
	for x in [-13.0,13.0]: draw_circle(Vector2(x,0),1.5,outline)
	if health!=null:
		var fraction := clampf(health.current_health/health.max_health,0,1)
		draw_rect(Rect2(-18,-19,36,6),outline)
		draw_rect(Rect2(-16,-17,32*fraction,2),Color("9bd7bd"))
