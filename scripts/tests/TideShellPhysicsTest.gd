extends SceneTree
## Actual actor, physics server walls and moving salt projectiles. Not victory.
const Boss = preload("res://scripts/actors/SaltTideBoss.gd")
const Health = preload("res://scripts/components/HealthComponent.gd")
class Target extends CharacterBody2D:
	var hits: Array[float] = []
	var health: Node
	func _ready() -> void:
		add_to_group(&"player")
		health = Health.new(); health.max_health = 1000; add_child(health)
	func is_alive() -> bool: return health.current_health>0
	func get_body_radius() -> float: return 13.0
	func take_damage(amount: float,_source: StringName = &"") -> void: hits.append(amount)
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: TideShellPhysicsTest "+label)
func _initialize() -> void: call_deferred("run")
func advance_warning(combat: Node,seconds: float = -1.0) -> void:
	var remaining: float = combat.DURATIONS[combat.action][0] if seconds<0 else seconds
	while remaining>0.0000001:
		var step := minf(1.0/120.0,remaining)
		combat.advance(step)
		remaining -= step

func wait_until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+3000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await physics_frame
	return predicate.call()
func make_wall(host: Node2D,at: Vector2,size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new(); wall.position = at
	var shape := CollisionShape2D.new(); var rectangle := RectangleShape2D.new(); rectangle.size = size
	shape.shape = rectangle; wall.add_child(shape); host.add_child(wall)
	return wall
func run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		var host := Node2D.new(); root.add_child(host)
		var shots := Node2D.new(); host.add_child(shots)
		var target := Target.new(); target.position = Vector2(200,0); host.add_child(target)
		var shape := CollisionShape2D.new(); var circle := CircleShape2D.new(); circle.radius = 13
		shape.shape = circle; target.add_child(shape)
		var boss := Boss.new(); boss.setup(3,shots,target); boss.world_bounds = Rect2(-600,-600,1200,1200); host.add_child(boss)
		var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
		check(combat.start_action(&"ripple"),"automatic ring cannot arm")
		check(await wait_until(func(): return combat.action_stage==combat.Stage.RECOVERY),"automatic ring recovery")
		check(target.hits==[42.0] and boss.position==Vector2.ZERO,"actual ring repeats or moves actor")
		boss.set_physics_process(false); combat.cancel_action(); target.hits.clear()
		var wall := make_wall(host,Vector2(100,0),Vector2(2,400)); await physics_frame; await physics_frame
		check(combat.start_action(&"ripple"),"wall ring cannot arm")
		advance_warning(combat); combat.advance(0.72)
		check(target.hits.is_empty() and not combat._point_visible(Vector2(200,0)),"ring damage/drawing passes 2px wall")
		combat.cancel_action(); check(combat.start_action(&"salt"),"wall fan cannot arm")
		advance_warning(combat)
		check(combat.owned_projectiles.size()==3,"real fan not spawned")
		check(await wait_until(func(): return shots.get_child_count()==0),"salt sweep leaks against wall")
		check(target.hits.is_empty(),"salt crosses thin wall")
		wall.free(); await physics_frame; await physics_frame
		combat.cancel_action(); check(combat.start_action(&"salt"),"open fan cannot arm")
		advance_warning(combat)
		check(await wait_until(func(): return not target.hits.is_empty()),"real salt never hits player collider")
		check(target.hits==[18.0],"open aimed fan damage/radius incorrect")
		combat.cancel_action(); await process_frame; target.hits.clear()
		target.position = Vector2(200,0); boss.world_bounds = Rect2(-190,-190,380,380)
		check(not combat.start_action(&"ripple") and not combat.is_attacking(),"out-of-bounds target admits attack")
		check(target.hits.is_empty() and not combat._point_visible(target.position),"ring hits/draws outside world")
		boss.world_bounds = Rect2(-600,-600,1200,1200); combat.cancel_action()
		check(combat.start_action(&"pincer"),"pause warning cannot arm")
		paused = true; await process_frame; await process_frame
		check(not combat.is_attacking() and not boss.should_show_attack_marker(),"pause retains hit/head")
		check(not "pincer" in String(boss.get_visual_node().player.current_animation),"pause retains cancelled bone action")
		paused = false; combat.advance(0.01)
		check(combat.attack_gap>1,"resume lacks safe gap")
		check(combat.start_action(&"salt"),"target death cannot arm")
		advance_warning(combat); target.health.damage(1000,true)
		check(not combat.is_attacking() and combat.owned_projectiles.is_empty(),"real health death leaves salt fan")
		host.free(); await process_frame
	Engine.physics_ticks_per_second = original_rate
	if not failures: print("TEST PASS: TideShellPhysicsTest %d" % checks)
	quit(1 if failures else 0)
