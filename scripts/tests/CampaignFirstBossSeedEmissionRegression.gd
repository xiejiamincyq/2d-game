extends SceneTree
## Reproduction through normal actor physics. Never calls start_action(),
## advance(), _physics_process(), or _release_seeds() directly.
const Boss = preload("res://scripts/actors/NurseryVineBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Seed = preload("res://scripts/components/VineSeedProjectile.gd")
class ObservedBoss extends Boss:
	var release_origin_samples: Array[Dictionary] = []
	func get_safe_seed_origin() -> Vector2:
		var result := super.get_safe_seed_origin()
		if attack_director.action == &"seeds" and attack_director.action_stage == attack_director.Stage.ACTIVE:
			var locked: Vector2 = attack_director.seed_warning_paths[0] \
				if not attack_director.seed_warning_paths.is_empty() else result
			release_origin_samples.append({"active_elapsed":attack_director.action_elapsed,
				"origin":result, "locked":locked, "drift":result.distance_to(locked)})
		return result
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignFirstBossSeedEmissionRegression " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var ticks := 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ticks="):
			ticks = int(argument.trim_prefix("--ticks="))
	check(ticks in [30, 60, 120], "supported natural physics rate")
	if failures:
		quit(1)
		return
	Engine.physics_ticks_per_second = ticks
	root.size = Vector2i(1280, 720)
	var host := Node2D.new()
	root.add_child(host)
	var shots := Node2D.new()
	host.add_child(shots)
	var player := Player.new()
	player.position = Vector2(800, 360)
	player.world_bounds = Rect2(-1000, -1000, 3000, 2500)
	host.add_child(player)
	# No keys or mouse fire are injected. Player stays still in open terrain.
	# Optional diagnostic only wraps the socket getter and returns its unmodified
	# result. The default regression uses the production Boss itself.
	var observe_socket := "--observe-seed-origin" in OS.get_cmdline_user_args()
	var boss := ObservedBoss.new() if observe_socket else Boss.new()
	boss.position = Vector2(480, 360)
	boss.world_bounds = player.world_bounds
	boss.setup(1, shots, player)
	host.add_child(boss)
	var combat = boss.get_attack_director()
	var observations := {"seed_warnings":0, "births":0, "fans":[], "origin_drift":0.0}
	var batch: Array[Vector2] = []
	shots.child_entered_tree.connect(func(shot: Node):
		if shot.get_script() == Seed:
			observations.births += 1
			# child_entered_tree precedes the director assigning velocity;
			# sampling below records the real initialized flight outcome.
	)
	boss.combat_cue.connect(func(cue: StringName):
		if cue == &"boss_barrage": observations.seed_warnings += 1
	)
	var previous_action: StringName = &""
	var previous_stage := -1
	for _frame in ticks * 8:
		await physics_frame
		await process_frame
		if combat.action == &"seeds" and combat.action_stage == combat.Stage.WARNING:
			if not combat.seed_warning_paths.is_empty():
				observations.origin_drift = maxf(observations.origin_drift,
					boss.get_safe_seed_origin().distance_to(combat.seed_warning_paths[0]))
		if combat.action == &"seeds" and combat.action_stage == combat.Stage.ACTIVE \
				and (previous_action != &"seeds" or previous_stage != combat.Stage.ACTIVE):
			batch.clear()
			for shot in shots.get_children():
				if shot.get_script() == Seed and not shot.is_queued_for_deletion():
					batch.append(shot.velocity)
			observations.fans.append(batch.duplicate())
		previous_action = combat.action
		previous_stage = combat.action_stage
		if observations.fans.size() >= 2: break
	check(boss.entrance_resolved and combat.current_phase == 1,
		"natural entrance did not reach phase one")
	check(observations.seed_warnings >= 2,
		"open-arena natural controller did not select repeated seed warnings")
	check(observations.births >= 6 and observations.fans.size() >= 2,
		"natural phase-one seed warnings must release repeated three-route fans; " + str(observations))
	for fan in observations.fans:
		check(fan.size() == 3, "phase-one natural fan must contain exactly three live seeds")
		if fan.size() == 3:
			check(is_equal_approx(fan[0].length(), 300.0)
				and is_equal_approx(fan[1].length(), 300.0)
				and is_equal_approx(fan[2].length(), 300.0), "natural seed base flight speed")
			check(is_equal_approx(absf(fan[0].angle_to(fan[1])), deg_to_rad(18))
				and is_equal_approx(absf(fan[1].angle_to(fan[2])), deg_to_rad(18)),
				"natural three routes need distinct 18-degree separations")
	print("NATURAL SEED EMISSION OBSERVATIONS: " + str(observations))
	if observe_socket:
		print("NATURAL SEED ORIGIN READS: " + str(boss.release_origin_samples))
	host.free()
	await process_frame
	if failures == 0:
		print("TEST PASS: CampaignFirstBossSeedEmissionRegression %d" % checks)
	quit(1 if failures else 0)
