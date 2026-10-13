extends SceneTree
## Real bodies/Health/terrain with controlled sweep segments, not playable Boss/AI.
const SOURCE := "res://scripts/components/RiftObserverBeam.gd"
const PlayerScript = preload("res://scripts/actors/Player.gd")
const Health = preload("res://scripts/components/HealthComponent.gd")
const Terrain = preload("res://scripts/world/TerrainSweep.gd")
class Emitter extends CharacterBody2D:
	var entrance_resolved := true
	var death_resolved := false
	var health: Node
	var world_bounds := Rect2(-1000,-1000,2000,2000)
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverBeamTest "+label)
func synced() -> void: await physics_frame; await process_frame
func wall(at: Vector2,layer: int = 1) -> StaticBody2D:
	var body := StaticBody2D.new(); body.position = at; body.collision_layer = layer
	var collision := CollisionShape2D.new(); var box := RectangleShape2D.new(); box.size = Vector2(2,100)
	collision.shape = box; body.add_child(collision); return body
func reset_player(player: Node) -> void:
	player.health.current_health = 100; player.health.invulnerable_time = 0
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"actual locked observer beam missing")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var player := PlayerScript.new(); player.position = Vector2(220,0); host.add_child(player); player.set_physics_process(false)
	var emitter := Emitter.new(); host.add_child(emitter); emitter.health = Health.new(); emitter.health.max_health = 1000; emitter.add_child(emitter.health)
	await synced()
	var beam = load(SOURCE).new()
	check(is_equal_approx(player.get_body_radius(),16.9) and player.health.max_health==100,"normal physical player changed")
	check(beam.LENGTH==360 and beam.RADIUS==8 and beam.DAMAGE==36,"candidate footprint/base triple damage")
	check(beam.arm(emitter,player,Vector2.ZERO,Vector2(5,0)),"clear beam cannot arm")
	check(beam.origin==Vector2.ZERO and beam.tip==Vector2(360,0),"direction normalization/locked endpoints")
	player.position = Vector2(220,70)
	beam.resolve_hit(player.position,player.position)
	check(player.health.current_health==100 and not beam.attempted and beam.tip==Vector2(360,0),"tracks player or damages outside")
	player.position = Vector2(220,0); beam.resolve_hit(player.position,player.position)
	check(player.health.current_health==64 and beam.attempted,"standing player avoids real 12x3")
	player.health.invulnerable_time = 0; beam.resolve_hit(player.position,player.position)
	check(player.health.current_health==64,"same beam retries damage")
	reset_player(player); player.health.invulnerable_time = 10
	check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"immune context rejects arm")
	beam.resolve_hit(player.position,player.position); player.health.invulnerable_time = 0
	beam.resolve_hit(player.position,player.position)
	check(player.health.current_health==100 and beam.attempted,"immune rejection retries after recovery")
	check(beam.arm(emitter,player,Vector2.ZERO,Vector2(1e30,0)) and beam.tip.is_equal_approx(Vector2(360,0)),"finite large direction overflows normalization")
	for distance in [-24.8,-25.0,384.8,385.0]:
		reset_player(player); check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"round endcap arm")
		var at := Vector2(distance,0); beam.resolve_hit(at,at)
		check(player.health.current_health==(64 if distance in [-24.8,384.8] else 100),"capsule endcap becomes padded rectangle")
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2(1,1).normalized()]:
		reset_player(player); player.position = direction*220
		check(beam.arm(emitter,player,Vector2.ZERO,direction),"finite mirrored/diagonal arm")
		beam.resolve_hit(player.position,player.position)
		check(player.health.current_health==64,"mirror/diagonal sweep misses real body")
		reset_player(player); var side: Vector2 = direction.orthogonal()
		check(beam.arm(emitter,player,Vector2.ZERO,direction),"crossing arm")
		beam.resolve_hit(direction*180-side*90,direction*180+side*90)
		check(player.health.current_health==64,"cross-frame crossing misses capsule")
		for gap in [24.8,25.0]:
			reset_player(player); check(beam.arm(emitter,player,Vector2.ZERO,direction),"round-side threshold arm")
			var at: Vector2 = direction*180+side*gap; beam.resolve_hit(at,at)
			check(player.health.current_health==(64 if gap<24.9 else 100),"circle-edge padded/rectangular body")
	reset_player(player); player.position = Vector2(220,0)
	var obstacle := wall(Vector2(100,0)); host.add_child(obstacle); await synced()
	check(not beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"default layer1 thin wall ignored")
	obstacle.collision_layer = Terrain.QUERY_LAYER; await synced()
	check(not beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"query-only wall ignored")
	obstacle.position.y = 150; await synced()
	check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"moved-clear wall remains blocked")
	obstacle.position.y = 0; await synced(); beam.resolve_hit(player.position,player.position)
	check(player.health.current_health==100 and not beam.armed,"new active wall permits damage")
	obstacle.queue_free(); await synced()
	var mover := CharacterBody2D.new(); mover.position = Vector2(80,0); mover.collision_layer = 1
	var mover_shape := CollisionShape2D.new(); var mover_circle := CircleShape2D.new(); mover_circle.radius = 14
	mover_shape.shape = mover_circle; mover.add_child(mover_shape); host.add_child(mover); await synced()
	check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"ordinary dynamic actor becomes terrain")
	mover.collision_layer |= Terrain.QUERY_LAYER; await synced()
	check(not beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"marked dynamic terrain bypassed")
	mover.queue_free(); await synced()
	var dense := Node2D.new(); host.add_child(dense)
	for index in Terrain.MAX_CONTACTS:
		var body := CharacterBody2D.new(); body.position = Vector2(100,0); body.collision_layer = 1
		var shape_node := CollisionShape2D.new(); var circle := CircleShape2D.new(); circle.radius = 2
		shape_node.shape = circle; body.add_child(shape_node); dense.add_child(body)
	await synced()
	check(not beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"saturated contact query fails open")
	dense.queue_free(); await synced()
	for direction in [Vector2.ZERO,Vector2(NAN,0),Vector2(INF,0)]:
		check(not beam.arm(emitter,player,Vector2.ZERO,direction) and not beam.armed,"invalid direction authority")
	for at in [Vector2(NAN,0),Vector2(INF,0),Vector2(950,0)]:
		check(not beam.arm(emitter,player,at,Vector2.RIGHT),"invalid origin/border authority")
	for value in [false,true]:
		emitter.entrance_resolved = value
		check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT)==value,"entrance guard")
	emitter.health.current_health = 0
	check(not beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"owner health zero still armed")
	emitter.health.current_health = 1000; emitter.death_resolved = true
	check(not beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"resolved owner death armed")
	emitter.death_resolved = false; reset_player(player)
	player.stealth_remaining = 1.0
	check(not beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"hidden target armed")
	player.stealth_remaining = 0.0
	check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"stealth cancellation fixture")
	player.stealth_remaining = 1.0; beam.resolve_hit(player.position,player.position)
	check(not beam.armed and player.health.current_health==100,"target becomes hidden but beam still damages")
	player.stealth_remaining = 0.0
	check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"owner death cancellation fixture")
	emitter.health.current_health = 0; beam.resolve_hit(player.position,player.position)
	check(not beam.armed and player.health.current_health==100,"owner dies during active still damage")
	emitter.health.current_health = 1000
	check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"invalid sweep fixture")
	beam.resolve_hit(Vector2(NAN,0),player.position)
	check(not beam.armed and player.health.current_health==100,"invalid sweep leaves authority")
	check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"cancel fixture")
	beam.cancel(); beam.cancel(); beam.resolve_hit(player.position,player.position)
	check(not beam.armed and beam.actor==null and beam.target==null and player.health.current_health==100,"cancel residue")
	check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"paused fixture")
	paused = true; beam.resolve_hit(player.position,player.position)
	check(not beam.armed and player.health.current_health==100,"paused physics damage")
	paused = false
	check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"target death fixture")
	player.health.current_health = 0; beam.resolve_hit(player.position,player.position)
	check(not beam.armed,"target dead authority"); reset_player(player)
	check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"reentrant death fixture")
	var live_reentry := [0]
	player.health.health_changed.connect(func(_current: float,_maximum: float):
		if live_reentry[0]==0:
			live_reentry[0] = 1; player.health.invulnerable_time = 0
			beam.resolve_hit(player.position,player.position))
	beam.resolve_hit(player.position,player.position)
	check(player.health.current_health==64 and beam.attempted and live_reentry[0]==1,"live damage callback retries before latch")
	reset_player(player); check(beam.arm(emitter,player,Vector2.ZERO,Vector2.RIGHT),"terminal reentrant fixture")
	player.health.current_health = 30
	player.died.connect(func(): beam.resolve_hit(player.position,player.position),CONNECT_ONE_SHOT)
	beam.resolve_hit(player.position,player.position)
	check(player.health.current_health==0 and not beam.armed,"terminal reentrant death retains authority")
	emitter.queue_free(); await synced(); beam.resolve_hit(Vector2.ZERO,Vector2.ZERO)
	check(not beam.armed,"freed owner authority")
	host.free(); await process_frame
	if not failures: print("TEST PASS: RiftObserverBeamTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
