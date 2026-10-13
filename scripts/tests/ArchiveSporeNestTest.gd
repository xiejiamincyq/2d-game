extends SceneTree
## Manual clock/state checks; normal Player motion/shooting are separate gates.
const Layout = preload("res://scripts/world/ArchiveArenaLayout.gd")
var checks := 0
var failures := 0
class Target extends Node2D:
	var health = preload("res://scripts/components/HealthComponent.gd").new()
	var hits := 0
	var attempts := 0
	var immune := false
	var entering := false
	func _init() -> void: health.max_health = 1000; add_child(health)
	func is_alive() -> bool: return health.current_health>0
	func is_entrance_active() -> bool: return entering
	func get_body_radius() -> float: return 13.0
	func take_damage(amount: float,source: StringName) -> bool:
		attempts += 1
		if immune or source!=&"archive_spore": return false
		hits += 1; return health.damage(amount,true)
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveSporeNestTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scripts/world/ArchiveSporeNest.gd"
	check(ResourceLoader.exists(path),"destructible archive nest missing")
	if failures: quit(1); return
	var layout := Layout.new(); root.add_child(layout); layout.generate_map(521)
	var target := Target.new(); root.add_child(target); target.position = layout.get_spore_sites()[0]
	var nest = load(path).new(); root.add_child(nest); nest.set_physics_process(false)
	nest.configure(layout,target,target.position); await physics_frame; await process_frame
	check(not nest.enabled and nest.state==nest.State.INACTIVE and not nest.is_in_group(&"enemies"),"defaults must be harmless/untargetable")
	check(not nest.take_damage(100) and nest.health.current_health==36,"inactive nest accepts damage")
	nest.set_enabled(true); nest.advance(nest.COOLDOWN_TIME-0.001)
	check(nest.state==nest.State.COOLDOWN and target.hits==0 and nest.is_in_group(&"enemies"),"initial safe/targetable cooldown")
	nest.advance(0.002)
	check(nest.state==nest.State.WARNING and target.hits==0,"warning harmless")
	check(nest.WARNING_TIME==0.45 and nest.RADIUS==34,"verified escape budget changed without review")
	nest.advance(nest.WARNING_TIME-0.001); check(nest.state==nest.State.WARNING,"full warning erased")
	nest.advance(0.002); check(nest.state==nest.State.ACTIVE and target.hits==1 and target.health.current_health==982,"single damage18 missing")
	nest.advance(0.2); nest.set_enabled(true); nest.advance(0.2)
	check(target.attempts==1,"repeat/reentry retries damage")
	nest.advance(nest.ACTIVE_TIME); nest.advance(100)
	check(nest.state==nest.State.WARNING and target.hits==1,"stall skips warning")
	target.immune = true; nest.advance(nest.WARNING_TIME); target.immune = false; nest.advance(0.01)
	check(target.attempts==2 and target.hits==1,"immunity causes repeated attempt")
	paused = true; nest.advance(10)
	check(nest.state==nest.State.INACTIVE and not nest.is_in_group(&"enemies"),"pause leaves attack/targetability")
	paused = false; nest.advance(0.01)
	check(nest.state==nest.State.COOLDOWN and nest.remaining==nest.COOLDOWN_TIME,"resume lacks full recovery")
	target.entering = true; nest.advance(10)
	check(nest.state==nest.State.INACTIVE and not nest.take_damage(1),"entrance leaves attack/damage target")
	target.entering = false; nest.advance(0.01); nest.advance(nest.COOLDOWN_TIME)
	check(not nest.take_damage(-1) and not nest.take_damage(NAN) and nest.health.current_health==36,"invalid damage accepted")
	check(not nest.take_damage(12) and nest.health.current_health==24,"partial damage wrong")
	check(nest.take_damage(24) and nest.state==nest.State.BROKEN and not nest.is_in_group(&"enemies"),"fatal shot does not suppress nest")
	nest.set_enabled(true); nest.advance(100)
	check(nest.state==nest.State.BROKEN and nest.health.current_health==0 and target.hits==1,"idempotent enable revives destroyed nest")
	nest.set_enabled(false); nest.set_enabled(true)
	check(nest.state==nest.State.COOLDOWN and nest.health.current_health==36,"new encounter cannot restore nest")
	nest.advance(INF); nest.advance(NAN); nest.advance(-1)
	check(nest.remaining==nest.COOLDOWN_TIME,"invalid time corrupts clock")
	target.position += Vector2(48,0); nest.advance(nest.COOLDOWN_TIME); nest.advance(nest.WARNING_TIME)
	check(target.hits==1,"outside genuine body overlap damaged")
	target.position -= Vector2(2,0); nest.advance(0.01)
	check(target.hits==2,"late actual body overlap not damaged")
	target.health.damage(target.health.current_health,true)
	check(not nest.enabled and nest.state==nest.State.INACTIVE,"actual health death not synchronous cancel")
	var fresh := Target.new(); root.add_child(fresh); fresh.position = nest.position
	nest.bind_player(fresh); nest.set_enabled(true); root.remove_child(fresh)
	check(not nest.enabled,"target detach not immediate cancel"); fresh.free()
	var other := Target.new(); root.add_child(other)
	for point in [Vector2.ZERO,layout.BOSS_CENTER,layout.world_bounds.end-Vector2.ONE,layout.get_obstacle_descriptors()[0].rect.get_center()]:
		nest.configure(layout,other,point); nest.set_enabled(true); check(not nest.enabled,"unsafe spawn/Boss/boundary/shelf site armed")
	nest.configure(layout,other,layout.get_spore_sites()[0]); nest.set_enabled(true)
	root.remove_child(layout); check(not nest.enabled,"terrain detach not synchronous cancel")
	layout.free(); nest.free(); target.free(); other.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveSporeNestTest %d"%checks)
	quit(1 if failures else 0)
