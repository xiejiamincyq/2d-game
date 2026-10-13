extends SceneTree
## Real unique combat clock + native Actor; controlled timing/lifecycle, not a run.
const Boss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BellPriestBellAttackTest "+label)
func _initialize() -> void: call_deferred("run")
func advance_warning(combat: Node,seconds: float = -1.0) -> void:
	var remaining: float = combat.DURATIONS[combat.action][0] if seconds<0 else seconds
	while remaining>0.0000001:
		var step := minf(1.0/120.0,remaining)
		combat.advance(step)
		remaining -= step

func run() -> void:
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := Player.new(); player.position = Vector2(120,0); host.add_child(player); player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000)
	boss.setup(5,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	check(combat.start_action(&"bell"),"real bell action cannot arm")
	if failures: host.free(); await process_frame; quit(1); return
	check(boss.should_show_attack_marker() and boss.get_visual_node().player.current_animation=="bell_warning","short native warning absent")
	var at: Vector2 = combat.locked_origin; var direction: Vector2 = combat.locked_direction
	check(at.is_equal_approx(boss.get_action_origin(&"bell",12)) and combat.strike.origin==at,"not actual bone socket/fixed world origin")
	advance_warning(combat,combat.DURATIONS[&"bell"][0]-0.001)
	check(player.health.current_health==100 and combat.action_stage==combat.Stage.WARNING,"warning inflicts damage")
	combat.advance(0.001)
	check(combat.action_stage==combat.Stage.ACTIVE and player.health.current_health==100 and not boss.should_show_attack_marker(),"instant damage before visible downstroke")
	combat.advance(0.079)
	check(player.health.current_health==100 and boss.get_visual_node().player.current_animation=="bell_attack","damage before physical active interval")
	combat.advance(0.001)
	check(player.health.current_health==64 and combat.strike.attempted and shots.get_child_count()==0,"bell lacks finite actual damage")
	player.health.invulnerable_time = 0; combat.advance(0.04)
	check(player.health.current_health==64,"same active capsule damages twice")
	check(combat.locked_origin==at and combat.locked_direction==direction,"strike world geometry retargets")
	combat.advance(0.3)
	check(combat.action_stage==combat.Stage.RECOVERY and not combat.strike.armed and boss.get_visual_node().player.current_animation=="bell_recovery","recovery retains damage/ignores bones")
	combat.advance(0.54)
	check(not combat.is_attacking() and not boss.should_show_attack_marker(),"finite strike never ends")
	check(not combat.start_action(&"unknown"),"unknown action silently admitted")
	check(combat.start_action(&"bell"),"pause fixture cannot arm")
	paused = true; await process_frame; await process_frame
	check(not combat.is_attacking() and not combat.strike.armed and not boss.should_show_attack_marker(),"pause retains danger/head cue")
	paused = false; combat.advance(0.01)
	check(combat.attack_gap>1,"resume lacks safe gap")
	check(combat.start_action(&"bell"),"target exit fixture cannot arm")
	host.remove_child(player)
	check(not combat.is_attacking() and not combat.strike.armed and boss.get_target_player()==null,"target departure retains danger/group fallback")
	player.free(); host.free(); await process_frame
	if not failures: print("TEST PASS: BellPriestBellAttackTest %d"%checks)
	quit(1 if failures else 0)
