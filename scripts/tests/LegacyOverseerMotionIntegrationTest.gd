extends SceneTree
## Actual legacy Actor/controllers with explicit authoritative clock fixtures.
## No UI/player-input, all-chapter, export, or rendered appearance claim.
const BossSource = preload("res://scripts/actors/OverseerBoss.gd")
var checks := 0
var failures := 0
class Target extends Node2D:
	var damage_taken := 0.0
	func take_damage(amount: float) -> void: damage_taken += amount
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: LegacyOverseerMotionIntegrationTest " + message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var shots := Node2D.new()
	arena.add_child(shots)
	var target := Target.new()
	target.position = Vector2(500, 0)
	arena.add_child(target)
	var boss = BossSource.new()
	boss.setup(5, shots, target)
	arena.add_child(boss)
	boss.set_physics_process(false)
	var view = boss.get_visual_node()
	check(view.scene_file_path == "res://scenes/actors/native/root_overseer_paper_v1.tscn", "actual legacy Actor has no independent attack rig")
	var melee = boss.get_tentacle_attack()
	var director = boss.get_attack_director()
	var pattern = director.get_pattern()
	check(melee.has_signal("attack_finished") and melee.has_signal("attack_cancelled") and pattern.has_signal("pattern_cancelled") and pattern.has_method("get_visual_state"), "authoritative observation contract missing")
	if failures:
		arena.free()
		await process_frame
		quit(1)
		return
	boss._physics_process(1.41)
	check(boss.entrance_resolved and boss.process_mode == Node.PROCESS_MODE_PAUSABLE, "real entrance/processing changed")
	check(view.player.get_animation_list().size() == 21 and view.skeleton.get_bone_count() == 23, "actual rig/clip coverage drift")
	check(boss.health.max_health == 10800 and boss.body_radius == 56 and boss.MOVE_SPEED == 63.8, "art changes combat constants")
	var root_at: Transform2D = boss.global_transform
	var completed: Array[int] = []
	var reset_seen := [true]
	melee.connect("attack_finished", func(kind: int):
		completed.append(kind)
		reset_seen[0] = reset_seen[0] and not melee.is_attacking() and melee.elapsed == 0)
	check(melee.start_sweep(target.position), "actual sweep rejected")
	melee.set_physics_process(false) # Test owns explicit combat clock below.
	melee.advance_attack(0.5)
	boss._update_boss_motion(0)
	check_pose(view, "sweep_warning", 0.5)
	var elapsed_before: float = melee.elapsed
	boss._update_boss_motion(0.02)
	check(melee.elapsed == elapsed_before and shots.get_child_count() == 0, "sampling advances combat/fires shots")
	boss.take_damage(1)
	check(view.player.current_animation == "sweep_warning" and float(boss.boss_flash_material.get_shader_parameter("flash_amount")) == 0.35, "recoil overrides attack or flash disappeared")
	melee.advance_attack(0.61)
	boss._update_boss_motion(0)
	check_pose(view, "sweep_attack", 0.5)
	melee.advance_attack(0.12)
	boss._update_boss_motion(0)
	check(completed == [melee.AttackKind.SWEEP] and reset_seen[0], "completion absent/duplicated/pre-reset")
	check_pose(view, "sweep_recovery", 0)
	melee.advance_attack(1)
	check(completed.size() == 1, "idle produces repeated completion")
	# Cancel an already-completed visual tail, not only an active warning.
	melee.cancel_attack()
	boss.velocity = Vector2.ZERO
	boss._update_boss_motion(0)
	check(view.player.current_animation == "idle", "cancel leaves stale recovery")
	check(melee.start_slam(melee.make_slam_targets(target.position, 2)), "actual slam rejected")
	melee.set_physics_process(false)
	melee.advance_attack(0.55)
	boss._update_boss_motion(0)
	check_pose(view, "slam_warning", 0.5)
	var damage_before: float = target.damage_taken
	melee.advance_attack(0.56) # Slam resolves and finishes in this SAME call.
	check(not melee.is_attacking() and completed.size() == 2 and completed[1] == melee.AttackKind.SLAM, "slam changed instantaneous combat lifecycle")
	check(shots.get_child_count() == 12 and target.damage_taken == damage_before, "slam projectiles/targets changed")
	boss._update_boss_motion(0)
	check_pose(view, "slam_attack", 0)
	boss._update_boss_motion(0.07)
	check_pose(view, "slam_attack", 0.5)
	# Actual PAUSABLE tree gate, then resume the SAME pose/clock.
	boss.set_physics_process(true)
	var paused_pose: Transform2D = view.skeleton.get_bone(0).transform
	var paused_director_time: float = director.state_elapsed
	paused = true
	for frame in 4: await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(paused_pose) and director.state_elapsed == paused_director_time, "pause advances visual or combat clock")
	boss.set_physics_process(false)
	paused = false
	boss._update_boss_motion(0.07)
	check_pose(view, "slam_recovery", 0)
	boss._update_boss_motion(0.35)
	check(view.player.current_animation == "idle" and target.damage_taken == damage_before and shots.get_child_count() == 12, "visual tail repeats gameplay/never settles")
	# Cancelled warnings must NEVER create successful attack tails.
	check(melee.start_sweep(target.position), "second sweep rejected")
	melee.set_physics_process(false)
	boss._update_boss_motion(0)
	melee.cancel_attack()
	boss._update_boss_motion(0)
	check(view.player.current_animation == "idle" and completed.size() == 2, "cancel is mistaken for completion")
	check(melee.start_sweep(target.position), "tail replacement sweep rejected")
	melee.set_physics_process(false)
	melee.advance_attack(1.23)
	boss._update_boss_motion(0)
	check_pose(view, "sweep_recovery", 0)
	check(melee.start_slam(melee.make_slam_targets(target.position, 2)), "new action cannot replace completed tail")
	melee.set_physics_process(false)
	boss._update_boss_motion(0)
	check_pose(view, "slam_warning", 0)
	melee.cancel_attack()
	boss._update_boss_motion(0.05)
	check(view.player.current_animation == "idle" and completed.size() == 3, "replaced tail resurfaces after new-action cancel")
	melee.cleanup_projectiles()
	await process_frame
	var ranged_completed: Array[StringName] = []
	var pattern_reset_seen := [true]
	pattern.connect("pattern_finished", func(action: StringName):
		ranged_completed.append(action)
		pattern_reset_seen[0] = pattern_reset_seen[0] and not pattern.is_pattern_active() and pattern.call("get_visual_state").is_empty())
	for action in [pattern.AIMED_FAN, pattern.TWIN_SPIRAL, pattern.BROKEN_RING]:
		pattern.advance(1) # Clear ORIGINAL blank window; does not start an attack.
		check(pattern.start_pattern(action), "pattern rejected " + String(action))
		var plan: Array = pattern.get_active_plan()
		var first_time: float = plan[0].time
		var last_time: float = plan[-1].time
		var snapshot: Dictionary = pattern.call("get_visual_state")
		var count_before: int = pattern.get_total_spawned()
		for sample in 5: snapshot = pattern.call("get_visual_state")
		check(snapshot.elapsed == 0 and pattern.get_total_spawned() == count_before and pattern.get_active_plan() == plan, "readonly snapshot mutates pattern")
		check(snapshot.pattern == action and snapshot.stage == "warning" and snapshot.first_shot_seconds == first_time and snapshot.last_shot_seconds == last_time, "snapshot not actual seeded plan")
		pattern.advance(first_time * 0.5)
		boss._update_boss_motion(0)
		check_pose(view, String(action) + "_warning", 0.5)
		pattern.advance(first_time * 0.5 + (last_time - first_time) * 0.5)
		boss._update_boss_motion(0)
		check_pose(view, String(action) + "_attack", 0.5)
		var bullets_before: int = shots.get_child_count()
		pattern.cancel(false)
		boss._update_boss_motion(0)
		check(view.player.current_animation == "idle" and shots.get_child_count() == bullets_before and not pattern.is_pattern_active(), "cancel clears live bullets/plays recovery")
		check(ranged_completed.size() == [pattern.AIMED_FAN, pattern.TWIN_SPIRAL, pattern.BROKEN_RING].find(action), "cancel emits successful pattern completion")
		pattern.clear_projectiles()
		await process_frame
		pattern.advance(1)
		check(pattern.start_pattern(action), "completed pattern rejected")
		plan = pattern.get_active_plan()
		pattern.advance(float(plan[-1].time) + 0.001)
		boss._update_boss_motion(0)
		check_pose(view, String(action) + "_recovery", 0)
		check(not pattern.is_pattern_active() and shots.get_child_count() > 0, "recovery changes fired projectiles")
		var receipts_before: int = ranged_completed.size()
		pattern.advance(0.01)
		check(pattern_reset_seen[0] and ranged_completed[-1] == action and ranged_completed.size() == receipts_before, "pattern completion pre-reset/duplicate/wrong identity")
		pattern.cancel(false)
		boss._update_boss_motion(0)
		check(view.player.current_animation == "idle", "inactive cancel leaves ranged tail")
		pattern.clear_projectiles()
		await process_frame
	# Hidden target and true HP transition invalidate short impact/recovery tails.
	check(melee.start_slam(melee.make_slam_targets(target.position, 2)), "hidden setup slam")
	melee.set_physics_process(false)
	melee.advance_attack(1.11)
	boss._update_boss_motion(0)
	director.set_target_hidden(true)
	boss._update_boss_motion(0)
	check(view.player.current_animation == "idle", "hidden target leaves attack tail")
	director.set_target_hidden(false)
	boss.take_damage(4000)
	check(director.get_state_name() == "TRANSITION_1" and view.player.current_animation == "phase_transition", "real health transition/recoil mapping wrong")
	director.advance(0.325)
	boss._update_boss_motion(0)
	check_pose(view, "phase_transition", 0.5)
	director.advance(0.325)
	boss._update_boss_motion(0)
	check(director.get_state_name() == "PHASE_2" and view.player.current_animation == "idle", "transition length/new phase changed")
	check(boss.global_transform.is_equal_approx(root_at) and boss.modulate.a == 1, "body animation moves/fades physical root")
	# Kill during warning: only genuine detached PAUSABLE death remains.
	check(melee.start_sweep(target.position), "death setup sweep")
	melee.set_physics_process(false)
	boss._update_boss_motion(0)
	boss.take_damage(1e9)
	check(director.get_state_name() == "DEATH" and not melee.is_attacking() and not pattern.is_pattern_active() and view.player.current_animation == "death", "death retains combat/body attack")
	check(view.get_parent() == arena and view.process_mode == Node.PROCESS_MODE_PAUSABLE and boss.boss_motion.view == null, "death release lifecycle changed")
	view.player.advance(1.4)
	await process_frame
	check(not is_instance_valid(view) and not is_instance_valid(boss), "actual death/actor leaks")
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: LegacyOverseerMotionIntegrationTest %d" % checks)
	quit(1 if failures else 0)
func check_pose(view: Node2D, clip: String, ratio: float) -> void:
	check(view.player.current_animation == clip, "clip mismatch expected " + clip)
	if view.player.current_animation == clip:
		check(is_equal_approx(view.player.current_animation_position, view.player.get_animation(clip).length * ratio), "authoritative phase mismatch " + clip)
