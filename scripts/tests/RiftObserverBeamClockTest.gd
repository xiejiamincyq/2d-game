extends SceneTree
## Real Observer Actor and unique director; controlled time, not a chapter victory.
const SOURCE := "res://scripts/actors/RiftObserverBoss.gd"
const PlayerScript = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverBeamClockTest "+label)
func step(combat: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"actual native Observer Actor/clock missing")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := PlayerScript.new(); player.position = Vector2(240,0); host.add_child(player); player.set_physics_process(false)
	var boss = load(SOURCE).new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000)
	boss.setup(6,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director()
	check(not combat.start_action(&"beam") and not boss.entrance_resolved,"attack bypasses actual entrance")
	combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	check(boss.get_visual_node().scene_file_path=="res://scenes/actors/native/rift_observer_paper_v2.tscn" and boss.get_visual_node().skeleton.get_bone_count()==30,"native Observer replaced by old Boss")
	check(boss.body_radius==56 and boss.health.max_health==10800 and boss.scale==Vector2.ONE and boss.rotation==0,"physical Boss contract changed")
	check(not combat.start_action(&"unknown"),"unknown attacks silently admitted")
	check(combat.start_action(&"refract"),"verified refract unavailable"); combat.cancel_action()
	check(combat.start_action(&"beam"),"actual beam cannot start")
	if failures: host.free(); await process_frame; quit(1); return
	var root_at: Transform2D = boss.global_transform
	var direction: Vector2 = combat.locked_direction
	check(boss.should_show_attack_marker() and not combat.beam.armed and boss.get_visual_node().player.current_animation=="beam_warning","warning has damage authority or wrong pose")
	step(combat,combat.DURATIONS[&"beam"][0]-0.001)
	check(player.health.current_health==100 and combat.action_stage==combat.Stage.WARNING,"warning damage")
	step(combat,0.001)
	check(combat.action_stage==combat.Stage.ACTIVE and player.health.current_health==100 and not boss.should_show_attack_marker(),"active release inflicts previsible damage")
	var origin: Vector2 = combat.locked_origin
	check(combat.beam.armed and origin.is_equal_approx(boss.get_action_origin(&"beam",8)) and combat.beam.origin==origin,"not current true Pupil socket at release")
	check(combat.locked_direction==direction and boss.get_visual_node().player.current_animation=="beam_attack","release retargets or does not show action")
	step(combat,0.008)
	check(player.health.current_health==64 and combat.beam.attempted,"visible beam misses stationary target")
	player.health.invulnerable_time = 0; step(combat,0.10)
	check(player.health.current_health==64 and combat.locked_origin==origin and combat.locked_direction==direction and boss.global_transform==root_at,"beam repeats/tracks or native motion moves physical root")
	step(combat,0.012)
	check(combat.action_stage==combat.Stage.ACTIVE and combat.beam.armed,"active closing frame erases footprint before rendering")
	step(combat,1.0/120)
	check(combat.action_stage==combat.Stage.RECOVERY and not combat.beam.armed and boss.get_visual_node().player.current_animation=="beam_recovery","recovery damage authority")
	step(combat,0.45)
	check(not combat.is_attacking() and not boss.should_show_attack_marker(),"finite action never finishes")
	player.health.current_health = 100; player.health.invulnerable_time = 0
	check(combat.start_action(&"beam"),"last-active-frame crossing fixture")
	var side: Vector2 = combat.locked_direction.orthogonal()
	player.position = combat.locked_origin+combat.locked_direction*220+side*80
	step(combat,combat.DURATIONS[&"beam"][0]); step(combat,0.10)
	check(player.health.current_health==100,"off-axis control hit before last-frame crossing")
	player.position = combat.locked_origin+combat.locked_direction*220; combat.advance(0.02)
	check(player.health.current_health==64 and combat.action_stage==combat.Stage.ACTIVE and combat.beam.armed,"last legal active crossing damages without retained visible beam")
	player.health.invulnerable_time = 0; combat.advance(1.0/120)
	check(player.health.current_health==64 and combat.action_stage==combat.Stage.RECOVERY and not combat.beam.armed,"closed active frame retries or never releases")
	step(combat,0.45)
	for dt in [NAN,INF,-1.0,0.0]:
		var elapsed: float = combat.state_elapsed; combat.advance(dt); check(combat.state_elapsed==elapsed,"invalid delta progresses")
	player.health.current_health = 100; player.health.invulnerable_time = 0
	check(combat.start_action(&"beam"),"hitch fixture")
	step(combat,combat.DURATIONS[&"beam"][0]); combat.advance(0.1)
	check(not combat.is_attacking() and not combat.beam.armed and player.health.current_health==100 and combat.attack_gap>=1.1,"hitch catches up damage")
	check(combat.start_action(&"beam"),"pause fixture")
	paused = true; await process_frame; await process_frame
	check(not combat.is_attacking() and not combat.beam.armed and not boss.should_show_attack_marker(),"pause retains attack")
	paused = false; combat.advance(0.01); check(combat.attack_gap>1,"resume safe interval absent")
	check(combat.start_action(&"beam"),"target-departure fixture")
	host.remove_child(player)
	check(not combat.is_attacking() and not combat.beam.armed and boss.get_target_player()==null,"target departure retargets fallback")
	host.add_child(player); combat.target_hidden = false
	check(combat.start_action(&"beam"),"container departure fixture")
	host.remove_child(shots)
	check(combat.get_state_name()=="DEATH" and not combat.is_attacking() and not combat.beam.armed,"container departure retains authority")
	shots.free(); host.free(); await process_frame
	if not failures: print("TEST PASS: RiftObserverBeamClockTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
