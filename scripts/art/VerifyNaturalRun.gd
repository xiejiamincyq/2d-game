extends SceneTree

const Policy = preload("res://scripts/art/NaturalRunPolicy.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const Store = preload("res://scripts/systems/RunSnapshotStore.gd")
const Main = preload("res://scripts/Main.gd")
const Support = preload("res://scripts/tests/TestSupport.gd")
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]
const OUTPUT := "res://build/diagnostics/natural-run/"
class Tap extends Node:
	var callback: Callable
	func _physics_process(delta: float) -> void:
		callback.call(delta)

var config := {"seed": 20260908, "steps": 1800, "run": "", "clock": "unknown", "mode": "flow", "resume": ""}
var policy := Policy.new()
var samples: Array[Dictionary] = []
var scene: Node
var view: SubViewport
var terminal := ""
var started := 0
var real_saves_before: Dictionary
var source_before: Dictionary
var waypoint := 0
var input_direction := Vector2.ZERO
var aim_world := Vector2.ZERO
var position_before := Vector2.ZERO
var pending_frame := 0
var initial_map_seed := 0
var valid := true
var simulation := 0.0
var orphan_before := 0
var events: Array[Dictionary] = []
var last_state := ""
var ui_next_frame := 0
var continued_once := false
var reloading := false
var result: Dictionary = {}
var restart_verified := false
var expected_checkpoint: Dictionary = {}
var resume_reference: Dictionary = {}

static func persisted_state_matches(actual: Dictionary, saved: Dictionary) -> bool:
	# JSON numbers lose int/float tags and use the store's decimal precision.
	# Compare the persisted representations without a gameplay-value tolerance.
	return JSON.parse_string(JSON.stringify(actual)) == JSON.parse_string(JSON.stringify(saved))

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2 or not config.has(parts[0]):
			quit(2)
			return
		config[parts[0]] = parts[1].to_int() if parts[0] in ["seed", "steps"] else parts[1]
	var safe_id := RegEx.create_from_string("^[A-Za-z0-9_-]{1,80}$")
	if config.seed not in [20260908, 20260909, 20260910] or config.steps < 1 or config.steps > 36000 or config.clock not in ["realtime", "fixed", "unknown"] or safe_id.search(config.run) == null or config.mode not in ["flow", "checkpoint", "idle"] or (not config.resume.is_empty() and (safe_id.search(config.resume) == null or config.mode != "flow")):
		push_error("Invalid natural run arguments")
		quit(2)
		return
	config["save_path"] = "user://natural-run/%s/run.json" % (config.run if config.resume.is_empty() else config.resume)
	policy = Policy.new(int(config.seed))
	if FileAccess.file_exists(OUTPUT + config.run + ".json") or (config.resume.is_empty() and FileAccess.file_exists(config.save_path)) or FileAccess.file_exists(config.save_path + ".tmp") or FileAccess.file_exists(config.save_path + ".bak"):
		push_error("Natural run refuses existing evidence/save path")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(config.save_path.get_base_dir())) != OK or DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT)) != OK:
		push_error("Natural run could not create isolated output paths")
		quit(2)
		return
	real_saves_before = _save_hashes()
	source_before = _source_hashes()
	orphan_before = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if not config.resume.is_empty():
		var checkpoint_path: String = OUTPUT + config.resume + ".json"
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path)) if FileAccess.file_exists(checkpoint_path) else null
		if not parsed is Dictionary or parsed.get("terminal") != "checkpoint" or parsed.get("valid") != true or parsed.get("source_sha256") != source_before or int(parsed.get("process_id", 0)) == OS.get_process_id() or int(parsed.get("config", {}).get("seed", 0)) != config.seed or not FileAccess.file_exists(config.save_path) or FileAccess.get_sha256(config.save_path) != parsed.get("isolated_save_sha256"):
			push_error("Resume requires same-source checkpoint from a different process and its unchanged isolated save")
			quit(2)
			return
		expected_checkpoint = parsed
		resume_reference = {"report_sha256": FileAccess.get_sha256(checkpoint_path), "snapshot_before": parsed.final.snapshot, "checkpoint_process_id": parsed.process_id, "verified": false}
	set_meta("natural_run_config", config)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	EnemyScript.next_formation_slot_index = 0
	_release_input()
	change_scene_to_file("res://scripts/art/NaturalRunDiagnostic.tscn")
	await scene_changed
	view = current_scene.get_node("View")
	scene = view.get_node("Main")
	view.notify_mouse_entered()
	await process_frame
	started = Time.get_ticks_usec()
	_key(KEY_ENTER if config.resume.is_empty() else KEY_C)
	if not config.resume.is_empty():
		var saved: Dictionary = expected_checkpoint.final.snapshot
		var restored := {"player": scene.player.get_snapshot_state(), "settlement": scene.upgrade_system.get_snapshot_state().settlement}
		var preserved: bool = scene.run_state == scene.RunState.SETTLEMENT and scene.map_seed == int(saved.map_seed) and scene.kill_count == int(saved.kills) and scene.upgrade_system.coins == int(saved.coins) and persisted_state_matches(restored.player, saved.player) and persisted_state_matches(restored.settlement, saved.settlement)
		valid = valid and preserved
		resume_reference.merge({"verified": preserved, "restored": restored}, true)
		continued_once = true
		events.append({"event": "process_continue_c", "verified": preserved, "checkpoint_process_id": expected_checkpoint.process_id, "current_process_id": OS.get_process_id()})
	initial_map_seed = scene.map_seed
	for priority in [-100000, 100000]:
		var tap := Tap.new()
		tap.process_mode = Node.PROCESS_MODE_ALWAYS
		tap.process_physics_priority = priority
		tap.callback = _before if priority < 0 else _after
		root.add_child(tap)
	process_frame.connect(_watchdog)
	while terminal.is_empty():
		await process_frame
	await _finish()

