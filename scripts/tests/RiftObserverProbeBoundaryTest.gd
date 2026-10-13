extends SceneTree
## Controlled geometry with real physical Owner/Player/Health, not natural play.
## A 235 px/s Player travels 14.1 px in the legal 0.10 -> 0.16 sample.
## Probe reaches its landing at 0.12: relative motion has TWO timed segments.
const Probe = preload("res://scripts/components/RiftObserverProbe.gd")
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const BEFORE := 0.10
const AFTER := 0.16
const FLIGHT_END := 0.12
const LANDING := Vector2(220,0)
const CONTACT_RADIUS := 22.9 # Actual Player 16.9 + actual probe 6; neither buffed.
var checks := 0
var failures := 0

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: RiftObserverProbeBoundaryTest "+label)

func segment_distance(first: Vector2,last: Vector2) -> float:
	# Independent analytic minimization of |first + u*(last-first)|, 0 <= u <= 1.
	# Do not call the production sweep or Geometry2D's closest-point implementation.
	var travel := last-first
	var squared := travel.length_squared()
	var fraction := clampf(-first.dot(travel)/squared,0,1) if squared>0 else 0.0
	return (first+travel*fraction).length()

func boundary_case(player: CharacterBody2D,boss: CharacterBody2D,label: String,previous: Vector2,current: Vector2,expected_hit: bool,expected_split: float,expected_chord: float) -> void:
	player.health.current_health = 100
	player.health.invulnerable_time = 0
	player.global_position = previous
	var probe := Probe.new()
	var ledger := {"attempted":false}
	check(probe.arm(boss,player,Vector2.ZERO,LANDING,ledger),label+" actual physical fixture arms")
	if not probe.armed:
		probe.cancel()
		return
	# Pre-advance the actual primitive clock, rather than jumping from age 0 to 0.10.
	# Player remains stationary only in these fixture setup segments.
	probe.resolve_hit(0,0.05,previous,previous)
	probe.resolve_hit(0.05,BEFORE,previous,previous)
	check(probe.armed and is_equal_approx(probe.age,BEFORE),label+" local clock pre-advanced")
	check(player.health.current_health==100 and not ledger.attempted,label+" no setup damage")
	check(is_equal_approx(previous.distance_to(current)/(AFTER-BEFORE),235),label+" ordinary movement speed")
	check(AFTER-BEFORE<=1.0/15.0,label+" legal sample interval")
	# Probe moves (183.3333,0) -> (220,0) during the first 0.02 s, then holds.
	# Player's LINEAR frame path reaches 1/3 of its displacement at that boundary.
	var player_at_landing := previous.lerp(current,(FLIGHT_END-BEFORE)/(AFTER-BEFORE))
	var relative_first := LANDING*(BEFORE/FLIGHT_END)-previous
	var relative_corner := LANDING-player_at_landing
	var relative_last := LANDING-current
	var split_distance := minf(segment_distance(relative_first,relative_corner),segment_distance(relative_corner,relative_last))
	var chord_distance := segment_distance(relative_first,relative_last)
	check(absf(split_distance-expected_split)<0.001,label+" independently derived two-segment distance")
	check(absf(chord_distance-expected_chord)<0.001,label+" independently derived chord distance")
	check((split_distance<=CONTACT_RADIUS)==expected_hit,label+" analytic contract outcome")
	check((chord_distance<=CONTACT_RADIUS)!=expected_hit,label+" fixture distinguishes collapsed chord")
	print("BOUNDARY GEOMETRY: %s split=%.6f chord=%.6f radius=%.1f expected_hit=%s"%[label,split_distance,chord_distance,CONTACT_RADIUS,expected_hit])
	var damage_events := [0]
	var on_damage := func(_current: float,_maximum: float) -> void: damage_events[0] += 1
	player.health.health_changed.connect(on_damage)
	player.global_position = current
	probe.resolve_hit(BEFORE,AFTER,previous,current)
	var expected_health := 73 if expected_hit else 100
	check(player.health.current_health==expected_health,label+" Health expected %d, actual %s"%[expected_health,player.health.current_health])
	check(ledger.attempted==expected_hit,label+" pair ledger matches true trajectory")
	check(damage_events[0]==(1 if expected_hit else 0),label+" exactly one or zero actual Health events")
	check(probe.armed and is_equal_approx(probe.age,AFTER) and probe.position.is_equal_approx(LANDING),label+" survives at actual landing")
	# Remove immunity only after the asserted sample, to test the once-only ledger.
	# Both chosen final positions are outside the contact radius during the hold.
	player.health.invulnerable_time = 0
	probe.resolve_hit(AFTER,0.20,current,current)
	check(player.health.current_health==expected_health and damage_events[0]==(1 if expected_hit else 0),label+" remaining hold never repeats damage")
	check(probe.armed and probe.position.is_equal_approx(LANDING),label+" last legal footprint retained")
	probe.resolve_hit(0.20,0.21,current,current)
	check(not probe.armed,label+" expires next tick")
	player.health.health_changed.disconnect(on_damage)
	probe.cancel()

func run() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var shots := Node2D.new()
	host.add_child(shots)
	var player := PlayerScript.new()
	player.position = Vector2(220,16)
	host.add_child(player)
	player.set_physics_process(false) # Controlled frame endpoints, not natural movement.
	var boss := Boss.new()
	boss.world_bounds = Rect2(-1000,-1000,2000,2000)
	boss.setup(6,shots,player)
	host.add_child(boss)
	boss.set_physics_process(false)
	var combat = boss.get_attack_director()
	combat.advance(1.4)
	boss._update_entrance_reveal()
	combat.attack_gap = 99
	await physics_frame
	check(boss.entrance_resolved and not boss.death_resolved and boss.health.current_health>0,"actual living entered Owner")
	check(player.health.max_health==100 and player.health.current_health==100 and player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9),"unmodified normal Player statistics")
	check(player.shield==0 and not player.is_stealthed() and not player.is_damage_immune(),"normal Player accepts actual damage")
	check(player.player_collision.shape is CircleShape2D and is_equal_approx(player.player_collision.shape.radius,16.9) and not player.player_collision.disabled,"actual normal circular collision remains enabled")
	check(Probe.RADIUS==6 and is_equal_approx(Probe.FLIGHT_SECONDS,FLIGHT_END) and is_equal_approx(Probe.LIFE_SECONDS,0.20),"actual primitive flight and hold contract")
	# False negative: relative (-36.6667,-16) -> (0,-20.7) -> (0,-30.1).
	# True closest distance 20.532011 < 22.9; collapsed chord 28.094361 > 22.9.
	boundary_case(player,boss,"flight_hold_false_negative",Vector2(220,16),Vector2(220,30.1),true,20.532011,28.094361)
	# False positive: relative (-16.6667,-30) -> (20,-25.3) -> (20,-15.9).
	# True closest distance 25.550147 > 22.9; collapsed chord 22.018987 < 22.9.
	boundary_case(player,boss,"flight_hold_false_positive",Vector2(200,30),Vector2(200,15.9),false,25.550147,22.018987)
	host.free()
	await process_frame
	if failures==0 and checks>0:
		print("TEST PASS: RiftObserverProbeBoundaryTest %d"%checks)
	quit(1 if failures>0 or checks<=0 else 0)

func _initialize() -> void:
	call_deferred("run")
