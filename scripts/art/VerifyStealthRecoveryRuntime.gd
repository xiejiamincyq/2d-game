extends SceneTree

# --fixed-fps 60 --resolution 1280x720 --write-movie <output>.avi
# Actual Player physics is sampled after each physics_frame + process_frame pair.
const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const ObstacleScript = preload("res://scripts/world/ArenaObstacle.gd")
const OUTPUT := "res://docs/art/previews/environment/stealth-recovery-runtime-v3"
const WALL := Rect2(80, -700, 20, 1400)
const START := Vector2(63.1, 0)
const ENEMY_POSITION := Vector2(30, 0)
const VIEW_SIZE := Vector2i(620, 540)
const DISPLAY_SCALE := 0.82
const STEPS := 120
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "dash_melee", "fire"]

class Trail extends Node2D:
	var points := PackedVector2Array([START])
	var radius := 0.0
	var enemy_radius := 0.0
	var guard_pending := false
	func _draw() -> void:
		draw_rect(WALL, Color("f27a4b"), false, 2.0)
		draw_arc(ENEMY_POSITION, enemy_radius, 0, TAU, 48, Color("8651ad"), 2.0, true)
		if points.size() > 1:
			draw_polyline(points, Color("1b737a"), 2.0, true)
		draw_circle(START, 4.0, Color("1b737a"))
		var tint := Color("dd9625") if guard_pending else Color("1b737a")
		draw_arc(points[-1], radius, 0, TAU, 48, tint, 3.0, true)

var canvas: SubViewport
var frames := 0

func _initialize() -> void:
	process_frame.connect(_watchdog)
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	seed(20261002)
	_release_input()
	AudioServer.set_bus_mute(0, true)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1280, 720)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var screen := TextureRect.new()
	screen.texture = canvas.get_texture()
	screen.size = Vector2(1280, 720)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(screen)
	var background := ColorRect.new()
	background.color = Color("d9e7dc")
	background.size = Vector2(1280, 720)
	canvas.add_child(background)
	_label("REAL INPUT / RESTORED BODY — UP 2 seconds, then DOWN 2 seconds / isolated fixtures", Vector2(12, 8), 22)
	var fixtures: Array[Dictionary] = []
	fixtures.append(await _make_fixture("up", Vector2.UP, 0))
	fixtures.append(await _make_fixture("down", Vector2.DOWN, 1))
	for _warmup in range(2):
		await physics_frame
		await process_frame
	var results: Array[Dictionary] = []
	for fixture in fixtures:
		results.append(await _run_case(fixture))
	var valid := results.all(func(item: Dictionary) -> bool: return item.sampling_valid)
	var defects := results.any(func(item: Dictionary) -> bool: return item.status == "confirmed_defect")
	var report := {
		"acceptance": "invalid_sampling" if not valid else ("needs_review" if defects else "scripted_checks_passed"),
		"engine": Engine.get_version_info().string,
		"source_sha256": {
			"Player.gd": FileAccess.get_sha256("res://scripts/actors/Player.gd"),
			"TerrainSweep.gd": FileAccess.get_sha256("res://scripts/world/TerrainSweep.gd"),
			"StealthRecoveryMotion.gd": FileAccess.get_sha256("res://scripts/world/StealthRecoveryMotion.gd"),
			"VerifyStealthRecoveryRuntime.gd": FileAccess.get_sha256("res://scripts/art/VerifyStealthRecoveryRuntime.gd")},
		"physics_hz": 60, "steps_per_case": STEPS, "display_scale": DISPLAY_SCALE,
		"movie_mode": OS.has_feature("movie"), "cases": results,
		"limitations": "Forced overlap component evidence: real Player/Input, real frozen BRUISER, separate World2D, sequential opposite inputs. clear_runtime_modifiers triggers recovery; this is not natural full-game encounter, performance, AI or art acceptance. No Main, saves, audio, firing or dash.",
	}
	_label("Gold ring: guard pending / teal: released + measured path / orange: wall / purple: enemy body / 0.82x", Vector2(12, 695), 16)
	for _hold in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := canvas.get_texture().get_image()
	var png_ok := capture != null and not capture.is_empty() and capture.save_png(ProjectSettings.globalize_path(OUTPUT + ".png")) == OK
	report["final_png_saved"] = png_ok
	report["process_frames"] = frames
	var file := FileAccess.open(OUTPUT + ".json", FileAccess.WRITE)
	if file == null:
		push_error("Stealth recovery report write failed")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("STEALTH RECOVERY RUNTIME: ", report.acceptance, " / ", OUTPUT)
	quit(0 if valid and not defects and png_ok else 2)

