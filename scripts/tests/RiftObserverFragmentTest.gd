extends SceneTree
## Fixed Fragment on the real finite kernel; controlled geometry, not a victory.
const SOURCE := "res://scripts/components/RiftObserverFragment.gd"
const Kernel = preload("res://scripts/components/RiftObserverCircleFlight.gd")
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const Terrain = preload("res://scripts/world/TerrainSweep.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverFragmentTest "+label)
func reset(player: Node) -> void:
	player.health.current_health = 100; player.health.invulnerable_time = 0
func obstacle(layer: int) -> StaticBody2D:
	var body := StaticBody2D.new(); body.position = Vector2(100,0); body.collision_layer = layer; body.collision_mask = 0
	var box := RectangleShape2D.new(); box.size = Vector2(2,100)
	var collision := CollisionShape2D.new(); collision.shape = box; body.add_child(collision); return body
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"actual finite Observer fragment missing")
	if failures: quit(1); return
	var fragment = load(SOURCE).new()
	check(fragment.get_script().get_base_script()==Kernel,"fragment copies rather than uses canonical finite flight")
	check(fragment.RADIUS==4 and fragment.MAX_DISTANCE==360 and is_equal_approx(fragment.FLIGHT_SECONDS,0.09) and is_equal_approx(fragment.LIFE_SECONDS,0.09) and fragment.DAMAGE==24,"fixed radius/range/no-hold/damage profile")
	check(not fragment.has_method("_physics_process") and not fragment.has_method("_process"),"fragment owns a second clock")
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := PlayerScript.new(); player.position = Vector2(220,0); host.add_child(player); player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(6,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	await physics_frame
	check(player.health.max_health==100 and player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9),"ordinary Player altered")
	for heading in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,1).normalized()]:
		reset(player); player.position = heading*220; var ledger := {"attempted":false}
		check(fragment.arm(boss,player,Vector2.ZERO,player.position,ledger),"finite mirrored birth")
		fragment.resolve_hit(0,0,Vector2.ZERO,Vector2.ZERO)
		check(player.health.current_health==100 and not ledger.attempted and fragment.age==0,"birth/zero elapsed has premature damage")
		fragment.resolve_hit(0,0.045,player.position,player.position)
		check(fragment.position.is_equal_approx(heading*110) and player.health.current_health==100,"single outward speed")
		fragment.resolve_hit(0.045,0.09,player.position,player.position)
		check(player.health.current_health==76 and ledger.attempted and fragment.armed and fragment.position.is_equal_approx(player.position),"real 8x3 or last legal visual missing")
		player.health.invulnerable_time = 0; fragment.resolve_hit(0.09,0.10,player.position,player.position)
		check(not fragment.armed and player.health.current_health==76,"no-hold fragment retains damage/visual authority")
		for gap in [20.8,21.0]:
			reset(player); check(fragment.arm(boss,player,Vector2.ZERO,heading*220,{"attempted":false}),"round threshold birth")
			var at: Vector2 = heading*110+heading.orthogonal()*gap
			fragment.resolve_hit(0,0.045,at,at)
			check(player.health.current_health==(76 if gap<20.9 else 100),"actual radius4 plus ordinary body16.9 threshold")
	reset(player); player.position = Vector2(220,0)
	for at in [Vector2(110,90),Vector2(55,90)]:
		check(fragment.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"relative crossing birth")
		fragment.resolve_hit(0,0.045,Vector2(at.x,-90),at)
		check(player.health.current_health==(76 if at.x==55 else 100),"different-time crossing or simultaneous sweep")
		reset(player)
	check(fragment.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"lifetime tail birth")
	fragment.resolve_hit(0,0.05,Vector2(500,0),Vector2(500,0))
	fragment.resolve_hit(0.05,0.10,Vector2(500,0),player.position)
	check(fragment.armed and is_equal_approx(fragment.age,0.09) and player.health.current_health==100,"post-lifetime Player segment damages")
	fragment.resolve_hit(0.09,0.10,player.position,player.position); check(not fragment.armed,"expired fragment stays armed")
	var fragments: Array[RefCounted] = []; var shared := {"attempted":false}
	for index in range(9):
		var shard = load(SOURCE).new(); fragments.append(shard)
		check(shard.arm(boss,player,Vector2(0,index-4),player.position,shared),"nine bounded shared fragments")
	for shard in fragments:
		player.health.invulnerable_time = 0; shard.resolve_hit(0,0.045,player.position,player.position); shard.resolve_hit(0.045,0.09,player.position,player.position)
	check(player.health.current_health==76 and shared.attempted,"nine fragments repeat real damage without immunity")
	reset(player); shared = {"attempted":false}
	for shard in fragments: check(shard.arm(boss,player,Vector2.ZERO,player.position,shared),"immune shared rearm")
	player.health.invulnerable_time = 10; fragments[0].resolve_hit(0,0.045,player.position,player.position); fragments[0].resolve_hit(0.045,0.09,player.position,player.position)
	for shard in fragments.slice(1):
		player.health.invulnerable_time = 0; shard.resolve_hit(0,0.045,player.position,player.position); shard.resolve_hit(0.045,0.09,player.position,player.position)
	check(player.health.current_health==100 and shared.attempted,"rejected immune attempt repeats across nine")
	for layer in [1,Terrain.QUERY_LAYER]:
		var wall := obstacle(layer); host.add_child(wall); await physics_frame
		check(not fragment.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"thin wall ignored")
		wall.position.y = 150; await physics_frame
		check(fragment.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"moved clear wall rejected")
		wall.position.y = 0; await physics_frame; fragment.resolve_hit(0,0.045,player.position,player.position)
		check(not fragment.armed and player.health.current_health==100,"later wall does not cancel")
		wall.free(); await physics_frame
	for at in [Vector2.ZERO,Vector2(361,0),Vector2(INF,0),Vector2(NAN,0),Vector2(1e30,0)]:
		check(not fragment.arm(boss,player,Vector2.ZERO,at,{"attempted":false}),"invalid/range path admitted")
	check(not fragment.arm(boss,player,Vector2(997,0),Vector2(777,0),{"attempted":false}),"actual full birth circle outside bounds")
	for times in [[NAN,0.01],[0,INF],[-0.01,0.02],[0.03,0.02],[0,0.1]]:
		check(fragment.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"bad-time birth")
		fragment.resolve_hit(times[0],times[1],player.position,player.position); check(not fragment.armed,"illegal time keeps authority")
	check(fragment.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"pause birth")
	paused = true; fragment.resolve_hit(0,0.01,player.position,player.position); check(not fragment.armed,"pause keeps authority"); paused = false
	player.stealth_remaining = 1; check(not fragment.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"stealth birth admitted"); player.stealth_remaining = 0
	check(fragment.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false}),"Health reentry birth")
	shared = fragment.attempt; var rearmed := [false]
	var callback := func(_current,_maximum):
		player.health.invulnerable_time = 0
		rearmed[0] = fragment.arm(boss,player,Vector2.ZERO,player.position,{"attempted":false})
		fragment.resolve_hit(0.045,0.09,player.position,player.position)
		fragment.cancel()
	player.health.health_changed.connect(callback,CONNECT_ONE_SHOT)
	fragment.resolve_hit(0,0.045,player.position,player.position); fragment.resolve_hit(0.045,0.09,player.position,player.position)
	check(player.health.current_health==76 and shared.attempted and not rearmed[0] and not fragment.armed,"Health reentry rearms/repeats/retains")
	fragment.cancel(); fragment.cancel()
	for shard in fragments: shard.cancel()
	host.free(); await process_frame
	if not failures: print("TEST PASS: RiftObserverFragmentTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
