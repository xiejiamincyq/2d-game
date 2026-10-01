extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const ObstacleScript = preload("res://scripts/world/ArenaObstacle.gd")
const OUTPUT := "res://docs/art/previews/environment/dash-terrain-runtime"
const WALL := Rect2(80, -100, 20, 200)
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "dash_melee", "fire"]
const CASES := [
	{"id": "normal_dash", "title": "01 Normal dash / wall", "start": Vector2.ZERO, "direction": Vector2.RIGHT},
	{"id": "stealth_dash", "title": "02 Stealth dash / wall", "start": Vector2.ZERO, "direction": Vector2.RIGHT, "stealth": true},
	{"id": "enemy_then_wall", "title": "03 Enemy before wall", "start": Vector2.ZERO, "direction": Vector2.RIGHT, "enemy": true},
	{"id": "leave_wall", "title": "04 Touching wall / leave", "start": Vector2(63.0, 0), "direction": Vector2.LEFT},
	{"id": "oblique_dash", "title": "05 Oblique dash / wall", "start": Vector2(0, -70), "direction": Vector2(1, 1)},
	{"id": "stealth_walk", "title": "06 Stealth WALK / 60 steps", "start": Vector2.ZERO, "direction": Vector2.RIGHT, "stealth": true, "walk": true},
]

class Trail extends Node2D:
	var points := PackedVector2Array()
	var radius := 0.0
	func _draw() -> void:
		draw_rect(WALL, Color("f27a4b"), false, 2.0)
		if points.size() < 2:
			return
		draw_polyline(points, Color("1b737a"), 2.0, true)
		draw_circle(points[0], 4.0, Color("1b737a"))
		draw_arc(points[-1], radius, 0, TAU, 32, Color("f27a4b"), 2.0, true)
		var direction := (points[-1] - points[0]).normalized()
		var side := direction.orthogonal()
		draw_line(points[-1], points[-1] - direction * 11 + side * 5, Color("1b737a"), 2.0, true)
		draw_line(points[-1], points[-1] - direction * 11 - side * 5, Color("1b737a"), 2.0, true)