func _make_fixture(id: String, direction: Vector2, index: int) -> Dictionary:
	var origin := Vector2(12 + index * 636, 43)
	var title := _label("%02d %s / waiting (stealth, physics frozen)" % [index + 1, id.to_upper()], origin, 19)
	var holder := SubViewportContainer.new()
	holder.position = origin + Vector2(0, 27)
	holder.size = Vector2(VIEW_SIZE)
	canvas.add_child(holder)
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(view)
	await process_frame
	view.canvas_transform = Transform2D(Vector2(DISPLAY_SCALE, 0), Vector2(0, DISPLAY_SCALE), Vector2(270, 480 if direction.y < 0 else 60))
	var floor_patch := Polygon2D.new()
	floor_patch.polygon = PackedVector2Array([Vector2(-1000, -1000), Vector2(1000, -1000), Vector2(1000, 1000), Vector2(-1000, 1000)])
	floor_patch.color = Color("ecf0de")
	view.add_child(floor_patch)
	var obstacle := ObstacleScript.new()
	obstacle.setup(WALL, &"pipe")
	view.add_child(obstacle)
	var player := PlayerScript.new()
	player.position = START
	view.add_child(player)
	# Script callbacks are enabled during tree entry; freeze only after _ready.
	if not player.is_node_ready():
		await player.ready
	player.set_physics_process(false)
	var enemy := EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.BRUISER, 0, view, player)
	enemy.position = ENEMY_POSITION
	view.add_child(enemy)
	if not enemy.is_node_ready():
		await enemy.ready
	enemy.set_physics_process(false)
	var enemies: Array[Node] = [enemy]
	player.set_enemy_provider(func() -> Array[Node]: return enemies)
	player._activate_assassin_stealth()
	view.notify_mouse_entered()
	var mouse := InputEventMouseMotion.new()
	mouse.position = view.canvas_transform * (START + direction * 1000.0)
	view.push_input(mouse, true)
	var trail := Trail.new()
	trail.radius = player.get_body_radius()
	trail.enemy_radius = enemy.body_radius
	trail.z_index = 10
	view.add_child(trail)
	return {"id": id, "direction": direction, "view": view, "player": player, "enemy": enemy, "trail": trail,
		"samples": [], "first_guard_release": 0, "title_label": title,
		"progress_label": _label("Waiting for this fixture's real input...", origin + Vector2(0, 577), 16),
		"body_label": _label("", origin + Vector2(0, 598), 15),
		"guard_label": _label("", origin + Vector2(0, 619), 15)}

func _run_case(fixture: Dictionary) -> Dictionary:
	_release_input()
	var player: PlayerScript = fixture.player
	var before_clear := _state(player)
	var preconditions := _fixture_preconditions(fixture)
	if not preconditions.values().all(func(passed: bool) -> bool: return passed):
		fixture.title_label.text = "%s / INVALID FIXTURE — input not started" % fixture.id.to_upper()
		fixture.progress_label.text = "Frozen/initial-state prerequisite failed; see JSON."
		fixture.progress_label.add_theme_color_override("font_color", Color("b32720"))
		push_error("Stealth recovery fixture prerequisites failed: %s %s" % [fixture.id, preconditions])
		return {"id": fixture.id, "status": "invalid_sampling", "sampling_valid": false,
			"fixture_preconditions": preconditions, "before_clear_state": before_clear, "samples": []}
	fixture["preconditions"] = preconditions
	fixture.title_label.text = "%s / clear_runtime_modifiers + REAL INPUT" % fixture.id.to_upper()
	player.clear_runtime_modifiers()
	var restore_request := _state(player)
	fixture.trail.guard_pending = player.stealth_recovery_pending
	fixture.trail.queue_redraw()
	var action := "move_up" if fixture.direction.y < 0 else "move_down"
	Input.action_press(action)
	player.set_physics_process(true)
	var first_frame := Engine.get_physics_frames()
	var previous_frame := first_frame
	for step in range(STEPS):
		await physics_frame
		var before_physics := _state(player)
		await process_frame
		var current_frame := Engine.get_physics_frames()
		_sample(fixture, step + 1, current_frame - previous_frame, before_physics)
		previous_frame = current_frame
	_release_input()
	player.set_physics_process(false)
	player.set_process(false)
	return _result(fixture, before_clear, restore_request, previous_frame - first_frame)

