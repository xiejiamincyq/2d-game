extends SceneTree
## Real native sockets/unique combat clock and birth callbacks, not normal play.
const Boss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BellPriestPendantAttackTest "+label)
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
	var player := Player.new(); player.position = Vector2(130,0); host.add_child(player); player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(5,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	check(combat.start_action(&"pendant"),"actual paired pendant cast absent")
	if failures: host.free(); await process_frame; quit(1); return
	var left: Vector2 = boss.get_action_origin(&"pendant_left",8); var right: Vector2 = boss.get_action_origin(&"pendant_right",8)
	var aimed_at := player.global_position
	check(combat.pendant_origins==[left,right] and boss.should_show_attack_marker() and boss.get_visual_node().player.current_animation=="pendant_warning","not actual left/right warning sockets")
	advance_warning(combat); combat.advance(0.099)
	check(shots.get_child_count()==0 and boss.get_visual_node().player.current_animation=="pendant_attack","pair born before visible outward gesture")
	player.position = Vector2(130,100); combat.advance(0.001)
	check(shots.get_child_count()==2 and combat.owned_projectiles.size()==2 and not boss.should_show_attack_marker(),"exact finite pair missing")
	for index in 2:
		var shot = shots.get_child(index); shot.set_physics_process(false)
		check(shot.origin==[left,right][index] and shot.global_position==shot.origin and shot.direction.is_equal_approx([left,right][index].direction_to(aimed_at)),"launch follows target/animated hand after locking")
	check(shots.get_child(0).hit_state==shots.get_child(1).hit_state,"pair damage ledger split")
	combat.advance(0.46); combat.advance(0.66)
	check(not combat.is_attacking() and shots.get_child_count()==2 and not combat.start_action(&"pendant"),"recovery duplicates pair or bypasses absolute quota")
	combat.cancel_action(); await process_frame
	check(shots.get_child_count()==0 and combat.owned_projectiles.is_empty(),"explicit cancellation leaves pendants")
	check(combat.start_action(&"pendant"),"reentrant birth fixture cannot arm")
	shots.child_entered_tree.connect(func(_node): combat.shutdown(),CONNECT_ONE_SHOT)
	advance_warning(combat); combat.advance(0.1)
	check(combat.get_state_name()=="DEATH" and combat.owned_projectiles.is_empty(),"child-entered callback appends late pendant")
	await process_frame; check(shots.get_child_count()==0,"reentrant partial pair survives")
	host.free(); await process_frame
	if not failures: print("TEST PASS: BellPriestPendantAttackTest %d"%checks)
	quit(1 if failures else 0)
