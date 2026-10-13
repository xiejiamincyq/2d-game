extends SceneTree
## Finite two-beat contract; real health/terrain, explicit clock sampling only here.
const Layout = preload("res://scripts/world/EchoArenaLayout.gd")
const Health = preload("res://scripts/components/HealthComponent.gd")
class Target extends Node2D:
	var health: HealthComponent
	var hits: Array[float] = []
	var attempts := 0
	var immune := false
	var entrance := false
	var target_hidden := false
	func _ready() -> void: health = HealthComponent.new(); health.max_health = 100; add_child(health)
	func take_damage(amount: float,_source: StringName) -> bool:
		attempts += 1
		if immune: return false
		hits.append(amount); return health.damage(amount,true)
	func get_body_radius() -> float: return 16.9
	func is_entrance_active() -> bool: return entrance
	func is_stealthed() -> bool: return target_hidden
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoBeatTest "+label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func run() -> void:
	var path := "res://scripts/world/EchoBeat.gd"
	check(ResourceLoader.exists(path),"finite original two-beat hazard missing")
	if failures: quit(1); return
	var Beat = load(path)
	var host := Node2D.new(); host.position = Vector2(64,32); root.add_child(host)
	var layout = Layout.new(); host.add_child(layout); layout.generate_map(521)
	var target := Target.new(); host.add_child(target)
	var beat = Beat.new(); host.add_child(beat); beat.set_physics_process(false)
	var at: Vector2 = layout.get_echo_sites()[0]; target.global_position = layout.to_global(at)
	await tick(); beat.configure(layout,target,at,Vector2.RIGHT)
	check(not beat.enabled and beat.state==Beat.State.INACTIVE and not beat is CollisionObject2D and not beat.is_in_group(&"enemies"),"generation arms damage, movement wall or loot target")
	var centers: Array = beat.get_beat_centers(); centers.clear()
	check(beat.get_beat_centers().size()==2 and beat.get_beat_centers()[0].is_equal_approx(layout.to_global(at)) and beat.get_beat_centers()[1].distance_to(beat.get_beat_centers()[0])==48,"fixed translated offsets/getter contract")
	beat.set_enabled(true); check(beat.enabled and beat.remaining>=3.4,"arming lacks safe cooldown")
	beat.advance(3.4); check(beat.state==Beat.State.WARNING_FIRST and target.hits.is_empty(),"first warning skipped or damaging")
	var warning: float = beat.remaining
	for delta in [0.0,-1.0,NAN,INF]: beat.advance(delta)
	check(beat.remaining==warning and target.hits.is_empty(),"invalid delta advances clock or damage")
	beat.advance(0.4); check(beat.state==Beat.State.PULSE_FIRST and target.hits==[18.0],"first actual overlap does not attempt18 once")
	for _step in 10: beat.advance(0.001)
	check(target.hits==[18.0],"first pulse repeats damage")
	beat.advance(0.12); check(beat.state==Beat.State.WARNING_SECOND,"missing independently visible second warning")
	check(beat.get_current_center().is_equal_approx(beat.get_beat_centers()[1]),"second beat silently remains first location")
	target.global_position = beat.get_beat_centers()[1]
	beat.advance(0.4); check(beat.state==Beat.State.PULSE_SECOND and target.hits==[18.0],"one cycle retries immunity or damages twice")
	beat.advance(0.12); check(beat.state==Beat.State.COOLDOWN and beat.remaining>=3.4,"pair has no finite recovery")
	beat.advance(999); check(beat.state==Beat.State.WARNING_FIRST and beat.remaining==0.4,"stall erases real visible warning")
	beat.set_enabled(true); check(beat.state==Beat.State.WARNING_FIRST,"repeated encounter update resets clock")
	paused = true; beat.advance(0.01); check(beat.state==Beat.State.INACTIVE,"pause leaves pulse state")
	paused = false; beat.advance(0.01); check(beat.state==Beat.State.COOLDOWN and beat.remaining==3.4,"resume inherits instant danger")
	target.entrance = true; beat.advance(0.01); check(beat.state==Beat.State.INACTIVE,"entrance does not cancel")
	target.entrance = false; beat.advance(0.01); check(beat.remaining==3.4,"entrance restart not safe")
	beat.set_enabled(false); beat.advance(999); check(not beat.enabled and beat.state==Beat.State.INACTIVE,"owner disable retains attack")
	# A new cycle may hit only at the second fixed site, once; hidden targets consume no attempt.
	beat.set_enabled(true); target.global_position = beat.get_beat_centers()[1]
	beat.advance(3.4); beat.advance(0.4); check(target.hits.size()==1,"first disk incorrectly fills union of both beats")
	beat.advance(0.12); target.target_hidden = true; beat.advance(0.4); check(target.hits.size()==1,"hidden target receives danger")
	target.target_hidden = false; beat.advance(0.001); check(target.hits==[18.0,18.0],"second distinct footprint fails real overlap")
	beat.set_enabled(false); target.global_position = beat.get_beat_centers()[0]; target.immune = true
	beat.set_enabled(true); beat.advance(3.4); beat.advance(0.4)
	check(target.attempts==3 and target.hits.size()==2,"immune actual overlap not attempted exactly once")
	target.immune = false; target.global_position = beat.get_beat_centers()[1]
	beat.advance(0.12); beat.advance(0.4); check(target.attempts==3 and target.hits.size()==2,"same pair retries rejected immunity")
	beat.set_enabled(false); target.global_position = beat.get_beat_centers()[0]+Vector2(34,34)
	beat.set_enabled(true); beat.advance(3.4); beat.advance(0.4)
	check(target.attempts==3,"circle falsely uses expanded square at corner")
	target.global_position = beat.get_beat_centers()[0]+Vector2(33,33); beat.advance(0.001)
	check(target.attempts==4 and target.hits.size()==3,"late true circle-body overlap not resolved")
	target.health.damage(target.health.current_health,true)
	check(not beat.enabled and beat.state==Beat.State.INACTIVE,"health death callback retains active pulse")
	beat.bind_player(null); beat.set_enabled(true); check(not beat.enabled,"absent player can arm")
	var other := Target.new(); host.add_child(other); beat.bind_player(other); await tick(); beat.set_enabled(true)
	check(beat.enabled,"valid new live target cannot arm")
	beat.scale = Vector2(2,1); beat.advance(0.01); check(not beat.enabled,"scaled hazard invalidates physical footprint silently")
	beat.scale = Vector2.ONE; beat.set_enabled(true); host.remove_child(beat)
	check(not beat.enabled and beat.state==Beat.State.INACTIVE,"detached owner retains danger")
	beat.free(); host.free(); await process_frame
	if not failures: print("TEST PASS: EchoBeatTest %d"%checks)
	quit(1 if failures else 0)
