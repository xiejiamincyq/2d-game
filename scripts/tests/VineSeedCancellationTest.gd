extends SceneTree
## Real first-chapter Actor and seeds; synchronous child-birth cancellation.
## Normal flight is the positive damage control, not a completed chapter.
const Boss = preload("res://scripts/actors/NurseryVineBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VineSeedCancellationTest " + label)
func _initialize() -> void: call_deferred("run")
func advance_warning(combat: Node) -> void:
	var remaining: float = combat.DURATIONS[&"seeds"][0]
	while remaining>0.0000001:
		var step := minf(1.0/120.0, remaining)
		combat.advance(step); remaining -= step
func run() -> void:
	for mode in ["normal", "shutdown", "cancel_action"]:
		var host := Node2D.new(); root.add_child(host)
		var shots := Node2D.new(); host.add_child(shots)
		var player := Player.new(); player.position = Vector2(300, 0)
		player.world_bounds = Rect2(-1000, -1000, 2000, 2000)
		host.add_child(player); player.set_physics_process(false)
		var boss := Boss.new(); boss.world_bounds = player.world_bounds
		boss.setup(1, shots, player); host.add_child(boss); boss.set_physics_process(false)
		var combat = boss.get_attack_director()
		combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
		check(player.health.current_health==100 and player.shield==0 and combat.current_phase==1,
			"unaltered real actor setup " + mode)
		var births := {"count":0}; shots.child_entered_tree.connect(func(_shot): births.count += 1)
		if mode!="normal":
			shots.child_entered_tree.connect(func(_shot):
				if mode=="shutdown": combat.shutdown()
				else: combat.cancel_action()
			, CONNECT_ONE_SHOT)
		var armed: bool = combat.start_action(&"seeds")
		check(armed and boss.should_show_attack_marker(), "genuine seed warning not admitted " + mode)
		if armed:
			advance_warning(combat)
			if mode=="normal":
				check(births.count==3 and shots.get_child_count()==3 and combat.owned_seeds.size()==3,
					"normal phase-one seed fan lost its bounded three births")
				for shot in shots.get_children():
					check(is_equal_approx(shot.damage,18.0) and is_equal_approx(shot.radius,6.0)
						and is_equal_approx(shot.velocity.length(),300.0), "normal seed profile changed")
				# Normal recovery must not erase a shot which has not reached its
				# ordinary target yet. Explicit cancellation is a separate event.
				combat.advance(combat.DURATIONS[&"seeds"][1])
				combat.advance(combat.DURATIONS[&"seeds"][2])
				check(not combat.is_attacking() and shots.get_child_count()==3,
					"normal recovery erased finite in-flight seeds")
				var deadline := Time.get_ticks_msec()+3000
				while player.health.current_health==100 and Time.get_ticks_msec()<deadline:
					await physics_frame
				check(player.health.current_health==82 and player.shield==0,
					"normal swept seed no longer deals its actual 18 damage")
				combat.shutdown(); await process_frame; await process_frame
				check(shots.get_child_count()==0 and combat.owned_seeds.is_empty(),
					"normal control cleanup leaves projectiles")
			else:
				check(births.count==1, "synchronous " + mode + " still spawns later fan members")
				check(not combat.is_attacking() and combat.owned_seeds.is_empty()
					and not boss.should_show_attack_marker(), "cancelled birth appended ownership " + mode)
				check(combat.get_state_name()==("DEATH" if mode=="shutdown" else "PHASE_1"),
					"birth cancellation overwrote terminal/nonterminal state " + mode)
				for shot in shots.get_children():
					check(shot.is_queued_for_deletion(), "cancelled newborn remains live " + mode)
				await process_frame; await process_frame
				check(shots.get_child_count()==0 and combat.owned_seeds.is_empty(),
					"deferred cancellation leaves newborn/ownership " + mode)
				check(player.health.current_health==100 and player.shield==0,
					"cancelled fan damages its target " + mode)
		print("SEED CANCELLATION CASE: " + mode)
		host.free(); await process_frame
	if not failures: print("TEST PASS: VineSeedCancellationTest %d; real normal 18-damage control and two synchronous birth cancellations" % checks)
	quit(1 if failures else 0)
