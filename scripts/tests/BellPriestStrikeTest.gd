extends SceneTree
## Locked capsule and real bodies/terrain; controlled mechanism, not ordinary play.
const SOURCE := "res://scripts/components/BellPriestStrike.gd"
const Boss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BellPriestStrikeTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"actual narrow bell strike absent")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := Player.new(); player.position = Vector2(130,0); host.add_child(player); player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000)
	boss.setup(5,shots,player); host.add_child(boss); boss.set_physics_process(false)
	boss.attack_director.advance(1.4); boss._update_entrance_reveal()
	var strike = load(SOURCE).new()
	check(strike.arm(boss,player,Vector2.ZERO,Vector2.RIGHT),"finite clear capsule cannot arm")
	check(strike.origin==Vector2.ZERO and strike.tip==Vector2(140,0) and is_equal_approx(strike.RADIUS,12),"locked footprint wrong")
	strike.resolve_hit(Vector2(130,0),Vector2(130,0))
	check(player.health.current_health==64 and strike.attempted,"actual emitter damage must be 12 x 3")
	player.health.invulnerable_time = 0; strike.resolve_hit(player.position,player.position)
	check(player.health.current_health==64,"same strike retries accepted damage")
	strike.cancel(); player.health.current_health = 100; player.health.invulnerable_time = 10
	check(strike.arm(boss,player,Vector2.ZERO,Vector2.RIGHT),"immune fixture cannot arm")
	strike.resolve_hit(player.position,player.position); player.health.invulnerable_time = 0
	strike.resolve_hit(player.position,player.position)
	check(player.health.current_health==100 and strike.attempted,"immunity retries within same strike")
	check(strike.arm(boss,player,Vector2.ZERO,Vector2.RIGHT),"crossing fixture cannot arm")
	strike.resolve_hit(Vector2(70,-80),Vector2(70,80))
	check(player.health.current_health==64,"full capsule sweep misses crossing between frames")
	player.health.current_health = 100; player.health.invulnerable_time = 0
	check(strike.arm(boss,player,Vector2.ZERO,Vector2.RIGHT),"outside fixture cannot arm")
	strike.resolve_hit(Vector2(130,40),Vector2(130,40))
	check(player.health.current_health==100 and not strike.attempted,"rectangular/capsule padding damages outside")
	var wall := StaticBody2D.new(); wall.position = Vector2(70,0)
	var collider := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(2,60)
	collider.shape = shape; wall.add_child(collider); host.add_child(wall); await physics_frame; await process_frame
	check(not strike.arm(boss,player,Vector2.ZERO,Vector2.RIGHT),"default-layer1 thin terrain ignored")
	wall.position = Vector2(70,100); await physics_frame; await process_frame
	check(strike.arm(boss,player,Vector2.ZERO,Vector2.RIGHT),"clear terrain remains blocked")
	wall.position = Vector2(70,0); await physics_frame; await process_frame
	strike.resolve_hit(player.position,player.position)
	check(player.health.current_health==100 and not strike.armed,"new wall during active strike bypassed")
	wall.queue_free(); await process_frame
	for direction in [Vector2.ZERO,Vector2(NAN,0),Vector2(INF,0)]: check(not strike.arm(boss,player,Vector2.ZERO,direction),"invalid vector accepted")
	check(strike.arm(boss,player,Vector2.ZERO,Vector2.RIGHT),"cancel fixture cannot arm")
	strike.cancel(); strike.resolve_hit(player.position,player.position)
	check(not strike.armed and player.health.current_health==100,"cancelled attack has damage authority")
	host.free(); await process_frame
	if not failures: print("TEST PASS: BellPriestStrikeTest %d"%checks)
	quit(1 if failures else 0)
