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
const LobScript = preload("res://scripts/components/LobbedProjectile.gd")
const StressObserver = preload("res://scripts/art/StressCaptureObserver.gd")
const RenderedSources = preload("res://scripts/art/VerifyNaturalRunRendered.gd")
const OUTPUT_DIR := "res://build/diagnostics/movement-repeatability/"
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]
const NATURAL_CAPTURE_STEPS := [60, 180, 360, 600]

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

var config := {"seed": 20260908, "track": "D", "mode": "walk", "run": "", "steps": 1200, "clock": "unknown", "scenario": "stress60", "capture": "none"}
var scene: DiagnosticMain
var view: SubViewport
var screen: TextureRect
var feedback: Node
var samples: Array[Dictionary] = []
var render_frames := 0
var cleaning_up := false
var watchdog_started_usec := 0
var active_sampler: Node
var live_captures: Array[Dictionary] = []
var live_capture_valid := true
var stress_observer: RefCounted

func _initialize() -> void:
	watchdog_started_usec = Time.get_ticks_usec()
	process_frame.connect(_watchdog)
	if not _parse_args():
		quit(1)
		return
	if DirAccess.dir_exists_absolute(OUTPUT_DIR + config.run + "-peak"):
		push_error("Existing pressure peak evidence; use a fresh run ID")
		quit(1)
		return
	var source_hashes_before := _source_hashes()
	_release_input()
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	var save_path := "user://movement-repeatability/%s/run.json" % config.run
	var output: String = OUTPUT_DIR + config.run + ".json"
	if FileAccess.file_exists(output) or FileAccess.file_exists(output.replace(".json", ".png")) or FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".tmp") or FileAccess.file_exists(save_path + ".bak"):
		push_error("Movement run id already has evidence/save state; use a fresh --run id")
		quit(1)
		return
	for capture_step in NATURAL_CAPTURE_STEPS:
		if FileAccess.file_exists(_live_capture_path(capture_step)):
			push_error("Movement run id has an existing live capture; refusing overwrite")
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
	var startup_frame := Engine.get_physics_frames()
	if config.scenario == "natural_wave1":
		var start_event := InputEventKey.new()
		start_event.keycode = KEY_ENTER
		start_event.pressed = true
		view.push_input(start_event, true)
		start_event = start_event.duplicate()
		start_event.pressed = false
		view.push_input(start_event, true)
	else:
		scene._start_run()
	if not scene.run_started:
		push_error("Diagnostic start input did not start the run")
		quit(2)
		return
	if not scene.player.is_node_ready():
		await scene.player.ready
	if not scene.wave_director.is_node_ready():
		await scene.wave_director.ready
	scene.wave_director.spawn_rng.seed = int(config.seed) + 1000003
	_replace_feedback()
	if config.scenario == "natural_wave1":
		# No skipped entrance/banner, regenerated map, injected monsters or HP reset.
		# Release-only startup lets the production spawn-input guard clear itself.
		while not scene.game_over and (scene.run_state != scene.RunState.PLAYING or scene.player.spawn_input_guard_active):
			await physics_frame
			await process_frame
	else:
		scene.map_seed = config.seed
		scene.arena_layout.generate(scene.WORLD_BOUNDS, config.seed)
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
	initial.merge({"start_input": "enter" if config.scenario == "natural_wave1" else "direct_fixture",
		"startup_unsampled_physics_steps": Engine.get_physics_frames() - startup_frame,
		"director_active": scene.wave_director.active, "director_running": scene.wave_director.wave_running,
		"kills": scene.kill_count})
	var valid: bool = not initial.spawn_guard_active and not paused and scene.run_state == scene.RunState.PLAYING and scene.player.health.invulnerable_time <= 0.0
	if config.scenario == "natural_wave1":
		valid = valid and initial.enemies == 0 and initial.portals == 3 and initial.player.spawn_pending == 41
		valid = valid and initial.map_seed == initial.layout_seed and initial.director_active and initial.director_running
		valid = valid and initial.kills == 0 and initial.player.health == 100.0 and initial.player.shield == 0.0 and scene.player.global_position == Vector2.ZERO
	else:
		valid = valid and initial.enemies == 60 and initial.portals == 0 and initial.map_seed == config.seed and initial.layout_seed == config.seed
	var sampler := SamplerScript.new()
	active_sampler = sampler
	sampler.scene = scene
	sampler.view = view
	sampler.config = config
	sampler.read_state = _player_state
	view.add_child(sampler)
	if config.capture == "peak":
		stress_observer = StressObserver.new()
		sampler.sample_recorded.connect(_observe_stress_sample)
		RenderingServer.frame_post_draw.connect(_capture_stress_frame)
	if config.scenario == "natural_wave1" and DisplayServer.get_name() != "headless":
		RenderingServer.frame_post_draw.connect(_capture_natural_frame)
	if valid:
		sampler.start()
		await sampler.finished
	valid = valid and sampler.valid and live_capture_valid
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
	var pressure_capture := {}
	if stress_observer != null:
		RenderingServer.frame_post_draw.disconnect(_capture_stress_frame)
		pressure_capture = stress_observer.finish(OUTPUT_DIR + config.run + "-peak", float(ended_usec-started_usec)/1000000.0, terminal)
		valid = valid and pressure_capture.valid
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
		caption.text = "DIAGNOSTIC %s | %s | step %d | %s\nPost-freeze image; terminal JSON was captured before pause notifications." % [config.scenario, config.run, samples.size(), terminal]
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
		"formal_step_budget": config.scenario == "stress60" and config.steps == 1200, "terminal": terminal, "terminal_phase": terminal_phase, "initial": initial, "final": final_state,
		"sample_steps": samples.size(), "physics_steps": previous_frame - first_frame, "simulated_seconds": simulated_seconds,
		"wall_seconds": wall_seconds, "unscaled_step_seconds": unscaled_step_seconds, "clock": clock_info,
		"travelled_pixels": travelled, "samples": samples,
		"health_loss": health_loss, "shield_loss": shield_loss,
		"snapshot": snapshot, "live_captures": live_captures,
		"cleanup": {"owned_tree_freed": cleanup_valid, "orphan_nodes_before": orphan_nodes_before,
			"orphan_nodes_after": orphan_nodes_after, "audio_references_cleared": audio_references_cleared,
			"audio_flush_wall_seconds": audio_flush_wall_seconds, "objectdb_leaks": "requires_exit_log_review"},
		"hit_stop_events": feedback_events, "real_save_hashes_before": real_saves_before, "real_save_hashes_after": real_saves_after,
		"limitations": "Measurement only, not balance/visual/human/performance acceptance. stress60 injects 60 AI; natural_wave1 starts via Enter, waits natural entrance/banner and release-only spawn guard, then observes wave 1 until death/clear/budget without invulnerability or enemy reset. Wave 1 has no lobbers: zero landing fills cannot validate lobber readability. Wave clear is not settlement/shop/restart acceptance. Fixed square inputs are a diagnostic bot, not human skill. D suppresses hit-stop; R calls production hit-stop. Clock mode is caller-declared and unverified. Enemy strafe uses wall clock and instance IDs; no deterministic claim."}
	report["process_id"] = OS.get_process_id()
	report["source_sha256_before"] = source_hashes_before
	report["pressure_capture"] = pressure_capture
	report["source_sha256_after"] = _source_hashes()
	report["source_hashes_unchanged"] = report.source_sha256_before == report.source_sha256_after
	valid = valid and report.source_hashes_unchanged
	report.sampling_valid = valid
	report.acceptance = "measurement_only" if valid else "invalid_sampling"
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Movement sample report write failed")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MOVEMENT_SAMPLE_COMPLETE run=%s valid=%s steps=%d output=%s" % [config.run, valid, samples.size(), output])
	quit(0 if valid else 2)

