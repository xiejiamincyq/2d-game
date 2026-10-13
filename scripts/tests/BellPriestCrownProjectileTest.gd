extends SceneTree
## Actual player body, canonical finite sweep, original crown stats/ownership.
const SOURCE := "res://scripts/components/BellPriestCrownProjectile.gd"
const Boss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BellPriestCrownProjectileTest "+label)
func _initialize() -> void: call_deferred("run")
func barrier(host: Node2D,at: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new(); body.position = at
	var collider := CollisionShape2D.new(); var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2,240); collider.shape = rectangle; body.add_child(collider); host.add_child(body)
	return body
func fire(shots: Node2D,boss: CharacterBody2D,player: Node2D,bounds: Rect2 = Rect2(-1000,-1000,2000,2000)) -> Node2D:
	var shot = load(SOURCE).new(); shot.position = shots.to_local(Vector2(20,0))
	shot.world_bounds = bounds; shot.collision_layer = 0; shot.collision_mask = boss.collision_mask
	shot.set_target(player); shots.add_child(shot); shot.ignore_source(boss)
	return shot
func gone(shot: Node) -> bool:
	var deadline := Time.get_ticks_msec()+1800
	while is_instance_valid(shot) and Time.get_ticks_msec()<deadline: await physics_frame
	return not is_instance_valid(shot)
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"independent crown projectile absent")
	if failures: quit(1); return
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		var host := Node2D.new(); root.add_child(host)
		var shots := Node2D.new(); shots.position = Vector2(60,80); host.add_child(shots)
		var player := Player.new(); player.position = Vector2(180,0); host.add_child(player); player.set_physics_process(false)
		var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(5,shots,player); host.add_child(boss); boss.set_physics_process(false)
		await physics_frame; await physics_frame
		var shot = fire(shots,boss,player)
		check(shot.global_position==Vector2(20,0) and shot.radius==4 and shot.damage==18 and shot.velocity==Vector2(440,0) and is_equal_approx(shot.lifetime,1.05),"actual finite crown stats/translated birth")
		check(shot.sweep_query.exclude.has(boss.get_rid()),"source body not excluded")
		check(await gone(shot) and player.health.current_health==82,"crown not actual one-shot 18 damage")
		player.health.current_health = 100; player.health.invulnerable_time = 0
		var wall := barrier(host,Vector2(90,0)); await physics_frame; await physics_frame
		shot = fire(shots,boss,player)
		check(await gone(shot) and player.health.current_health==100,"swept crown crosses thin wall")
		wall.free(); await physics_frame; await physics_frame
		shot = fire(shots,boss,player,Rect2(-100,-100,200,200))
		check(await gone(shot) and player.health.current_health==100,"crown damages beyond footprint boundary")
		shot = fire(shots,boss,player); shot.set_physics_process(false); shot.lifetime = 0.1
		shot._physics_process(2)
		check(shot.is_queued_for_deletion() and shot.global_position.x<=64.001 and player.health.current_health==100,"hitch bypasses finite lifetime")
		shot._try_hit(player); check(player.health.current_health==100,"queued crown takes late callback")
		await process_frame
		shot = fire(shots,boss,player); shot.set_physics_process(false)
		host.remove_child(player); shot._physics_process(0.1)
		check(shot.is_queued_for_deletion() and not shot.visible,"departed linked target leaves live crown")
		player.free(); host.free(); await process_frame
	Engine.physics_ticks_per_second = original_rate
	if not failures: print("TEST PASS: BellPriestCrownProjectileTest %d"%checks)
	quit(1 if failures else 0)
