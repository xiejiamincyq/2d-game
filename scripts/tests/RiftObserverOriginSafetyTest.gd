extends SceneTree
## Actual articulated sockets and real terrain layers, not a simulated emitter.
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const Terrain = preload("res://scripts/world/TerrainSweep.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverOriginSafetyTest "+label)
func wall(host: Node2D,at: Vector2,extent: Vector2,angle: float,layer: int) -> StaticBody2D:
	var body := StaticBody2D.new(); body.position = at; body.rotation = angle; body.collision_layer = layer; body.collision_mask = 0
	var shape := RectangleShape2D.new(); shape.size = extent
	var collision := CollisionShape2D.new(); collision.shape = shape; body.add_child(collision); host.add_child(body); return body
func run() -> void:
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := PlayerScript.new(); player.position = Vector2(600,300); host.add_child(player); player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(6,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	for facing_left in [false,true]:
		boss.get_visual_node().set_facing_left(facing_left); boss.get_visual_node().sample_clip("idle",0)
		for entry in [[&"beam",8.0],[&"probes_left",6.0],[&"probes_right",6.0],[&"refract",8.0]]:
			var raw: Vector2 = boss.get_visual_node().skeleton.get_node(boss.SOCKETS[entry[0]]).global_position
			check(raw.distance_to(boss.global_position)>24,"socket is not actual external articulated marker")
			check(boss.get_action_origin(entry[0],entry[1]).is_equal_approx(raw),"clear socket rejected")
			for layer in [1,Terrain.QUERY_LAYER]:
				var delta := raw-boss.global_position
				var obstacle := wall(host,boss.global_position.lerp(raw,0.5),Vector2(2,32),delta.angle(),layer)
				await physics_frame
				check(boss.get_action_origin(entry[0],entry[1]).is_equal_approx(boss.global_position),"socket born beyond centre-to-socket thin wall layer %s"%layer)
				obstacle.free(); await physics_frame
				obstacle = wall(host,raw+Vector2(entry[1]-0.5,0),Vector2(1,16),0,layer)
				await physics_frame
				check(boss.get_action_origin(entry[0],entry[1]).is_equal_approx(boss.global_position),"socket circle overlaps terrain layer %s"%layer)
				obstacle.free(); await physics_frame
			var bounds: Rect2 = boss.world_bounds
			boss.world_bounds = Rect2(boss.position-Vector2(16,16),Vector2(32,32))
			check(boss.get_action_origin(entry[0],entry[1]).is_equal_approx(boss.global_position),"socket emitted beyond world bounds")
			boss.world_bounds = bounds
	check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.body_radius==56,"physical Boss changed for socket proof")
	check(player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9) and player.health.current_health==100,"Player modified")
	host.free(); await process_frame
	if not failures: print("TEST PASS: RiftObserverOriginSafetyTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
