extends SceneTree
## Actual bounded sweeps/real actors; controlled flight steps, not ordinary play.
const SOURCE := "res://scripts/components/BellPriestPendantProjectile.gd"
const Boss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BellPriestPendantProjectileTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"real fixed out-and-back pendant absent")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); shots.position = Vector2(50,70); host.add_child(shots)
	var player := Player.new(); player.position = Vector2(130,0); host.add_child(player); player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(5,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var ledger := {"attempted":false}; var pair: Array[Node2D] = []
	for at in [Vector2.ZERO,Vector2(0,24)]:
		var shot = load(SOURCE).new(); shot.configure(boss,player,at,Vector2.RIGHT,ledger); shots.add_child(shot); shot.set_physics_process(false); pair.append(shot)
		check(shot.global_position==at and shot.origin==at,"translated parent corrupts fixed origin")
	await physics_frame; await process_frame
	for tick in 4:
		for shot in pair: shot._physics_process(0.05)
	check(pair[0].global_position==Vector2(180,0) and pair[0].returning,"outbound distance/turnpoint wrong")
	check(player.health.current_health==70 and ledger.attempted,"two eligible pendants must share 10 x 3 damage attempt")
	player.health.invulnerable_time = 0; boss.position = Vector2(-300,-200)
	for tick in 4:
		for shot in pair: shot._physics_process(0.05)
	check(player.health.current_health==70,"return/other pendant retries damage")
	check(pair[0].global_position.is_equal_approx(Vector2.ZERO) and pair[1].global_position.is_equal_approx(Vector2(0,24)) and pair[0].is_queued_for_deletion(),"return follows moving actor instead of fixed origin")
	await process_frame; check(shots.get_child_count()==0,"finite pair leaks")
	player.health.current_health = 100; player.health.invulnerable_time = 0
	var wall := StaticBody2D.new(); wall.position = Vector2(70,0)
	var collider := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(2,60); collider.shape = shape; wall.add_child(collider); host.add_child(wall)
	await physics_frame; await process_frame
	var shot = load(SOURCE).new(); shot.configure(boss,player,Vector2.ZERO,Vector2.RIGHT,{"attempted":false}); shots.add_child(shot); shot.set_physics_process(false)
	shot._physics_process(0.4)
	check(shot.is_queued_for_deletion() and not shot.visible and shot.global_position.x<70 and player.health.current_health==100,"large step crosses thin wall/turn before first blocker")
	await process_frame; wall.queue_free(); await process_frame
	shot = load(SOURCE).new(); shot.configure(boss,player,Vector2.ZERO,Vector2.RIGHT,{"attempted":false}); shots.add_child(shot); shot.set_physics_process(false)
	var initial: Transform2D = shot.global_transform
	for delta in [-1.0,0.0,NAN,INF]: shot._physics_process(delta)
	check(shot.global_transform==initial and shot.elapsed==0,"invalid flight time moves")
	shot._physics_process(5)
	check(shot.is_queued_for_deletion() and shot.global_position.is_equal_approx(Vector2.ZERO) and player.health.current_health==70,"hitch loses bounded return or finite damage")
	await process_frame; player.health.current_health = 100; player.health.invulnerable_time = 0
	boss.world_bounds = Rect2(-100,-100,200,200)
	shot = load(SOURCE).new(); shot.configure(boss,player,Vector2.ZERO,Vector2.RIGHT,{"attempted":false}); shots.add_child(shot); shot.set_physics_process(false); shot._physics_process(0.5)
	check(shot.is_queued_for_deletion() and shot.global_position.x<=92.001 and player.health.current_health==100,"flight damages past world footprint")
	await process_frame
	host.free(); await process_frame
	if not failures: print("TEST PASS: BellPriestPendantProjectileTest %d"%checks)
	quit(1 if failures else 0)
