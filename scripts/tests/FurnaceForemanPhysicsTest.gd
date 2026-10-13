extends SceneTree
func advance_warning(clock, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 1.0/120.0)
		clock.advance(step)
		remaining = maxf(0.0, remaining-step)
## Real Godot sweeps and automatic physics clock, not a normal-input victory.
const Director = preload("res://scripts/components/FurnaceForemanAttackDirector.gd")
const Health = preload("res://scripts/components/HealthComponent.gd")
class Target extends CharacterBody2D:
	var hits: Array[float] = []
	var health: Node
	var lethal := false
	func _ready() -> void:
		health = Health.new(); add_child(health)
	func is_alive() -> bool: return health.current_health>0
	func get_body_radius() -> float: return 13.0
	func take_damage(amount: float,_source: StringName = &"") -> void:
		hits.append(amount)
		if lethal: health.damage(health.current_health,true)
class Boss extends CharacterBody2D:
	var death_resolved := false
	var body_radius := 56.0
	var world_bounds := Rect2(-1000,-1000,2000,2000)
	var director: Node
	func get_safe_heat_origin() -> Vector2: return global_position+Vector2(60,-12)
	# Geometry fixture has a fixed nozzle; production actors sample native bones.
	func _update_boss_motion(_delta: float) -> void: pass
	func _physics_process(delta: float) -> void:
		if director!=null: director.advance(delta)
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: FurnaceForemanPhysicsTest "+label)
func _initialize() -> void: call_deferred("run")
func collider(body: CollisionObject2D,radius: float) -> void:
	var shape := CollisionShape2D.new(); var circle := CircleShape2D.new(); circle.radius = radius
	shape.shape = circle; body.add_child(shape); body.collision_layer = 2; body.collision_mask = 1
func wait_until(predicate: Callable) -> bool:
	var end := Time.get_ticks_msec()+2500
	while not predicate.call() and Time.get_ticks_msec()<end: await physics_frame
	return predicate.call()
func wall_at(host: Node2D,x: float,height: float = 220) -> Node2D:
	var wall := StaticBody2D.new(); wall.position.x = x
	var shape := CollisionShape2D.new(); var rect := RectangleShape2D.new(); rect.size = Vector2(2,height)
	shape.shape = rect; wall.add_child(shape); host.add_child(wall); return wall
func run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second = hz
		var host := Node2D.new(); root.add_child(host)
		var boss := Boss.new(); collider(boss,56); host.add_child(boss)
		var target := Target.new(); collider(target,13); target.position = Vector2(150,0); host.add_child(target)
		var director := Director.new(); boss.add_child(director); director.configure(boss,target,null)
		director.advance(1.4); director.attack_gap = 99; boss.director = director
		check(director.start_action(&"ram"),"automatic ram cannot arm %s"%hz)
		check(await wait_until(func(): return director.action_stage==Director.Stage.RECOVERY),"automatic ram recovery %s"%hz)
		check(is_equal_approx(boss.position.x,240) and boss.position.y==0,"only active subinterval moves 240px %s"%hz)
		check(target.hits==[54.0],"swept hit once at actual speed %s"%hz)
		check(not director.blocked,"open floor falsely blocked")
		boss.set_physics_process(false); director.cancel_action(); boss.position = Vector2.ZERO; target.hits.clear()
		var wall := wall_at(host,100); await physics_frame; await physics_frame
		check(director.start_action(&"ram"),"thin-wall ram cannot arm")
		advance_warning(director,director.DURATIONS[&"ram"][0]); director.advance(1)
		check(director.blocked and director.action_stage==Director.Stage.RECOVERY,"thin wall fails to stop oversized step")
		check(boss.position.x<45 and boss.position.x>40 and boss.velocity==Vector2.ZERO,"physical body penetrates thin wall")
		check(target.hits.is_empty(),"wall blocks body but not damage")
		wall.free(); await physics_frame; await physics_frame
		# Keep the target's full circle inside this deliberately smaller world.
		# An out-of-world target cannot satisfy the real escape admission gate.
		director.cancel_action(); boss.position = Vector2.ZERO; target.position = Vector2(386.999,0)
		boss.world_bounds = Rect2(-400,-400,800,800)
		check(director.start_action(&"ram"),"boundary ram absent")
		advance_warning(director,director.DURATIONS[&"ram"][0]); director.advance(0.5)
		check(not director.blocked and is_equal_approx(boss.position.x,240),"normal full ram incorrectly clipped")
		director.cancel_action(); check(director.start_action(&"ram"),"second boundary ram absent")
		advance_warning(director,director.DURATIONS[&"ram"][0]); director.advance(0.5)
		check(director.blocked and boss.position.x<=344 and boss.position.x>=343.9,"world edge fails to stop body")
		check(target.hits==[54.0],"legal boundary target receives exactly one swept hit")
		target.hits.clear()
		director.cancel_action(); boss.position = Vector2.ZERO; target.position = Vector2(180,0); boss.world_bounds = Rect2(-1000,-1000,2000,2000)
		wall = wall_at(host,120); await physics_frame; await physics_frame
		check(director.start_action(&"jet"),"wall-blocked fan absent")
		advance_warning(director,director.DURATIONS[&"jet"][0])
		check(target.hits.is_empty() and Array(director.jet_points).all(func(point): return point.x<=119.001),"jet damage or visual extends through thin wall")
		wall.free(); await physics_frame; await physics_frame; director.advance(0.01)
		check(target.hits==[48.0],"late entry/unblocking cannot be hit")
		director.cancel_action(); check(director.start_action(&"ram"),"pause fixture absent")
		paused = true; await process_frame; await process_frame
		check(not director.is_attacking() and boss.position==Vector2.ZERO,"actual tree pause fails to cancel")
		paused = false; director.advance(0.01)
		check(not director.is_attacking() and director.attack_gap>1,"resume immediately re-arms")
		check(director.start_action(&"vents"),"death fixture absent")
		target.health.damage(target.health.current_health,true)
		check(not director.is_attacking() and director.vent_centers.is_empty(),"real health death doesn't cancel synchronously")
		director.advance(10); check(target.hits==[48.0],"dead target still damaged")
		host.free(); await process_frame
		# A colliding lethal hit emits Health.died synchronously inside the sweep.
		# Collision recovery must not re-arm the action canceled by that callback.
		host = Node2D.new(); root.add_child(host)
		boss = Boss.new(); collider(boss,56); host.add_child(boss); boss.set_physics_process(false)
		target = Target.new(); collider(target,13); target.collision_layer = 1
		target.position = Vector2(100,0); target.lethal = true; host.add_child(target)
		director = Director.new(); boss.add_child(director); director.configure(boss,target,null); director.advance(1.4)
		await physics_frame; await physics_frame
		check(director.start_action(&"ram"),"lethal collision fixture cannot arm")
		advance_warning(director,director.DURATIONS[&"ram"][0]); director.advance(0.5)
		check(not target.is_alive() and target.hits==[54.0],"real collider lethal damage not reached")
		check(not director.is_attacking() and director.action==&"" and boss.velocity==Vector2.ZERO,"collision recovery re-arms canceled action after synchronous target death")
		host.free(); await process_frame
	Engine.physics_ticks_per_second = original_hz
	if not failures: print("TEST PASS: FurnaceForemanPhysicsTest %d"%checks)
	quit(1 if failures else 0)