func _sample(fixture: Dictionary, step: int, frame_delta: int, before_physics: Dictionary) -> void:
	var player: PlayerScript = fixture.player
	var state := _state(player)
	var point := player.global_position
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var trace: Dictionary = player.stealth_recovery_trace.duplicate(true)
	# This is a read-only engine proposal, never an actual intermediate position.
	var recovery_proposal: Vector2 = trace.start + trace.recovery_requested if not trace.is_empty() else point
	var proposal_penetration := _penetration(recovery_proposal, player.get_body_radius())
	var gap: float = point.distance_to(fixture.enemy.global_position) - player.get_body_radius() - fixture.enemy.body_radius
	var screen_point: Vector2 = fixture.view.canvas_transform * point
	var margin := Vector2.ONE * 60.0 * DISPLAY_SCALE
	state.merge({"step": step, "physics_frame": Engine.get_physics_frames(), "physics_frame_delta": frame_delta,
		"pre_player_physics_state": before_physics,
		"enemy_physics_processing": fixture.enemy.is_physics_processing(),
		"enemy_at_initial_position": fixture.enemy.global_position.distance_to(ENEMY_POSITION) < 0.001,
		"physics_delta": player.get_physics_process_delta_time(), "input": [input.x, input.y],
		"signed_progress": (point - START).dot(fixture.direction), "terrain_penetration": _penetration(point, player.get_body_radius()),
		"readonly_recovery_proposal_penetration": proposal_penetration, "enemy_gap": gap, "entity_overlap_geometric": gap < 0.0,
		"actor_with_margin_visible": screen_point.x >= margin.x and screen_point.y >= margin.y and screen_point.x <= VIEW_SIZE.x - margin.x and screen_point.y <= VIEW_SIZE.y - margin.y,
		"stealth_recovery_trace": _serialize_trace(trace)})
	fixture.samples.append(state)
	fixture.trail.points.append(point)
	fixture.trail.guard_pending = player.stealth_recovery_pending
	fixture.trail.queue_redraw()
	if not player.stealth_recovery_pending and fixture.first_guard_release == 0:
		fixture.first_guard_release = step
	fixture.progress_label.text = "%s step %03d / %03d | progress %.2f px | enemy gap %.2f px" % [fixture.id.to_upper(), step, STEPS, state.signed_progress, gap]
	fixture.body_label.text = "Stealth %.3f s | layer %d mask %d | shape disabled: %s" % [state.stealth_remaining, state.layer, state.mask, state.shape_disabled]
	fixture.guard_label.text = "Guard %s (off @ %d) | intrusion %.4f / R proposal %.4f" % [state.guard_pending, fixture.first_guard_release, state.terrain_penetration, proposal_penetration]

func _result(fixture: Dictionary, before: Dictionary, request: Dictionary, steps: int) -> Dictionary:
	var player: PlayerScript = fixture.player
	var valid: bool = steps == STEPS and fixture.samples.size() == STEPS and before.stealthed and before.shape_disabled and before.layer == 0 and before.mask == 0
	valid = valid and Vector2(before.position[0], before.position[1]).distance_to(START) < 0.001 and request.guard_pending
	var initial_gap: float = START.distance_to(fixture.enemy.position) - player.get_body_radius() - fixture.enemy.body_radius
	valid = valid and initial_gap < 0.0 and not fixture.enemy.is_physics_processing()
	var max_penetration := 0.0
	var max_proposal_penetration := 0.0
	var first_separated := 0
	var first_restored := 0
	var first_enabled_physics := 0
	var trace_steps := 0
	var recovery_constrained_steps := 0
	var body_contract: bool = is_zero_approx(request.stealth_remaining) and request.layer == player.normal_collision_layer and request.mask == player.normal_collision_mask
	var released_stays_off := true
	var path: Array = [before.position]
	for sample: Dictionary in fixture.samples:
		valid = valid and sample.physics_frame_delta == 1 and absf(sample.physics_delta - 1.0 / 60.0) < 0.000001
		valid = valid and not sample.enemy_physics_processing and sample.enemy_at_initial_position
		valid = valid and Vector2(sample.input[0], sample.input[1]).is_equal_approx(fixture.direction) and not sample.dash_active and sample.actor_with_margin_visible
		body_contract = body_contract and is_zero_approx(sample.stealth_remaining) and (sample.step <= 1 or (sample.body_restored and sample.pre_player_physics_state.body_restored))
		if first_restored == 0 and sample.body_restored:
			first_restored = sample.step
		if first_enabled_physics == 0 and sample.pre_player_physics_state.body_restored:
			first_enabled_physics = sample.step
		if first_separated == 0 and sample.body_restored and sample.enemy_gap > 0.1:
			first_separated = sample.step
		if sample.step >= fixture.first_guard_release and fixture.first_guard_release > 0:
			released_stays_off = released_stays_off and not sample.guard_pending
		max_penetration = maxf(max_penetration, sample.terrain_penetration)
		max_proposal_penetration = maxf(max_proposal_penetration, sample.readonly_recovery_proposal_penetration)
		var trace: Dictionary = sample.stealth_recovery_trace
		trace_steps += 0 if trace.is_empty() else 1
		recovery_constrained_steps += 1 if trace.get("recovery_changed", false) else 0
		path.append(sample.position)
	var last: Dictionary = fixture.samples[-1]
	var escaped: bool = first_separated > 0 and first_separated < STEPS - 3 and last.enemy_gap > 0.1 and last.signed_progress > PlayerScript.BASE_MOVE_SPEED
	var guard_released: bool = fixture.first_guard_release > 0 and fixture.first_guard_release < STEPS - 3 and not last.guard_pending and released_stays_off
	var defect := max_penetration > 0.1 or not body_contract or not escaped or not guard_released or trace_steps == 0
	var status := "invalid_sampling" if not valid else ("confirmed_defect" if defect else "scripted_checks_passed")
	fixture.title_label.text = "%s / FINISHED — physics frozen for comparison" % fixture.id.to_upper()
	fixture.progress_label.text = "%s / %s / progress %.2f px" % [fixture.id.to_upper(), status, last.signed_progress]
	fixture.progress_label.add_theme_color_override("font_color", Color("b32720") if not valid or defect else Color("123b3b"))
	return {"id": fixture.id, "status": status, "sampling_valid": valid, "seconds": float(steps) / 60.0,
		"fixture_preconditions": fixture.preconditions,
		"start": before.position, "end": last.position, "wall": [80, -700, 20, 1400], "enemy": [30, 0],
		"player_radius": player.get_body_radius(), "enemy_radius": fixture.enemy.body_radius, "initial_enemy_gap": initial_gap, "enemy_physics_frozen": not fixture.enemy.is_physics_processing(),
		"before_clear_state": before, "restore_requested_state": request, "final_state": _state(player),
		"samples": fixture.samples, "path": path, "max_terrain_penetration": max_penetration, "max_readonly_recovery_proposal_penetration": max_proposal_penetration,
		"first_body_restored_step": first_restored, "first_enabled_body_physics_step": first_enabled_physics,
		"first_separated_step": first_separated, "first_guard_release_step": fixture.first_guard_release,
		"trace_steps": trace_steps, "recovery_constrained_steps": recovery_constrained_steps, "body_not_extended": body_contract,
		"escaped": escaped, "guard_released_and_stays_off": guard_released}

