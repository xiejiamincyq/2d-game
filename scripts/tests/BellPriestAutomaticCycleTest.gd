extends SceneTree
## Controlled phase/clock routing. Immunity here is NOT ordinary dodge evidence.
const Boss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
class FramedPriest extends Boss:
	func get_combat_safe_rect() -> Rect2: return Rect2(-200,-200,400,400)
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BellPriestAutomaticCycleTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for phase in [1,2,3]:
		var host := Node2D.new(); root.add_child(host)
		var shots := Node2D.new(); host.add_child(shots)
		var player := Player.new(); player.position = Vector2(120,0); host.add_child(player); player.set_physics_process(false)
		player.health.begin_invulnerability(100) # Isolate routing from target death.
		var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(5,shots,player); host.add_child(boss); boss.set_physics_process(false)
		var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal()
		if phase>1: boss.take_damage(boss.health.max_health*(0.31 if phase==2 else 0.80)); combat.advance(0.65)
		if phase==3: combat.advance(0.65)
		check(combat.current_phase==phase and combat.get_state_name()=="PHASE_%d"%phase,"real Health does not reach requested phase")
		var seen: Array[StringName] = []; var serial: int = combat.action_serial
		for _step in 1600:
			combat.advance(1.0/120)
			for shot in shots.get_children():
				shot.set_physics_process(false)
				if not shot.is_queued_for_deletion(): shot._physics_process(1.0/120)
			if combat.action_serial!=serial:
				serial = combat.action_serial
				if combat.action_stage==combat.Stage.WARNING: seen.append(combat.action)
			if seen.size()>=3: break
		check(seen==[&"bell",&"pendant",&"crown"],"automatic finite three-action cycle absent in phase %s: %s"%[phase,seen])
		combat.cancel_action(); await process_frame
		check(shots.get_child_count()==0,"phase fixture cancellation leaves shot")
		host.free(); await process_frame
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := Player.new(); player.position = Vector2(600,0); host.add_child(player); player.set_physics_process(false)
	var boss := FramedPriest.new(); boss.position = Vector2(250,0); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(5,shots,player); host.add_child(boss); boss.set_physics_process(false)
	check(boss.get_combat_movement_direction(player).x<0,"priest abandons inherited camera-safe return")
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.advance(0.65)
	check(combat.action==&"pendant" and combat.is_attacking(),"out-of-range auto strike stalls ranged cycle")
	host.free(); await process_frame
	if not failures: print("TEST PASS: BellPriestAutomaticCycleTest %d"%checks)
	quit(1 if failures else 0)
