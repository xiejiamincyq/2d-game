extends SceneTree
## Production Actor + actual ownership/health callbacks. Not normal chapter play.
const Boss = preload("res://scripts/actors/ArchiveArchivistBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveBossPageLifecycleTest "+label)
func _initialize() -> void: call_deferred("run")
func fixture() -> Dictionary:
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var target := Player.new(); target.position = Vector2(500,0); host.add_child(target); target.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000)
	boss.setup(4,shots,target); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	return {"host":host,"shots":shots,"target":target,"boss":boss,"combat":combat}
func step(combat: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
func run() -> void:
	for mode in ["target-death","target-detach","target-queued","shots-detach","shots-queued","boss-detach","boss-death"]:
		var f := fixture(); var combat = f.combat
		check(combat.start_action(&"page"),"owner fixture cannot arm "+mode)
		step(combat,combat.DURATIONS[&"page"][0])
		check(f.shots.get_child_count()==1,"owner fixture must release exactly one real page "+mode)
		if f.shots.get_child_count()!=1:
			f.host.free(); await process_frame; quit(1); return
		var page = f.shots.get_child(0); page.set_physics_process(false)
		match mode:
			"target-death": f.target.health.damage(100,true)
			"target-detach": f.host.remove_child(f.target)
			"target-queued": f.target.queue_free(); step(combat,0.01)
			"shots-detach": f.host.remove_child(f.shots)
			"shots-queued": f.shots.queue_free(); step(combat,0.01)
			"boss-detach": f.host.remove_child(f.boss)
			"boss-death": f.boss.take_damage(f.boss.health.current_health+1)
		check(page.is_queued_for_deletion() and not page.visible and combat.owned_projectiles.is_empty(),"owner cancellation leaves active leaf "+mode)
		check(not combat.is_attacking() and not combat.start_action(&"page"),"owner cancellation restarts "+mode)
		if mode=="target-detach":
			var other := Player.new(); f.host.add_child(other)
			check(f.boss.get_target_player()==null,"departed target replaced with unrelated player group member")
		await process_frame
		for key in ["target","shots","boss"]:
			if is_instance_valid(f[key]) and not f[key].is_inside_tree(): f[key].free()
		f.host.free(); await process_frame
	var f := fixture(); var combat = f.combat
	# Phase two makes brood genuinely eligible, so its rejection below exercises
	# live-projectile exclusion rather than the unrelated first-phase brood gate.
	combat.set_health_phase(2); step(combat,combat.TRANSITION_SECONDS)
	check(combat.current_phase==2 and combat.start_action(&"page"),"single live leaf exclusion fixture cannot arm")
	step(combat,combat.DURATIONS[&"page"][0])
	check(f.shots.get_child_count()==1 and combat.owned_projectiles.size()==1,"single live leaf release absent")
	if f.shots.get_child_count()!=1:
		f.host.free(); await process_frame; quit(1); return
	var page = f.shots.get_child(0); page.set_physics_process(false)
	step(combat,combat.DURATIONS[&"page"][1]); step(combat,combat.DURATIONS[&"page"][2])
	check(not combat.is_attacking() and combat.action_stage==combat.Stage.IDLE,"normal page recovery fails to close independently of projectile")
	for kind in [&"page",&"seal",&"brood"]:
		check(not combat.start_action(kind) and combat.owned_projectiles==[page] and f.shots.get_child_count()==1 and not page.is_queued_for_deletion(),"live page permits overlapping action "+String(kind))
	page.cancel(); await process_frame
	check(f.shots.get_child_count()==0,"explicit page cancellation does not remove actual prior node")
	check(combat.start_action(&"page") and combat.owned_projectiles.is_empty(),"dead prior leaf reference permanently prevents fresh warning")
	step(combat,combat.DURATIONS[&"page"][0])
	check(f.shots.get_child_count()==1 and combat.owned_projectiles.size()==1,"fresh page release retains old owned references or duplicates projectile")
	combat.cancel_action(); await process_frame
	check(f.shots.get_child_count()==0 and combat.owned_projectiles.is_empty(),"explicit director cancellation leaves actual/owned page")
	f.host.free(); await process_frame
	# Preserve the original phase-two callback fixture, independently of the
	# phase-two exclusion checks above.
	f = fixture(); combat = f.combat
	var elapsed: float = combat.action_elapsed
	for delta in [-1.0,0.0,NAN,INF]: combat.advance(delta)
	check(not combat.is_attacking() and combat.action_elapsed==elapsed,"invalid delta starts/advances attack")
	combat.phase_changed.connect(func(phase: int):
		if phase==2: combat.shutdown())
	combat.set_health_phase(3); step(combat,0.65)
	check(combat.get_state_name()=="DEATH" and not combat.is_attacking(),"phase callback resurrects a terminal clock")
	f.host.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveBossPageLifecycleTest %d" % checks)
	quit(1 if failures else 0)
