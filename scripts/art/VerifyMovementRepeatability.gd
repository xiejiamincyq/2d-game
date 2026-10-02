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
const SamplerScript = preload("res://scripts/art/MovementPhysicsSampler.gd")
const OUTPUT_DIR := "res://build/diagnostics/movement-repeatability/"
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]

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
var watchdog_started_usec := 0

func _initialize() -> void:
	watchdog_started_usec = Time.get_ticks_usec()
	process_frame.connect(_watchdog)
	if not _parse_args():
		quit(1)
		return
	_release_input()
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	var save_path := "user://movement-repeatability/%s/run.json" % config.run
	var output: String = OUTPUT_DIR + config.run + ".json"
	if FileAccess.file_exists(output) or FileAccess.file_exists(output.replace(".json", ".png")) or FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".tmp") or FileAccess.file_exists(save_path + ".bak"):
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
	var sampler := SamplerScript.new()
	sampler.scene = scene
	sampler.view = view
	sampler.config = config
	sampler.read_state = _player_state
	view.add_child(sampler)
	if valid:
		sampler.start()
		await sampler.finished
	valid = valid and sampler.valid
	samples = sampler.samples
	var first_frame: int = sampler.first_frame
	var previous_frame: int = sampler.previous_frame
	var started_usec: int = sampler.started_usec
	var ended_usec: int = sampler.ended_usec
	var simulated_seconds: float = sampler.simulated_seconds
	var travelled: float = sampler.travelled
	_release_input()
	var terminal: String = sampler.terminal
	var terminal_phase: String = sampler.terminal_phase
	var final_state: Dictionary = sampler.terminal_state if sampler.done else _player_state()
	var health_loss: float = sampler.health_loss
	var shield_loss: float = sampler.shield_loss
	cleaning_up = true
	# Stop live gameplay before draining deferred spawns. They must enter the
	# still-owned tree before it is freed, not become stranded shutdown objects.
	paused = true
	scene.set_process(false)
	feedback.cleanup_active = true
	feedback.reset_all()
	feedback.cleanup_active = false
	var feedback_events: Array = feedback.events.duplicate(true)
	var snapshot: Dictionary = {"captured": false, "reason": "headless", "sample_step": samples.size()}
	if DisplayServer.get_name() != "headless":
		var caption_layer := CanvasLayer.new()
		caption_layer.layer = 100
		var caption := Label.new()
		caption.text = "DIAGNOSTIC 60-AI | %s | step %d | %s\nPost-freeze image; terminal JSON was captured before pause notifications." % [config.run, samples.size(), terminal]
		caption.position = Vector2(16, 128)
		caption.add_theme_color_override("font_color", Color.YELLOW)
		caption.add_theme_color_override("font_outline_color", Color.BLACK)
		caption.add_theme_constant_override("outline_size", 6)
		caption_layer.add_child(caption)
		view.add_child(caption_layer)
		await RenderingServer.frame_post_draw
		var snapshot_path: String = output.replace(".json", ".png")
		var saved := view.get_texture().get_image().save_png(snapshot_path)
		snapshot = {"captured": saved == OK, "path": snapshot_path, "sample_step": samples.size(), "state": "post_freeze_notifications"}
		valid = valid and saved == OK
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
	var report := {"schema_version": 2, "sampling_method": "pre_post_physics_callbacks", "physics_hz": 60,
		"first_physics_frame": first_frame, "run": config.duplicate(), "sampling_valid": valid, "acceptance": "measurement_only" if valid else "invalid_sampling",
		"formal_step_budget": config.steps == 1200, "terminal": terminal, "terminal_phase": terminal_phase, "initial": initial, "final": final_state,
		"sample_steps": samples.size(), "physics_steps": previous_frame - first_frame, "simulated_seconds": simulated_seconds,
		"wall_seconds": wall_seconds, "unscaled_step_seconds": unscaled_step_seconds, "clock": clock_info,
		"travelled_pixels": travelled, "samples": samples,
		"health_loss": health_loss, "shield_loss": shield_loss,
		"snapshot": snapshot,
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

func _release_input() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func _watchdog() -> void:
	if cleaning_up:
		return
	render_frames += 1
	if Time.get_ticks_usec() - watchdog_started_usec >= 60000000:
		_release_input()
		Engine.time_scale = 1.0
		push_error("Movement sample exceeded its 60-second wall-clock safety limit")
		quit(3)