func _source_hashes() -> Dictionary:
	var hashes := {}
	for source in ["scripts/art/VerifyMovementRepeatability.gd", "scripts/art/MovementPhysicsSampler.gd", "scripts/art/MovementDiagnosticFeedback.gd", "scripts/Main.gd", "scripts/actors/Player.gd", "scripts/actors/Enemy.gd", "scripts/systems/WaveDirector.gd", "scripts/world/SpawnPortal.gd"]:
		hashes[source] = FileAccess.get_sha256("res://" + source)
	if config.capture == "peak":
		for source in RenderedSources.visual_source_paths() + ["scripts/art/StressCaptureObserver.gd", "scripts/art/LateCrowdLedger.gd"]:
			hashes[source] = FileAccess.get_sha256("res://" + source)
	return hashes

func _observe_stress_sample(sample: Dictionary) -> void:
	var bodies := StressObserver.Ledger.entities(scene.wave_director.active_enemies, view.canvas_transform,
		Rect2(Vector2.ZERO,Vector2(view.size)), scene.player.global_position, scene.player.get_body_radius())
	bodies["player_radius"] = scene.player.get_body_radius()
	var warnings: Array[Dictionary] = []
	for shot in scene.projectiles.get_children():
		if shot is LobScript and not shot.is_queued_for_deletion():
			warnings.append({"id":shot.get_instance_id(), "position":[shot.target_position.x,shot.target_position.y],
				"radius":shot.splash_radius, "elapsed":shot.elapsed, "duration":shot.flight_duration})
	stress_observer.observe_sample(sample, bodies, warnings)

