extends SceneTree
## Actual Actor/Player/terrain; controlled clock, not a chapter victory.
const Boss = preload("res://scripts/actors/ArchiveArchivistBoss.gd")
class CountedPlayer extends "res://scripts/actors/Player.gd":
	var attempts: Array = []
	func take_damage(amount: float,source: StringName = &"generic") -> bool:
		attempts.append([amount,source]); return super.take_damage(amount,source)
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveBossSealTest "+label)
func _initialize() -> void: call_deferred("run")
func fixture() -> Dictionary:
	var host := Node2D.new(); host.z_index = 7; root.add_child(host)
	var shots := Node2D.new(); shots.z_index = 50; host.add_child(shots)
	var target := CountedPlayer.new(); target.position = Vector2(240,0); host.add_child(target); target.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-600,-600,1200,1200)
	boss.setup(4,shots,target); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	return {"host":host,"shots":shots,"target":target,"boss":boss,"combat":combat}
func wall(host: Node2D,at: Vector2,size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new(); body.position = at
	var collider := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = size
	collider.shape = shape; body.add_child(collider); host.add_child(body); return body
func step(combat: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
func run() -> void:
	var f := fixture(); var combat = f.combat
	check(combat.start_action(&"seal"),"actual independent seal action unavailable")
	if failures: f.host.free(); await process_frame; quit(1); return
	check(combat is Node2D and not combat.z_as_relative and combat.z_index==-1,"seal ground follows parent foreground z")
	var seal = combat.seal_attack
	check(seal.centers.size()==2 and is_equal_approx(seal.centers[0].distance_to(seal.centers[1]),72),"two locked finite small seal centers absent")
	check(f.boss.should_show_attack_marker() and f.boss.get_visual_node().player.current_animation=="seal_warning","native short seal warning/head absent")
	var centers = seal.centers.duplicate()
	step(combat,combat.DURATIONS[&"seal"][0]-0.001)
	check(f.target.attempts.is_empty() and f.target.health.current_health==100,"seal damages before configured warning")
	step(combat,0.001)
	check(f.target.health.current_health==82 and f.target.attempts==[[18.0,&"archive_seal"]],"seal misses actual 16.9-radius player or double hits overlapping spots")
	check(combat.action_stage==combat.Stage.ACTIVE and f.boss.get_visual_node().player.current_animation=="seal_attack" and not f.boss.should_show_attack_marker(),"native active stage mismatch")
	step(combat,0.10); step(combat,0.18)
	check(f.target.attempts.size()==1 and seal.centers.is_empty() and combat.action_stage==combat.Stage.RECOVERY,"finite seal persists/retries after active phase")
	step(combat,0.64)
	check(not combat.is_attacking(),"seal recovery never ends")
	check(combat.start_action(&"seal"),"second seal cannot arm")
	f.target.position += Vector2(100,0)
	check(seal.centers==centers,"seal follows moving player after warning")
	step(combat,combat.DURATIONS[&"seal"][0]); step(combat,0.10)
	check(f.target.attempts.size()==1,"locked spots chase target")
	combat.cancel_action()
	check(seal.centers.is_empty() and not f.boss.should_show_attack_marker(),"cancel leaves ground/head")
	f.host.free(); await process_frame
	# Real 2px terrain blocks birth rays; footprint checks also reject inside walls.
	f = fixture(); combat = f.combat
	var barrier := wall(f.host,Vector2(120,-50),Vector2(2,300))
	await physics_frame; await physics_frame
	check(not combat.start_action(&"seal") and combat.seal_attack.centers.is_empty(),"seal births beyond thin wall")
	barrier.free(); await physics_frame; await physics_frame
	barrier = wall(f.host,Vector2(240,-36),Vector2(6,6))
	await physics_frame; await physics_frame
	check(not combat.start_action(&"seal") and combat.seal_attack.centers.is_empty(),"partial cast hides an obstructed footprint")
	barrier.free(); await physics_frame; await physics_frame
	f.target.position = Vector2(240,570)
	check(not combat.start_action(&"seal"),"whole seal footprint escapes world bounds")
	f.host.free(); await process_frame
	for mode in ["pause","stealth","target-death","target-detach","shots-detach","boss-death"]:
		f = fixture(); combat = f.combat
		check(combat.start_action(&"seal"),"cancel fixture cannot arm "+mode)
		match mode:
			"pause": paused = true; await process_frame; await process_frame; paused = false
			"stealth": combat.set_target_hidden(true)
			"target-death": f.target.health.damage(100,true)
			"target-detach": f.host.remove_child(f.target)
			"shots-detach": f.host.remove_child(f.shots)
			"boss-death": f.boss.take_damage(f.boss.health.current_health+1)
		check(not combat.is_attacking() and combat.seal_attack.centers.is_empty(),"cancelled seal survives "+mode)
		await process_frame
		for key in ["target","shots"]:
			if is_instance_valid(f[key]) and not f[key].is_inside_tree(): f[key].free()
		f.host.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveBossSealTest %d" % checks)
	quit(1 if failures else 0)