func _before(_delta: float) -> void:
	_release_input()
	if not terminal.is_empty() or reloading or not is_instance_valid(scene) or scene.run_state != scene.RunState.PLAYING or scene.player.spawn_input_guard_active:
		return
	var p: Vector2 = scene.player.global_position
	position_before = p
	if config.mode == "idle":
		input_direction = Vector2.ZERO
		aim_world = p + Vector2(500, 0)
		var idle_mouse := InputEventMouseMotion.new()
		idle_mouse.position = view.canvas_transform * aim_world
		view.push_input(idle_mouse, true)
		pending_frame = Engine.get_physics_frames()
		return # Observe natural contact damage without shooting or moving.
	var threats: Array = []
	var nearest: Node2D
	var nearest_distance := INF
	for enemy in scene.wave_director.active_enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.health.current_health <= 0:
			continue
		threats.append(enemy.global_position)
		var distance := p.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	var corners := [Vector2(650, -450), Vector2(650, 450), Vector2(-650, 450), Vector2(-650, -450)]
	if p.distance_to(corners[waypoint]) < 100:
		waypoint = (waypoint + 1) % corners.size()
	var goal: Vector2 = corners[waypoint]
	# Chase the final ranged stragglers instead of orbiting forever outside gun range.
	if threats.size() <= 5 and nearest != null and nearest_distance > 220.0 * 220.0:
		goal = nearest.global_position
	var pickup_distance := 200.0 * 200.0 if not threats.is_empty() else INF
	if nearest_distance > 250.0 * 250.0:
		for pickup in scene.pickups.get_children():
			if not pickup is Node2D or pickup.is_queued_for_deletion():
				continue
			var distance: float = p.distance_squared_to(pickup.global_position)
			if distance < pickup_distance:
				pickup_distance = distance
				goal = pickup.global_position
	var navigation: Vector2 = scene.arena_layout.get_navigation_direction(p, goal, scene.player.get_body_radius())
	input_direction = policy.choose_direction(p, navigation, threats, func(point: Vector2) -> bool: return scene.arena_layout.is_position_walkable(point, scene.player.get_body_radius()))
	for pair in [["move_right", maxf(input_direction.x, 0)], ["move_left", maxf(-input_direction.x, 0)], ["move_down", maxf(input_direction.y, 0)], ["move_up", maxf(-input_direction.y, 0)]]:
		if pair[1] > 0:
			Input.action_press(pair[0], pair[1])
	aim_world = nearest.global_position if nearest != null else p + navigation * 500
	aim_world = policy.nonzero_aim(p, aim_world)
	var mouse := InputEventMouseMotion.new()
	mouse.position = view.canvas_transform * aim_world
	view.push_input(mouse, true)
	Input.action_press("fire")
	if scene.player.dash_cooldown_remaining <= 0 and nearest_distance < 160.0 * 160.0 and input_direction != Vector2.ZERO:
		Input.action_press("dash_melee")
	pending_frame = Engine.get_physics_frames()