func _state(player: PlayerScript) -> Dictionary:
	return {"position": [player.position.x, player.position.y], "velocity": [player.velocity.x, player.velocity.y],
		"physics_processing": player.is_physics_processing(),
		"layer": player.collision_layer, "mask": player.collision_mask, "shape_disabled": player.player_collision.disabled,
		"body_restored": player.collision_layer == player.normal_collision_layer and player.collision_mask == player.normal_collision_mask and not player.player_collision.disabled,
		"stealthed": player.is_stealthed(), "stealth_remaining": player.stealth_remaining, "dash_active": player.dash_active,
		"guard_pending": player.stealth_recovery_pending}

func _fixture_preconditions(fixture: Dictionary) -> Dictionary:
	var player: PlayerScript = fixture.player
	return {"player_ready": player.is_node_ready(), "enemy_ready": fixture.enemy.is_node_ready(),
		"player_physics_frozen": not player.is_physics_processing(),
		"enemy_physics_frozen": not fixture.enemy.is_physics_processing(),
		"player_at_initial_position": player.global_position.distance_to(START) < 0.001,
		"enemy_at_initial_position": fixture.enemy.global_position.distance_to(ENEMY_POSITION) < 0.001,
		"stealth_time_unchanged_while_waiting": absf(player.stealth_remaining - PlayerScript.ASSASSIN_STEALTH_SECONDS) < 0.000001,
		"stealth_body_disabled": player.is_stealthed() and player.collision_layer == 0 and player.collision_mask == 0 and player.player_collision.disabled,
		"waiting_guard_inactive": not player.stealth_recovery_pending,
		"initial_enemy_overlap": player.global_position.distance_to(fixture.enemy.global_position) < player.get_body_radius() + fixture.enemy.body_radius}

func _serialize_trace(trace: Dictionary) -> Dictionary:
	return _json_value(trace)

func _json_value(value: Variant) -> Variant:
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var serialized: Dictionary = {}
		for key in value:
			serialized[key] = _json_value(value[key])
		return serialized
	if value is Array:
		var serialized: Array = []
		for entry in value:
			serialized.append(_json_value(entry))
		return serialized
	return value

func _penetration(point: Vector2, radius: float) -> float:
	return maxf(0.0, radius - point.distance_to(point.clamp(WALL.position, WALL.end)))

func _label(value: String, position: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("123b3b"))
	canvas.add_child(label)
	return label

func _release_input() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func _watchdog() -> void:
	frames += 1
	if frames >= 1200:
		_release_input()
		push_error("Stealth recovery capture exceeded the 1200-frame safety limit")
		quit(3)