func _capture_stress_frame() -> void:
	if not cleaning_up and is_instance_valid(active_sampler) and not active_sampler.done:
		stress_observer.capture(view, Engine.get_physics_frames(), float(Time.get_ticks_usec()-active_sampler.started_usec)/1000000.0)

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
	var state := {"position": [player.global_position.x, player.global_position.y], "velocity": [player.velocity.x, player.velocity.y],
		"health": player.health.current_health, "shield": player.shield, "dash_active": player.dash_active,
		"dash_cooldown": player.dash_cooldown_remaining, "stealth_remaining": player.stealth_remaining,
		"layer": player.collision_layer, "mask": player.collision_mask, "shape_disabled": player.player_collision.disabled}
	if config.scenario == "natural_wave1":
		state.merge(_natural_crowd_state())
	return state

func _natural_crowd_state() -> Dictionary:
	var kinds: Dictionary = {}
	var live := 0
	for enemy in scene.wave_director.active_enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.health == null or enemy.health.current_health <= 0.0:
			continue
		var kind: String = EnemyScript.EnemyKind.keys()[enemy.kind].to_lower()
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		live += 1
	var pending_count: int = scene.wave_director.spawn_queue.size()
	for queue in scene.wave_director.portal_spawn_queues.values():
		pending_count += queue.size()
	var fill_total := 0
	var fill_in_view := 0
	var world_corners := PackedVector2Array()
	var inverse := view.canvas_transform.affine_inverse()
	for corner in [Vector2.ZERO, Vector2(view.size.x, 0), Vector2(view.size), Vector2(0, view.size.y)]:
		world_corners.append(inverse * corner)
	for projectile in scene.projectiles.get_children():
		if not projectile is LobScript or projectile.is_queued_for_deletion() or not is_instance_valid(projectile.landing_fill):
			continue
		fill_total += 1
		var center: Vector2 = projectile.target_position
		var intersects := Geometry2D.is_point_in_polygon(center, world_corners)
		for edge in range(4):
			intersects = intersects or center.distance_to(Geometry2D.get_closest_point_to_segment(center, world_corners[edge], world_corners[(edge + 1) % 4])) <= projectile.splash_radius
		fill_in_view += int(intersects)
	return {"run_state": scene.RunState.keys()[scene.run_state], "wave_index": scene.wave_director.wave_index,
		"live_enemies": live, "enemy_kinds": kinds, "spawn_pending": pending_count, "kills": scene.kill_count,
		"portal_count": scene.wave_director.active_portals.size(), "director_collection": scene.wave_director.collection_window_active,
		"landing_fill_total": fill_total, "landing_fill_view_intersections": fill_in_view}

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
	valid = valid and config.scenario in ["stress60", "natural_wave1"] and (config.scenario != "natural_wave1" or config.track == "R")
	valid = valid and config.steps >= 1 and config.steps <= (10800 if config.scenario == "natural_wave1" else 1200) and run_pattern.search(config.run) != null and config.clock in ["unknown", "fixed", "realtime"]
	valid = valid and config.capture in ["none","peak"] and (config.capture != "peak" or (config.scenario == "stress60" and DisplayServer.get_name() != "headless"))
	if not valid:
		push_error("Expected registered seed, D/R, walk/dash, safe unique run, clock declaration; stress60 1..1200 steps or natural_wave1 R-only 1..10800 steps")
	return valid

func _release_input() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func _live_capture_path(step: int) -> String:
	return OUTPUT_DIR + config.run + "-step-%04d.png" % step

func _capture_natural_frame() -> void:
	if cleaning_up or not is_instance_valid(active_sampler) or active_sampler.done or live_captures.size() >= NATURAL_CAPTURE_STEPS.size():
		return
	var requested_step: int = NATURAL_CAPTURE_STEPS[live_captures.size()]
	if active_sampler.samples.size() < requested_step:
		return
	var path := _live_capture_path(requested_step)
	var capture := view.get_texture().get_image()
	var saved := not FileAccess.file_exists(path) and capture != null and not capture.is_empty() and capture.save_png(path) == OK
	live_capture_valid = live_capture_valid and saved
	live_captures.append({"requested_step": requested_step, "sample_step": active_sampler.samples.size(),
		"physics_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(),
		"path": path, "captured": saved, "render_state": _player_state(),
		"scope": "post_draw_live_image; may include idle callbacks after latest physics sample; capture IO is not performance evidence"})

func _watchdog() -> void:
	if cleaning_up:
		return
	render_frames += 1
	var wall_limit := 240000000 if config.scenario == "natural_wave1" else 60000000
	if Time.get_ticks_usec() - watchdog_started_usec >= wall_limit:
		if is_instance_valid(active_sampler) and not active_sampler.done:
			push_error("Movement wall-clock watchdog reached; sealing invalid evidence and cleaning up")
			active_sampler.valid = false
			active_sampler.terminal_phase = "before_input"
			active_sampler._finish("wall_timeout")
			return
		_release_input()
		Engine.time_scale = 1.0
		push_error("Movement sample exceeded its %d-second wall-clock safety limit" % (wall_limit / 1000000))
		quit(3)