func _after(delta: float) -> void:
	if not terminal.is_empty() or reloading or not is_instance_valid(scene):
		return
	if scene.game_over:
		return # Let the real result UI and restart flow run in _flow_ui.
	if pending_frame != Engine.get_physics_frames():
		return
	valid = valid and scene.snapshot_store.save_path == config.save_path
	var aim_dot := Vector2.RIGHT.rotated(scene.player.gun_angle).dot((aim_world - position_before).normalized())
	valid = valid and aim_dot >= 0.9999
	if aim_dot < 0.9999:
		terminal = "invalid_aim"
	simulation += delta
	samples.append({"step": samples.size() + 1, "frame": pending_frame, "delta": delta, "scale": Engine.time_scale,
		"wall": float(Time.get_ticks_usec() - started) / 1000000.0, "simulation": simulation,
		"input": [input_direction.x, input_direction.y], "actual_input": [Input.get_vector("move_left", "move_right", "move_up", "move_down").x, Input.get_vector("move_left", "move_right", "move_up", "move_down").y],
		"aim_world": [aim_world.x, aim_world.y], "aim_dot": aim_dot, "gun_angle": scene.player.gun_angle, "fire": Input.is_action_pressed("fire"), "bullets": scene.projectiles.get_child_count(),
		"position": [scene.player.global_position.x, scene.player.global_position.y], "health": scene.player.health.current_health,
		"pilot_escape_events": policy.escape_events, "pilot_escape_remaining": policy.escape_remaining, "pilot_random_heading_changes": policy.random_heading_changes,
		"shield": scene.player.shield, "kills": scene.kill_count, "wave": scene.wave_director.wave_index + 1,
		"state": scene.RunState.keys()[scene.run_state], "live": scene.wave_director.active_enemies.size(),
		"pending": scene.wave_director.spawn_queue.size() + _portal_pending(), "coins": scene.upgrade_system.coins})
	if samples.size() >= int(config.steps) and terminal.is_empty():
		terminal = "step_budget"
	if samples.size() % 600 == 0:
		print("NATURAL_RUN_PROGRESS steps=%d wave=%d hp=%.1f kills=%d" % [samples.size(), scene.wave_director.wave_index + 1, scene.player.health.current_health, scene.kill_count])

func _portal_pending() -> int:
	var total := 0
	for queue: Array in scene.wave_director.portal_spawn_queues.values():
		total += queue.size()
	return total

func _key(code: int) -> void:
	for pressed in [true, false]:
		# R can synchronously detach the old scene on the press event.
		# There is no old UI left to receive its release; never push into detached Viewports.
		if not is_instance_valid(view) or not view.is_inside_tree():
			break
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		view.push_input(event, true)

func _release_input() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func _watchdog() -> void:
	if started > 0 and terminal.is_empty() and not reloading:
		_flow_ui()
	if started > 0 and terminal.is_empty() and Time.get_ticks_usec() - started > 900000000:
		valid = false
		terminal = "watchdog"

func _flow_ui() -> void:
	if not is_instance_valid(scene):
		return
	var state: String = scene.RunState.keys()[scene.run_state]
	if scene.run_started and initial_map_seed == 0:
		initial_map_seed = scene.map_seed
	if state != last_state:
		last_state = state
		events.append({"event": "state", "state": state, "step": samples.size(), "wave": scene.wave_director.wave_index + 1, "wall": float(Time.get_ticks_usec() - started) / 1000000.0})
		print("NATURAL_RUN_STATE state=%s wave=%d step=%d" % [state, scene.wave_director.wave_index + 1, samples.size()])
		ui_next_frame = Engine.get_process_frames() + 15
	if Engine.get_process_frames() < ui_next_frame:
		return
	if state == "RESULT":
		result = {"terminal": "victory" if scene.ui.result_screen.result_label.text.begins_with("清剿完成") else "death", "health": scene.player.health.current_health, "kills": scene.kill_count, "wave": scene.wave_director.wave_index + 1, "elapsed": scene.elapsed_seconds, "snapshot_cleared": not scene.snapshot_store.has_valid_snapshot(), "text": scene.ui.result_screen.result_label.text}
		valid = valid and result.snapshot_cleared
		_reload(true)
	elif state == "SETTLEMENT":
		if config.mode == "checkpoint":
			valid = valid and scene.snapshot_store.has_valid_snapshot()
			terminal = "checkpoint"
			return # Exit process while the production stable boundary remains on disk.
		if not continued_once:
			continued_once = true
			_reload(false)
			return
		var shop: Node = scene.ui.settlement_screen
		var selected := -1
		var best_priority := 999
		var preference := ["shield_capacity", "health", "drone", "mine", "arc", "gun_lines", "damage", "pierce", "fire_rate"]
		for index in range(shop.offer_buttons.size()):
			if shop.offer_buttons[index].visible and not shop.offer_buttons[index].disabled:
				var priority: int = preference.find(String(shop.current_offers[index].get("id", "")))
				if priority < 0:
					priority = 100 + index
				if priority < best_priority:
					selected = index
					best_priority = priority
		if selected >= 0:
			events.append({"event": "shop_key", "key": selected + 1, "offer": shop.current_offers[selected].duplicate(true), "coins_before": scene.upgrade_system.coins})
			_key(KEY_1 + selected)
		else:
			valid = valid and not shop.close_button.disabled
			shop.close_button.grab_focus()
			events.append({"event": "shop_close_enter", "wave": scene.wave_director.wave_index + 1})
			_key(KEY_ENTER)
		ui_next_frame = Engine.get_process_frames() + 15

