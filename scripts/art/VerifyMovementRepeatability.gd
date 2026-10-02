extends SceneTree

# One process per run. Example user args: --seed=20260908 --track=D
# --mode=walk --run=smoke-d-walk-01 --steps=120 --clock=fixed.
# --clock is a caller declaration, not proof of engine pacing. Default: unknown.
# Formal budget is 1200 steps.
const MainScript = preload("res://scripts/Main.gd")
const StoreScript = preload("res://scripts/systems/RunSnapshotStore.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const FeedbackScript = preload("res://scripts/art/MovementDiagnosticFeedback.gd")
const TestSupportScript = preload("res://scripts/tests/TestSupport.gd")
const OUTPUT_DIR := "res://build/diagnostics/movement-repeatability/"
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]
const DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const DASH_STEPS := [180, 360, 540, 720, 900, 1080]

class DiagnosticMain extends MainScript:
	var isolated_save_path := ""
	func _ready() -> void:
		# Same startup wiring as Main, but never construct a store at the real path
		# and never overwrite the fixture's initial global RNG with randomize().
		process_mode = Node.PROCESS_MODE_ALWAYS
		RenderingServer.set_default_clear_color(Color(0.025, 0.032, 0.045))
		snapshot_store = StoreScript.new()
		snapshot_store.save_path = isolated_save_path
		add_child(snapshot_store)
		_build_world()
		ui.show_start_screen()
		ui.set_continue_available(snapshot_store.has_valid_snapshot())

var config := {"seed": 20260908, "track": "D", "mode": "walk", "run": "", "steps": 1200, "clock": "unknown"}
var scene: DiagnosticMain
var view: SubViewport
var screen: TextureRect
var feedback: Node
var samples: Array[Dictionary] = []
var render_frames := 0
var cleaning_up := false

