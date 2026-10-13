extends SceneTree
## Shared finite flight contract with actual Owner/Player/Health, not a victory.
const SOURCE := "res://scripts/components/RiftObserverCircleFlight.gd"
const Probe = preload("res://scripts/components/RiftObserverProbe.gd")
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
class MutableProbe extends Probe:
	var configured_radius := 6.0
	var configured_flight := 0.12
	var configured_life := 0.20
	var configured_damage := 27.0
	func _get_radius() -> float: return configured_radius
	func _get_flight_seconds() -> float: return configured_flight
	func _get_life_seconds() -> float: return configured_life
	func _get_damage() -> float: return configured_damage
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverCircleFlightTest "+label)
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"actual shared finite flight kernel missing")
	if failures: quit(1); return
	var kernel: Script = load(SOURCE)
	var actual_probe := Probe.new()
	check(actual_probe.get_script().get_base_script()==kernel,"Probe does not use the canonical finite kernel")
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := PlayerScript.new(); player.position = Vector2(220,0); host.add_child(player); player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(6,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	await physics_frame
	check(player.health.current_health==100 and player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9),"actual normal Player altered")
	var unconfigured: RefCounted = kernel.new()
	check(not unconfigured.arm(boss,player,Vector2.ZERO,Vector2(220,0),{"attempted":false}),"unconfigured kernel accidentally armed")
	var probe := MutableProbe.new(); var ledger := {"attempted":false}
	check(probe.arm(boss,player,Vector2.ZERO,Vector2(220,0),ledger),"actual configured Probe cannot arm")
	probe.configured_radius = 40; probe.configured_flight = 1; probe.configured_life = 4; probe.configured_damage = 999
	probe.resolve_hit(0,0.06,Vector2(110,23),Vector2(110,23))
	check(probe.position.is_equal_approx(Vector2(110,0)) and is_equal_approx(probe.age,0.06),"armed flight speed silently changes")
	check(player.health.current_health==100 and not ledger.attempted and probe.query.shape.radius==6,"armed radius or real capsule changes")
	probe.resolve_hit(0.06,0.12,Vector2(220,0),Vector2(220,0))
	check(player.health.current_health==73 and ledger.attempted and probe.position==Vector2(220,0),"armed damage or landing changes")
	player.health.invulnerable_time = 0; probe.resolve_hit(0.12,0.16,Vector2(220,0),Vector2(220,0)); probe.resolve_hit(0.16,0.20,Vector2(220,0),Vector2(220,0))
	check(player.health.current_health==73 and probe.armed,"last legal footprint or once-only attempt changed")
	probe.resolve_hit(0.20,0.21,Vector2(220,0),Vector2(220,0))
	check(not probe.armed and player.health.current_health==73,"armed lifetime silently changes")
	for invalid in [0.0,-1.0,NAN,INF]:
		probe.configured_radius = invalid; probe.configured_flight = 0.12; probe.configured_life = 0.20; probe.configured_damage = 27
		check(not probe.arm(boss,player,Vector2.ZERO,Vector2(220,0),{"attempted":false}),"invalid radius accepted")
	probe.configured_radius = 6; probe.configured_flight = 0; check(not probe.arm(boss,player,Vector2.ZERO,Vector2(220,0),{"attempted":false}),"zero flight accepted")
	probe.configured_flight = 0.12; probe.configured_life = 0.10; check(not probe.arm(boss,player,Vector2.ZERO,Vector2(220,0),{"attempted":false}),"life shorter than flight accepted")
	probe.configured_life = 0.20
	for invalid in [0.0,-1.0,NAN,INF]:
		probe.configured_damage = invalid; check(not probe.arm(boss,player,Vector2.ZERO,Vector2(220,0),{"attempted":false}),"invalid damage accepted")
	probe.cancel(); unconfigured.cancel(); host.free(); await process_frame
	if not failures: print("TEST PASS: RiftObserverCircleFlightTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
