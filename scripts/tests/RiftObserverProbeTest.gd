extends SceneTree
## Real Actor/Player and controlled relative segments; not a natural Boss victory.
const SOURCE := "res://scripts/components/RiftObserverProbe.gd"
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const Terrain = preload("res://scripts/world/TerrainSweep.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverProbeTest "+label)
func reset(player: Node) -> void:
	player.health.current_health = 100; player.health.invulnerable_time = 0
func obstacle(at: Vector2,layer: int) -> StaticBody2D:
	var body := StaticBody2D.new(); body.position = at; body.collision_layer = layer; body.collision_mask = 0
	var box := RectangleShape2D.new(); box.size = Vector2(2,100)
	var collision := CollisionShape2D.new(); collision.shape = box; body.add_child(collision); return body
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"actual finite locked Observer probe missing")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := PlayerScript.new(); player.position = Vector2(220,0); host.add_child(player); player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(6,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	await physics_frame
	var probe = load(SOURCE).new(); var pair = load(SOURCE).new()
	check(probe.RADIUS==6 and probe.DAMAGE==27 and is_equal_approx(probe.LIFE_SECONDS,0.20),"candidate probe contract")
	check(player.health.max_health==100 and player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9),"ordinary Player modified")
	for heading in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2(1,1).normalized()]:
		reset(player); player.position = heading*220; var landing: Vector2 = player.position; var ledger := {"attempted":false}
		check(probe.arm(boss,player,Vector2.ZERO,landing,ledger),"clear mirrored probe cannot arm")
		check(probe.position==Vector2.ZERO and player.health.current_health==100 and not ledger.attempted,"birth already damages")
		probe.resolve_hit(0,0.06,player.position,player.position)
		check(probe.position.is_equal_approx(landing*0.5) and player.health.current_health==100,"not single outward finite path")
		probe.resolve_hit(0.06,0.12,player.position,player.position)
		check(probe.position.is_equal_approx(landing) and player.health.current_health==73 and ledger.attempted,"standing normal Player misses true 9x3")
		player.health.invulnerable_time = 0; probe.resolve_hit(0.12,0.16,player.position,player.position); probe.resolve_hit(0.16,0.20,player.position,player.position)
		check(probe.armed and probe.position==landing and player.health.current_health==73,"closing visible footprint repeats/returns")
		probe.resolve_hit(0.20,0.21,player.position,player.position)
		check(not probe.armed and player.health.current_health==73,"expired probe retains authority")
		reset(player); check(probe.arm(boss,player,Vector2.ZERO,landing,{"attempted":false}),"crossing fixture arm")
		var side: Vector2 = heading.orthogonal()
		probe.resolve_hit(0,0.06,heading*110-side*90,heading*110+side*90)
		check(player.health.current_health==100,"spatial crossing at different times causes false hit")
		check(probe.arm(boss,player,Vector2.ZERO,landing,{"attempted":false}),"simultaneous crossing arm")
		probe.resolve_hit(0,0.06,heading*55-side*90,heading*55+side*90)
		check(player.health.current_health==73,"relative two-frame crossing tunnels")
		for gap in [22.8,23.0]:
			reset(player); check(probe.arm(boss,player,Vector2.ZERO,landing,{"attempted":false}),"rounded moving circle fixture")
			var at: Vector2 = heading*110+side*gap
			probe.resolve_hit(0,0.06,at,at)
			check(player.health.current_health==(73 if gap<22.9 else 100),"actual round body side threshold")
	reset(player); player.position = Vector2(220,0); var shared := {"attempted":false}
	check(probe.arm(boss,player,Vector2.ZERO,player.position,shared) and pair.arm(boss,player,Vector2(0,30),player.position,shared),"finite pair fixture")
	player.health.invulnerable_time = 10; probe.resolve_hit(0,0.06,player.position,player.position); probe.resolve_hit(0.06,0.12,player.position,player.position)
	player.health.invulnerable_time = 0; pair.resolve_hit(0,0.06,player.position,player.position); pair.resolve_hit(0.06,0.12,player.position,player.position)
	check(player.health.current_health==100 and shared.attempted,"immune rejection retries through second probe")
	reset(player); check(probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"late lifetime clipping fixture")
	probe.resolve_hit(0,0.06,Vector2(500,0),Vector2(500,0)); probe.resolve_hit(0.06,0.12,Vector2(500,0),Vector2(500,0))
	probe.resolve_hit(0.12,0.18,Vector2(500,0),Vector2(500,0)); probe.resolve_hit(0.18,0.22,Vector2(500,0),player.position)
	check(player.health.current_health==100 and probe.armed and probe.position==player.position,"lifetime tail damage or closing visual erased")
	probe.resolve_hit(0.20,0.21,player.position,player.position); check(not probe.armed,"end closes next frame")
	for layer in [1,Terrain.QUERY_LAYER]:
		var wall := obstacle(Vector2(100,0),layer); host.add_child(wall); await physics_frame
		check(not probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"thin wall ignored layer %s"%layer)
		wall.position.y = 150; await physics_frame
		check(probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"clear moved wall rejected")
		wall.position.y = 0; await physics_frame; probe.resolve_hit(0,0.06,player.position,player.position)
		check(not probe.armed and player.health.current_health==100,"later wall leaves damage authority")
		wall.free(); await physics_frame
	var mover := CharacterBody2D.new(); mover.position = Vector2(100,0); mover.collision_layer = 1
	var mover_collision := CollisionShape2D.new(); var mover_shape := CircleShape2D.new(); mover_shape.radius = 14
	mover_collision.shape = mover_shape; mover.add_child(mover_collision); host.add_child(mover); await physics_frame
	check(probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"ordinary neighbour becomes a wall")
	mover.collision_layer |= Terrain.QUERY_LAYER; await physics_frame
	check(not probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"tagged dynamic terrain ignored")
	mover.free(); await physics_frame
	var dense := Node2D.new(); host.add_child(dense)
	for _index in Terrain.MAX_CONTACTS:
		var body := CharacterBody2D.new(); body.position = Vector2(100,0); body.collision_layer = 1
		var collision := CollisionShape2D.new(); var circle := CircleShape2D.new(); circle.radius = 2
		collision.shape = circle; body.add_child(collision); dense.add_child(body)
	await physics_frame
	check(not probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"saturated terrain query fails open")
	dense.free(); await physics_frame
	check(not probe.arm(boss,player,Vector2(995,0),Vector2(775,0),{"attempted":false}),"full circular birth exceeds world")
	for entrance in [false,true]:
		boss.entrance_resolved = entrance
		check(probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false})==entrance,"unresolved actual entrance bypassed")
	reset(player); check(probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"zero-time fixture")
	probe.resolve_hit(0,0,Vector2.ZERO,Vector2.ZERO)
	check(player.health.current_health==100 and probe.armed and probe.age==0,"zero elapsed causes previsible birth damage")
	for landing in [Vector2.ZERO,Vector2(NAN,0),Vector2(INF,0),Vector2(361,0),Vector2(1e30,0)]:
		check(not probe.arm(boss,player,Vector2.ZERO,landing,{"attempted":false}),"invalid/overrange landing admitted")
	check(not probe.arm(boss,player,Vector2.ZERO,player.position,{}),"malformed ledger admitted")
	for times in [[NAN,0.01],[0,INF],[-0.01,0.02],[0.03,0.02],[0,0.1]]:
		check(probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"invalid-time fixture arm")
		probe.resolve_hit(times[0],times[1],player.position,player.position); check(not probe.armed,"invalid time span retains authority")
	check(probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"pause fixture")
	paused = true; probe.resolve_hit(0,0.01,player.position,player.position); check(not probe.armed,"pause authority persists"); paused = false
	boss.health.current_health = 0; check(not probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"dead Owner admitted"); boss.health.current_health = 10800
	check(probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"departure fixture")
	host.remove_child(player); probe.resolve_hit(0,0.01,Vector2.ZERO,Vector2.ZERO); check(not probe.armed,"departed target retained"); host.add_child(player)
	reset(player); shared = {"attempted":false}; check(probe.arm(boss,player,Vector2.ZERO,player.position,shared),"live callback fixture")
	var rearm := [false]
	var callback := func(_current,_maximum):
		player.health.invulnerable_time = 0
		rearm[0] = probe.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false})
		probe.resolve_hit(0.06,0.12,player.position,player.position)
	player.health.health_changed.connect(callback,CONNECT_ONE_SHOT)
	probe.resolve_hit(0,0.06,player.position,player.position); probe.resolve_hit(0.06,0.12,player.position,player.position)
	check(player.health.current_health==73 and shared.attempted and not rearm[0],"Health callback rearms or repeats")
	probe.cancel(); probe.cancel(); pair.cancel(); host.free(); await process_frame
	if not failures: print("TEST PASS: RiftObserverProbeTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