func _initialize() -> void:
	process_frame.connect(_watchdog)
	if not _parse_args():
		quit(1)
		return
	_release_input()
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	var save_path := "user://movement-repeatability/%s/run.json" % config.run
	var output: String = OUTPUT_DIR + config.run + ".json"
	if FileAccess.file_exists(output) or FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".tmp") or FileAccess.file_exists(save_path + ".bak"):
		push_error("Movement run id already has evidence/save state; use a fresh --run id")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir())) != OK or DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR)) != OK:
		push_error("Could not create isolated movement evidence directories")
		quit(1)
		return
	var real_saves_before := _real_save_hashes()
	var orphan_nodes_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var clock_info := _clock_metadata()
	seed(config.seed)
	EnemyScript.next_formation_slot_index = 0
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	screen = TextureRect.new()
	screen.texture = view.get_texture()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	scene = DiagnosticMain.new()
	scene.isolated_save_path = save_path # Set before entering Main's initialization.
	view.add_child(scene)
	if not scene.is_node_ready():
		await scene.ready
	await process_frame
	if scene.snapshot_store.save_path != save_path:
		push_error("Diagnostic Main did not retain its preassigned isolated save path")
		quit(1)
		return
	scene._start_run()
	if not scene.player.is_node_ready():
		await scene.player.ready
	if not scene.wave_director.is_node_ready():
		await scene.wave_director.ready
	scene.wave_director.spawn_rng.seed = int(config.seed) + 1000003
	scene.map_seed = config.seed
	scene.arena_layout.generate(scene.WORLD_BOUNDS, config.seed)
	_replace_feedback()
	scene.player.advance_entrance(scene.player.get_entrance_duration() + 0.01)
	scene.wave_director.spawn_queue.clear() # Before banner completion: no natural portals.
	scene.ui.wave_banner.finish_message()
	scene.wave_director.active = false
	scene.wave_director.set_process(false)
	for _warmup in range(2):
		await physics_frame
		await process_frame
	scene.elapsed_seconds = 0.0
	scene.shield_drop_timer = 4.0
	scene.player.get_node("PlayerCamera").reset_smoothing()
	var kinds: Array = EnemyScript.EnemyKind.values()
	for index in range(60):
		var angle := TAU * float(index) / 60.0
		scene.wave_director._spawn_enemy_at(kinds[index % kinds.size()], Vector2(cos(angle) * 280.0, sin(angle) * 220.0))
	scene.wave_director._emit_wave_status()
	view.notify_mouse_entered()
	var initial := {"map_seed": scene.map_seed, "layout_seed": scene.arena_layout.map_seed,
		"global_seed": config.seed, "spawn_seed": int(config.seed) + 1000003,
		"formation_index_after_spawns": EnemyScript.next_formation_slot_index,
		"enemies": scene.wave_director.active_enemies.size(), "portals": scene.wave_director.active_portals.size(),
		"player": _player_state(), "save_path_isolated": scene.snapshot_store.save_path == save_path,
		"spawn_guard_active": scene.player.spawn_input_guard_active, "time_scale": Engine.time_scale}
	var valid: bool = initial.enemies == 60 and initial.portals == 0 and not initial.spawn_guard_active and not paused and scene.run_state == scene.RunState.PLAYING
	valid = valid and initial.map_seed == config.seed and initial.layout_seed == config.seed and scene.player.health.invulnerable_time <= 0.0
	var first_frame := Engine.get_physics_frames()
	var previous_frame := first_frame
	var started_usec := Time.get_ticks_usec()
	var simulated_seconds := 0.0
	var travelled := 0.0
	var previous_position: Vector2 = scene.player.global_position
	Input.action_press("fire")
	for index in range(config.steps if valid else 0):
		var direction: Vector2 = DIRECTIONS[(index / 75) % DIRECTIONS.size()]
		_drive(direction)
		Input.action_release("dash_melee")
		var dash_requested: bool = config.mode == "dash" and index + 1 in DASH_STEPS
		if dash_requested:
			Input.action_press("dash_melee")
		await physics_frame
		var injected_frame := Engine.get_physics_frames()
		var before_position: Vector2 = scene.player.global_position
		var aim_world := before_position + direction * 480.0
		var mouse := InputEventMouseMotion.new()
		mouse.position = view.canvas_transform * aim_world
		view.push_input(mouse, true)
		var scale_before := Engine.time_scale
		await process_frame
		var current_frame := Engine.get_physics_frames()
		var delta: float = scene.player.get_physics_process_delta_time()
		var point: Vector2 = scene.player.global_position
		var actual_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var aim := Vector2.RIGHT.rotated(scene.player.gun_angle)
		valid = valid and current_frame == previous_frame + 1 and injected_frame == current_frame and actual_input.is_equal_approx(direction)
		valid = valid and aim.dot(direction) >= 0.9999 and (config.track != "D" or is_equal_approx(scale_before, 1.0))
		valid = valid and is_finite(delta) and delta > 0.0 and delta <= 1.0 / 60.0 + 0.000001
		simulated_seconds += delta
		travelled += previous_position.distance_to(point)
		var state := _player_state()
		state.merge({"step": index + 1, "physics_frame": current_frame, "physics_delta": delta,
			"simulated_seconds": simulated_seconds, "wall_seconds": float(Time.get_ticks_usec() - started_usec) / 1000000.0,
			"input": [actual_input.x, actual_input.y], "dash_requested": dash_requested,
			"mouse_injected_physics_frame": injected_frame, "mouse_viewport": [mouse.position.x, mouse.position.y],
			"aim_world_requested": [aim_world.x, aim_world.y], "actual_aim": [aim.x, aim.y],
			"scale_before_physics": scale_before, "scale_after_physics": Engine.time_scale,
			"spawn_rng_state": str(scene.wave_director.spawn_rng.state), "remaining_enemies": scene.wave_director.active_enemies.size()})
		samples.append(state)
		previous_position = point
		previous_frame = current_frame
		if scene.game_over or not valid:
			break
	_release_input()
	var terminal: String = "death" if scene.game_over else ("step_budget" if samples.size() == config.steps else "invalid_sampling")
	var final_state := _player_state()
	var ended_usec := Time.get_ticks_usec()
	cleaning_up = true
	# Stop live gameplay before draining deferred spawns. They must enter the
	# still-owned tree before it is freed, not become stranded shutdown objects.
	paused = true
	scene.set_process(false)
	feedback.cleanup_active = true
	feedback.reset_all()
	feedback.cleanup_active = false
	var feedback_events: Array = feedback.events.duplicate(true)
	if scene.snapshot_store.save_path == save_path:
		scene.snapshot_store.clear_snapshot() # Never clear a path that escaped isolation.
	else:
		valid = false
		push_error("Movement store path changed; refusing snapshot cleanup")
	await process_frame
	# Reuse the existing audio-test teardown after pending gameplay callbacks
	# have drained. stop() queues mixer deletion; a synthetic 0.25-second timer
	# under --fixed-fps would not give the audio thread 0.25 real seconds.
	scene.audio.set_process(false)
	scene.audio.silent_mode = true
	TestSupportScript.stop_audio(scene.audio)
	var audio_references_cleared: bool = scene.audio.voice_pool.is_empty() and scene.audio.streams.is_empty() and scene.audio.bgm_player == null and scene.audio.laser_loop_player == null
	if not audio_references_cleared:
		push_error("Movement audio teardown retained player or stream references")
	var audio_flush_started := Time.get_ticks_usec()
	while Time.get_ticks_usec() - audio_flush_started < 250000:
		OS.delay_msec(5) # Bounded, post-measurement yield to the mixer thread.
		await process_frame
	var audio_flush_wall_seconds := float(Time.get_ticks_usec() - audio_flush_started) / 1000000.0
	screen.texture = null
	screen.queue_free()
	view.queue_free() # Owns Main and every fixture child, not just Main.
	await process_frame
	await process_frame
	var orphan_nodes_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var cleanup_valid := not is_instance_valid(scene) and not is_instance_valid(view) and not is_instance_valid(screen) and orphan_nodes_after <= orphan_nodes_before
	if not cleanup_valid:
		push_error("Movement fixture cleanup left owned nodes or increased orphan nodes")
	paused = false
	var real_saves_after := _real_save_hashes()
	valid = valid and cleanup_valid and audio_references_cleared and real_saves_before == real_saves_after and is_equal_approx(Engine.time_scale, 1.0)
	var wall_seconds := float(ended_usec - started_usec) / 1000000.0
	var unscaled_step_seconds := float(previous_frame - first_frame) / 60.0
	clock_info["wall_to_unscaled_step_ratio"] = wall_seconds / unscaled_step_seconds if unscaled_step_seconds > 0.0 else null
	clock_info["wall_to_simulated_ratio"] = wall_seconds / simulated_seconds if simulated_seconds > 0.0 else null
	var report := {"run": config.duplicate(), "sampling_valid": valid, "acceptance": "measurement_only" if valid else "invalid_sampling",
		"formal_step_budget": config.steps == 1200, "terminal": terminal, "initial": initial, "final": final_state,
		"sample_steps": samples.size(), "physics_steps": previous_frame - first_frame, "simulated_seconds": simulated_seconds,
		"wall_seconds": wall_seconds, "unscaled_step_seconds": unscaled_step_seconds, "clock": clock_info,
		"travelled_pixels": travelled, "samples": samples,
		"cleanup": {"owned_tree_freed": cleanup_valid, "orphan_nodes_before": orphan_nodes_before,
			"orphan_nodes_after": orphan_nodes_after, "audio_references_cleared": audio_references_cleared,
			"audio_flush_wall_seconds": audio_flush_wall_seconds, "objectdb_leaks": "requires_exit_log_review"},
		"hit_stop_events": feedback_events, "real_save_hashes_before": real_saves_before, "real_save_hashes_after": real_saves_after,
		"limitations": "Initialization/input sampling slice only, not balance acceptance. One 60-AI stress fixture; no invulnerability or enemy reset. D suppresses hit-stop only; R calls production hit-stop. Clock mode is a caller declaration, not automatic verification: engine args may be filtered. Unknown/fixed R is sampling smoke, never real-clock acceptance; declared realtime is still unverified. Equal step counts need not mean equal simulated time. Restore reasons distinguish natural expiry, game-state reset and diagnostic cleanup. Enemy ranged strafe still uses wall clock and instance IDs. No deterministic proof, normal-crowd result, screenshot or video acceptance yet."}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Movement sample report write failed")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MOVEMENT_SAMPLE_COMPLETE run=%s valid=%s steps=%d output=%s" % [config.run, valid, samples.size(), output])
	quit(0 if valid else 2)

