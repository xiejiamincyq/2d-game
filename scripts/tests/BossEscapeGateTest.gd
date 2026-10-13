extends SceneTree
const Gate = preload("res://scripts/components/BossEscapeGate.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BossEscapeGateTest "+label)
func run() -> void:
	var host := Node2D.new(); root.add_child(host)
	var player := Player.new(); host.add_child(player); player.set_physics_process(false)
	await physics_frame; await physics_frame
	var bounds := Rect2(-300,-300,600,600)
	var danger := func(at: Vector2,_age: float) -> bool: return at.length()<=44+player.get_body_radius()+3
	var route := {}
	check(not Gate.has_route(host,player,0.32,0.45,bounds,danger,route) and route.is_empty(),"old vent permits impossible reaction escape")
	check(Gate.has_route(host,player,0.70,0.45,bounds,danger,route),"normal vent no direct route")
	check(not route.is_empty() and is_equal_approx(route.radius,player.get_body_radius()) and route.mask==player.collision_mask,"witness omits actual physical body")
	var heading: Vector2 = (route.end-route.start).normalized()
	check(absf(heading.y)<0.00001 and heading.x>0,"accepted route is not a WASD direction")
	check(Gate.route_still_clear(host,player,route),"new clear witness not repeatable")
	var wall := StaticBody2D.new(); wall.position = (route.start+route.end)/2
	var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new()
	shape.size = Vector2(10,140); collision.shape = shape; wall.add_child(collision); host.add_child(wall)
	await physics_frame; await physics_frame
	check(not Gate.route_still_clear(host,player,route),"new blocker is ignored during warning")
	wall.free(); await physics_frame
	player.move_speed = 100
	check(not Gate.has_route(host,player,0.70,0.45,bounds,danger,route),"slower actual player gets fictitious 235px escape")
	player.move_speed = 235; player.position = Vector2(350,0)
	check(not Gate.has_route(host,player,0.7,0.45,bounds,danger,route),"outside-world start admitted")
	host.free(); await process_frame
	if not failures: print("TEST PASS: BossEscapeGateTest %d" % checks)
	quit(1 if failures else 0)