func _reload(after_result: bool) -> void:
	reloading = true
	_release_input()
	var saved: Dictionary = scene.snapshot_store.load_snapshot()
	scene._reset_combat_feedback()
	Support.stop_audio(scene.audio)
	if after_result:
		_key(KEY_R) # Main's unchanged reload_current_scene path.
	else:
		paused = false
		reload_current_scene() # Simulated application reopen at a natural save boundary.
	await scene_changed
	view = current_scene.get_node("View")
	scene = view.get_node("Main")
	view.notify_mouse_entered()
	await process_frame
	valid = valid and scene.run_state == scene.RunState.START and scene.snapshot_store.save_path == config.save_path
	if after_result:
		restart_verified = not scene.ui.continue_button.visible and not scene.snapshot_store.has_valid_snapshot()
		valid = valid and restart_verified
		events.append({"event": "restart_title", "verified": restart_verified})
		terminal = result.terminal
	else:
		valid = valid and scene.ui.continue_button.visible and scene.snapshot_store.load_snapshot() == saved
		_key(KEY_C)
		valid = valid and scene.run_state == scene.RunState.SETTLEMENT and scene.map_seed == int(saved.map_seed) and scene.kill_count == int(saved.kills) and scene.upgrade_system.coins == int(saved.coins)
		events.append({"event": "continue_c", "saved": saved, "verified": valid, "scope": "same-process scene reopen; not yet separate OS process"})
		ui_next_frame = Engine.get_process_frames() + 15
	reloading = false

func _save_hashes() -> Dictionary:
	var hashes := {}
	for path in [Store.DEFAULT_PATH, Main.HEADLESS_SNAPSHOT_PATH]:
		for suffix in ["", ".tmp", ".bak"]:
			hashes[path + suffix] = FileAccess.get_sha256(path + suffix) if FileAccess.file_exists(path + suffix) else "absent"
	return hashes

func _source_hashes() -> Dictionary:
	var hashes := {}
	for path in ["scripts/art/VerifyNaturalRun.gd", "scripts/art/NaturalRunMain.gd", "scripts/art/NaturalRunPolicy.gd", "scripts/art/NaturalRunDiagnostic.tscn", "scripts/Main.gd", "scripts/actors/Player.gd", "scripts/actors/Enemy.gd", "scripts/actors/OverseerBoss.gd", "scripts/systems/WaveDirector.gd", "scripts/systems/UpgradeSystem.gd", "scripts/systems/RunSnapshotStore.gd", "scripts/systems/CombatFeedback.gd", "scripts/world/ArenaLayout.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes

func _finish() -> void:
	_release_input()
	paused = true
	scene.set_process(false)
	var final_state := {"state": scene.RunState.keys()[scene.run_state], "snapshot": scene.snapshot_store.load_snapshot()}
	if scene.player != null:
		final_state.merge({"health": scene.player.health.current_health, "kills": scene.kill_count, "wave": scene.wave_director.wave_index + 1})
	scene._reset_combat_feedback()
	await process_frame
	Support.stop_audio(scene.audio)
	var audio_flush := Time.get_ticks_usec()
	while Time.get_ticks_usec() - audio_flush < 250000:
		OS.delay_msec(5)
		await process_frame
	current_scene.free()
	await process_frame
	await process_frame
	Engine.time_scale = 1.0
	paused = false
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	valid = valid and _save_hashes() == real_saves_before and _source_hashes() == source_before and orphans <= orphan_before
	var report := {"config": config, "valid": valid, "acceptance": "measurement_only" if valid else "invalid_sampling",
		"process_id": OS.get_process_id(), "resume_reference": resume_reference,
		"isolated_save_sha256": FileAccess.get_sha256(config.save_path) if FileAccess.file_exists(config.save_path) else "absent",
		"terminal": terminal, "map_seed": initial_map_seed, "samples": samples, "final": final_state,
		"events": events, "result": result, "restart_verified": restart_verified,
		"real_saves_before": real_saves_before, "real_saves_after": _save_hashes(), "source_sha256": source_before,
		"orphan_before": orphan_before, "orphan_after": orphans, "clock_scope": "caller declaration; wall/physics observed; production hit-stop retained"}
	var file := FileAccess.open(OUTPUT + config.run + ".json", FileAccess.WRITE)
	if file == null:
		push_error("Natural run report could not be written")
		quit(2)
		return
	file.store_string(JSON.stringify(report))
	file.close()
	print("NATURAL_RUN_COMPLETE run=%s valid=%s steps=%d terminal=%s" % [config.run, valid, samples.size(), terminal])
	quit(0 if valid else 2)
