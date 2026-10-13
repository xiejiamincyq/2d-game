extends SceneTree
## Unique clock/real crown warning socket, bounded notes and callback cancellation.
const Boss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BellPriestCrownAttackTest "+label)
func _initialize() -> void: call_deferred("run")
func advance_warning(combat: Node,seconds: float = -1.0) -> void:
	var remaining: float = combat.DURATIONS[combat.action][0] if seconds<0 else seconds
	while remaining>0.0000001:
		var step := minf(1.0/120.0,remaining)
		combat.advance(step)
		remaining -= step

func run() -> void:
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); shots.position = Vector2(50,60); host.add_child(shots)
	var player := Player.new(); player.position = Vector2(180,0); host.add_child(player); player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(5,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	check(combat.start_action(&"crown"),"actual crown cast absent")
	if failures: host.free(); await process_frame; quit(1); return
	var origin: Vector2 = combat.locked_origin; var heading: Vector2 = combat.locked_direction
	check(origin==boss.get_action_origin(&"crown",4) and boss.should_show_attack_marker() and boss.get_visual_node().player.current_animation=="crown_warning","not actual warning-time crown socket")
	advance_warning(combat); combat.advance(0.079)
	check(shots.get_child_count()==0 and boss.get_visual_node().player.current_animation=="crown_attack","note emitted before visible gesture")
	player.position = Vector2(180,100)
	for interval in [0.001,0.15,0.15]:
		combat.advance(interval)
		for shot in shots.get_children(): shot.set_physics_process(false)
	check(shots.get_child_count()==6 and combat.owned_projectiles.size()==6 and combat.crown_notes==3,"not exactly three finite pairs")
	for shot in shots.get_children():
		check(shot.global_position==origin and shot.velocity.normalized().dot(heading)>0.97 and shot.source_actor.get_ref()==boss,"note follows moving crown/target or lacks actual source")
	combat.advance(0.10); combat.advance(0.6)
	check(not combat.is_attacking() and shots.get_child_count()==6 and not combat.start_action(&"crown"),"recovery duplicates/absolute crown quota bypassed")
	combat.cancel_action(); await process_frame
	check(shots.get_child_count()==0,"explicit cancel leaves notes")
	check(combat.start_action(&"crown"),"hitch fixture cannot arm")
	advance_warning(combat); combat.advance(5)
	for shot in shots.get_children(): shot.set_physics_process(false)
	check(shots.get_child_count()==2 and combat.crown_notes==1,"hitch catches up invisible multi-note burst")
	combat.cancel_action(); await process_frame
	check(combat.start_action(&"crown"),"reentrant fixture cannot arm")
	shots.child_entered_tree.connect(func(_node): combat.shutdown(),CONNECT_ONE_SHOT)
	advance_warning(combat); combat.advance(0.08)
	check(combat.get_state_name()=="DEATH" and combat.owned_projectiles.is_empty(),"late crown appended after birth callback shuts down")
	await process_frame; check(shots.get_child_count()==0,"reentrant partial note survives")
	host.free(); await process_frame
	if not failures: print("TEST PASS: BellPriestCrownAttackTest %d"%checks)
	quit(1 if failures else 0)