func _clock_metadata() -> Dictionary:
	# OS.get_cmdline_args() omitted --fixed-fps in a confirmed fixed-FPS run.
	# Retain what was visible, but never infer real-time operation from absence.
	var fidelity := "not_applicable_D"
	if config.track == "R":
		fidelity = "declared_realtime_unverified" if config.clock == "realtime" else ("sampling_smoke_declared_fixed" if config.clock == "fixed" else "sampling_smoke_clock_unknown")
	return {"observed_cmdline_args": OS.get_cmdline_args(), "observed_args_complete": false,
		"clock_declaration": config.clock, "declaration_source": "user_argument_or_unknown_default",
		"automatic_clock_verification": "unavailable", "real_clock_pass": false, "fidelity": fidelity,
		"hit_stop_clock": "Time.get_ticks_msec", "simulation_clock": "sum_of_sampled_physics_delta"}

func _replace_feedback() -> void:
	var old: Node = scene.combat_feedback
	scene.wave_director.damage_resolved.disconnect(old.on_damage_resolved)
	old.reset_all()
	old.queue_free()
	feedback = FeedbackScript.new()
	feedback.track = config.track
	scene.add_child(feedback)
	feedback.setup(scene.combat_vfx, scene.camera_effects, scene.audio, func() -> bool: return scene.overdrive_active)
	scene.combat_feedback = feedback
	scene.wave_director.damage_resolved.connect(feedback.on_damage_resolved)