var canvas: SubViewport
var results: Array[Dictionary] = []

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	seed(20261002)
	_release_input()
	canvas = SubViewport.new()
	canvas.size = Vector2i(1280, 720)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("d9e7dc")
	background.size = Vector2(1280, 720)
	canvas.add_child(background)
	_label("REAL INPUT / DASH TERRAIN — isolated fixtures, not art or gameplay acceptance", Vector2(16, 8), 21)
	for index in range(CASES.size()):
		results.append(await _run_case(CASES[index], index))
	var valid := results.all(func(result: Dictionary) -> bool: return result["sampling_valid"])
	var defects := results.filter(func(result: Dictionary) -> bool: return result["status"] == "confirmed_defect")
	var report := {
		"acceptance": "invalid_sampling" if not valid else ("needs_review" if not defects.is_empty() else "scripted_checks_passed"),
		"physics_hz": 60, "wall_rect": [80, -100, 20, 200], "cases": results,
		"limitations": "Real Input actions and physics; separate World2D per case; fixed fixtures and frozen enemy; no Main, saves or audio; not human playtesting or a performance claim. Baseline flag changes output name only.",
	}
	var suffix := "-baseline-v1" if OS.get_cmdline_user_args().has("--baseline") else "-v1"
	_label("Teal = sampled path / orange = wall + final body circle / red status = confirmed defect", Vector2(16, 685), 17)
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := canvas.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.save_png(ProjectSettings.globalize_path(OUTPUT + suffix + ".png")) != OK:
		push_error("Dash terrain runtime capture failed")
		_finish(1)
		return
	var file := FileAccess.open(OUTPUT + suffix + ".json", FileAccess.WRITE)
	if file == null:
		push_error("Dash terrain runtime report write failed")
		_finish(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("DASH TERRAIN RUNTIME REPORT: ", JSON.stringify(report))
	_finish(0 if valid and defects.is_empty() else 2)

func _run_case(config: Dictionary, index: int) -> Dictionary:
	var origin := Vector2(12 + (index % 3) * 424, 46 + (index / 3) * 316)
	_label(config["title"], origin, 19)
	var holder := SubViewportContainer.new()
	holder.position = origin + Vector2(0, 27)
	holder.size = Vector2(412, 238)
	canvas.add_child(holder)
	var view := SubViewport.new()
	view.size = Vector2i(412, 238)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var camera_offset := Vector2(156 if config["id"] == "leave_wall" else (50 if config.get("walk", false) else 118), 119)
	holder.add_child(view)
	await process_frame
	view.canvas_transform = Transform2D(0.0, camera_offset)
	var floor_patch := Polygon2D.new()
	floor_patch.polygon = PackedVector2Array([Vector2(-500, -300), Vector2(500, -300), Vector2(500, 300), Vector2(-500, 300)])
	floor_patch.color = Color("ecf0de")
	view.add_child(floor_patch)
	var obstacle := ObstacleScript.new()
	obstacle.setup(WALL, &"pipe")
	view.add_child(obstacle)
	var player := PlayerScript.new()
	player.position = config["start"]
	player.begin_spawn_input_guard()
	view.add_child(player)
	var enemies: Array[Node] = []
	if config.get("enemy", false):
		var enemy := EnemyScript.new()
		enemy.setup(EnemyScript.EnemyKind.BRUISER, 0, view, player)
		enemy.position = Vector2(45, 0)
		enemy.set_physics_process(false)
		view.add_child(enemy)
		enemies.append(enemy)
	player.set_enemy_provider(func() -> Array[Node]: return enemies)
	_release_input()
	await physics_frame
	await process_frame
	if config.get("stealth", false):
		player._activate_assassin_stealth()
	await physics_frame
	await process_frame
	var initial_state := _collision_state(player)
	var start: Vector2 = player.global_position
	var path := PackedVector2Array([start])
	var travelled := 0.0
	var penetration := 0.0
	var crossed := false
	var triggered := false
	var samples := 0
	var walk: bool = config.get("walk", false)
	var steps := 60 if walk else 12
	var health_before := 0.0 if enemies.is_empty() else float(enemies[0].health.current_health)
	var physics_start := Engine.get_physics_frames()
	_drive(config["direction"])
	if not walk:
		Input.action_press("dash_melee")
	for frame in range(steps):
		await physics_frame
		await process_frame
		samples += 1
		var point: Vector2 = player.global_position
		travelled += path[-1].distance_to(point)
		path.append(point)
		triggered = triggered or player.dash_active or player.dash_cooldown_remaining > 0.0
		penetration = maxf(penetration, player.get_body_radius() - point.distance_to(point.clamp(WALL.position, WALL.end)))
		crossed = crossed or (point.x >= WALL.end.x and point.y >= WALL.position.y and point.y <= WALL.end.y)
		if not walk and frame == 0:
			_release_input()
		if not walk and triggered and not player.dash_active:
			break
	_release_input()
	var elapsed_frames := Engine.get_physics_frames() - physics_start
	player.set_physics_process(false)
	player.set_process(false)
	var valid := elapsed_frames == samples and (not triggered and samples == 60 if walk else triggered and not player.dash_active)
	if config.get("stealth", false):
		valid = valid and initial_state["layer"] == 0 and initial_state["mask"] == 0 and initial_state["shape_disabled"]
	var enemy_damage := 0.0 if enemies.is_empty() else health_before - float(enemies[0].health.current_health)
	var contact_x: float = WALL.position.x - player.get_body_radius()
	var expected_motion := travelled > 160.0 if config["id"] == "leave_wall" else absf(player.global_position.x - contact_x) <= 1.0
	if not enemies.is_empty():
		expected_motion = expected_motion and enemy_damage > 0.0 and enemy_damage <= player.dash_melee_damage + 0.01
	var defect := penetration > 1.0 or crossed or (not walk and not expected_motion)
	var status := "invalid_sampling" if not valid else ("confirmed_defect" if defect else "scripted_checks_passed")
	var trail := Trail.new()
	trail.points = path
	trail.radius = player.get_body_radius()
	trail.z_index = 10
	view.add_child(trail)
	var tint := Color("b32720") if defect or not valid else Color("123b3b")
	_label("%s / %.1f px / dash: %s" % [status, travelled, triggered], origin + Vector2(0, 269), 14, tint)
	_label("layer %d / mask %d / shape disabled: %s" % [player.collision_layer, player.collision_mask, player.player_collision.disabled], origin + Vector2(0, 287), 14)
	var serialized_path: Array = []
	for point in path:
		serialized_path.append([point.x, point.y])
	return {
		"id": config["id"], "status": status, "start": [start.x, start.y], "end": serialized_path.back(),
		"path": serialized_path, "travelled_pixels": travelled, "maximum_steps": steps, "sample_steps": samples, "physics_steps": elapsed_frames,
		"sampling_valid": valid, "dash_triggered": triggered, "wall_crossed": crossed, "maximum_penetration_pixels": penetration,
		"initial_collision_state": initial_state, "final_collision_state": _collision_state(player),
		"enemy_damage": enemy_damage, "expected_dash_motion": expected_motion if not walk else null,
	}

func _collision_state(player: Node) -> Dictionary:
	return {"layer": player.collision_layer, "mask": player.collision_mask, "shape_disabled": player.player_collision.disabled, "stealthed": player.is_stealthed()}

func _drive(direction: Vector2) -> void:
	for action in ACTIONS:
		Input.action_release(action)
	if direction.x != 0.0:
		Input.action_press("move_right" if direction.x > 0.0 else "move_left", absf(direction.x))
	if direction.y != 0.0:
		Input.action_press("move_down" if direction.y > 0.0 else "move_up", absf(direction.y))

func _label(value: String, position: Vector2, size: int, tint := Color("123b3b")) -> void:
	var label := Label.new()
	label.text = value
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	canvas.add_child(label)

func _release_input() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func _finish(code: int) -> void:
	_release_input()
	canvas.queue_free()
	await process_frame
	await process_frame
	quit(code)
