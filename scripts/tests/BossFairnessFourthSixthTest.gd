extends SceneTree
## Real actors and normal input after 0.25 s. No dash, stat edits, victory or save.
const Archivist = preload("res://scripts/actors/ArchiveArchivistBoss.gd")
const Observer = preload("res://scripts/actors/RiftObserverBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
const REACTION_SECONDS := 0.25
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: BossFairnessFourthSixthTest " + label)
func release_inputs() -> void:
	for action in ["move_up","move_down","move_left","move_right","fire","dash_melee"]: Input.action_release(action)
func fixture(chapter: int, at: Vector2) -> Dictionary:
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := Player.new(); player.position = at
	player.world_bounds = Rect2(-1000,-1000,2000,2000); host.add_child(player)
	var boss = Archivist.new() if chapter==4 else Observer.new()
	boss.world_bounds = player.world_bounds; boss.setup(chapter,shots,player); host.add_child(boss)
	var combat = boss.get_attack_director()
	combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	return {"host":host,"shots":shots,"player":player,"boss":boss,"combat":combat}
func natural_dodge(chapter: int, kind: StringName, at: Vector2, input: String, rate: int) -> void:
	release_inputs()
	var f := fixture(chapter,at); var combat = f.combat
	check(f.player.health.current_health==100 and f.player.shield==0 and f.player.move_speed==235 and is_equal_approx(f.player.get_body_radius(),16.9),"normal player properties changed")
	check(combat.start_action(kind),"cannot arm isolated action %s/%s" % [chapter,kind])
	var locked: Vector2 = combat.locked_direction
	var elapsed := 0.0; var started := false; var moves := 0
	var previous: Vector2 = f.player.global_position
	var deadline := Time.get_ticks_msec()+4000
	while (combat.is_attacking() or f.shots.get_child_count()>0) and Time.get_ticks_msec()<deadline:
		await physics_frame
		elapsed += 1.0/rate
		if not started and elapsed>=REACTION_SECONDS:
			Input.action_press(input); started = true
		if f.player.global_position.distance_squared_to(previous)>0.01: moves += 1
		previous = f.player.global_position
		check(combat.locked_direction==locked,"direction tracks player after warning %s/%s" % [chapter,kind])
	release_inputs()
	check(Time.get_ticks_msec()<deadline,"action exceeds deadline")
	check(started and moves>=4,"ordinary delayed input never moves")
	check(f.player.health.current_health==100,"0.25s reaction ordinary dodge fails chapter%s/%s/%sHz HP%s" % [chapter,kind,rate,f.player.health.current_health])
	check(not f.player.dash_active and not f.player.is_stealthed() and not f.player.player_collision.disabled,"dodge bypasses ordinary physical body")
	print("FAIRNESS DELAYED DODGE: chapter%s %s at%s %sHz reaction>=0.25 moves%s HP%s" % [chapter,kind,at,rate,moves,f.player.health.current_health])
	f.host.free(); await process_frame
func wall(host: Node2D, at: Vector2) -> void:
	var body := StaticBody2D.new(); body.position = at; body.collision_layer = 1|2
	var shape := CollisionShape2D.new(); var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2000,40); shape.shape = rectangle; body.add_child(shape); host.add_child(body)
func sealed_beam_lane() -> void:
	var f := fixture(6,Vector2(240,0))
	wall(f.host,Vector2(0,42)); wall(f.host,Vector2(0,-42))
	await physics_frame
	f.boss.set_physics_process(false)
	var combat = f.combat
	var started: bool = combat.start_action(&"beam")
	if started:
		for _step in range(90): combat.advance(1.0/60)
	check(f.player.health.current_health==100,"beam damages fully blocked horizontal escape lane (player radius 16.9; available side clearance 5.1)")
	print("FAIRNESS SEALED LANE: started%s HP%s" % [started,f.player.health.current_health])
	f.host.free(); await process_frame
func cancellation_cases(chapter: int) -> void:
	var f := fixture(chapter,Vector2(240,0)); var combat = f.combat
	f.boss.set_physics_process(false)
	var kind: StringName = &"seal" if chapter==4 else &"beam"
	check(combat.start_action(kind),"hitch fixture cannot arm")
	combat.advance(0.5)
	check(not combat.is_attacking() and f.player.health.current_health==100,"large frame step turns unseen warning into live damage chapter%s" % chapter)
	f.host.free(); await process_frame
	f = fixture(chapter,Vector2(240,0)); combat = f.combat
	f.boss.set_physics_process(false)
	check(combat.start_action(kind),"pause fixture cannot arm")
	paused = true; combat.advance(1.0/60)
	check(not combat.is_attacking() and f.player.health.current_health==100,"pause leaves live attack chapter%s" % chapter)
	paused = false
	f.host.free(); await process_frame
	f = fixture(chapter,Vector2(240,0)); combat = f.combat
	f.boss.set_physics_process(false)
	check(combat.start_action(kind),"death fixture cannot arm")
	f.player.take_damage(1000,&"test")
	check(not combat.is_attacking(),"player death retains attacking geometry chapter%s" % chapter)
	f.host.free(); await process_frame
func run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		# Drain a tick from the old rate before the new-rate fixture is created.
		await physics_frame; await physics_frame
		await natural_dodge(4,&"seal",Vector2(240,0),"move_right",rate)
		await natural_dodge(4,&"page",Vector2(120,0),"move_down",rate)
		await natural_dodge(4,&"page",Vector2(150,0),"move_down",rate)
		await natural_dodge(6,&"beam",Vector2(240,0),"move_down",rate)
		await natural_dodge(6,&"probes",Vector2(240,0),"move_down",rate)
		await natural_dodge(6,&"refract",Vector2(240,0),"move_down",rate)
	await sealed_beam_lane()
	await cancellation_cases(4); await cancellation_cases(6)
	release_inputs(); Engine.physics_ticks_per_second = original_rate
	print("FAIRNESS SUMMARY: checks%s failures%s" % [checks,failures])
	if not failures: print("TEST PASS: BossFairnessFourthSixthTest %d" % checks)
	quit(1 if failures else 0)