func _player_state() -> Dictionary:
	var player: Node = scene.player
	return {"position": [player.global_position.x, player.global_position.y], "velocity": [player.velocity.x, player.velocity.y],
		"health": player.health.current_health, "shield": player.shield, "dash_active": player.dash_active,
		"dash_cooldown": player.dash_cooldown_remaining, "stealth_remaining": player.stealth_remaining,
		"layer": player.collision_layer, "mask": player.collision_mask, "shape_disabled": player.player_collision.disabled}

func _real_save_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for path in [StoreScript.DEFAULT_PATH, MainScript.HEADLESS_SNAPSHOT_PATH]:
		for suffix in ["", ".tmp", ".bak"]:
			var full: String = path + suffix
			hashes[full] = FileAccess.get_sha256(full) if FileAccess.file_exists(full) else "absent"
	return hashes

func _parse_args() -> bool:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2 or not config.has(parts[0]):
			push_error("Unknown movement diagnostic argument: " + argument)
			return false
		config[parts[0]] = parts[1].to_int() if parts[0] in ["seed", "steps"] else parts[1]
	var run_pattern := RegEx.create_from_string("^[A-Za-z0-9_-]{1,80}$")
	var valid: bool = config.seed in [20260908, 20260909, 20260910] and config.track in ["D", "R"] and config.mode in ["walk", "dash"]
	valid = valid and config.steps >= 1 and config.steps <= 1200 and run_pattern.search(config.run) != null and config.clock in ["unknown", "fixed", "realtime"]
	if not valid:
		push_error("Expected registered seed, D/R, walk/dash, unique safe --run id, 1..1200 steps, and clock unknown/fixed/realtime")
	return valid

func _drive(direction: Vector2) -> void:
	for action in ACTIONS.slice(0, 4):
		Input.action_release(action)
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0:
		Input.action_press("move_down" if direction.y > 0 else "move_up")

func _release_input() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func _watchdog() -> void:
	if cleaning_up:
		return
	render_frames += 1
	if render_frames >= 3000:
		_release_input()
		Engine.time_scale = 1.0
		push_error("Movement sample exceeded its 3000-frame safety limit")
		quit(3)
