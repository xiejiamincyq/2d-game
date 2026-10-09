extends SceneTree
## Isolated ordinary-input combat proof; not Main launch or human playtest.

const Map = preload("res://scenes/world/mist_nursery.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/NurseryEncounterDirector.gd")
const Policy = preload("res://scripts/art/NaturalRunPolicy.gd")
const OUTPUT := "res://docs/art/previews/campaign/nursery-encounter-input-v3"
const FRAMES := "res://build/diagnostics/campaign-goal/nursery-encounter-input-frames-v3/"
var assertions := 0
var failures := 0
var shots := 0
var kills := 0
var adjacent_moves := 0
var samples: Array[Dictionary] = []
var terrain_witnesses: Array[Dictionary] = []

static func has_body_clearance(point: Vector2, bounds: Rect2, obstacles: Array[Dictionary], radius: float) -> bool:
	# Actual circle-vs-rectangle clearance, not the navigation grid's expanded box.
	# 0.05px permits floating-point contact jitter, not square-corner intrusion.
	var margin := radius - 0.05
	if point.x < bounds.position.x + margin or point.x > bounds.end.x - margin or point.y < bounds.position.y + margin or point.y > bounds.end.y - margin:
		return false
	for descriptor in obstacles:
		var rect: Rect2 = descriptor.rect
		if point.distance_to(point.clamp(rect.position, rect.end)) < margin:
			return false
	return true

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyNurseryEncounterRun " + message)

func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]:
		Input.action_release(action)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(DisplayServer.get_name() != "headless", "GPU proof needs real rendering driver")
	check(not FileAccess.file_exists(OUTPUT + ".json") and not DirAccess.dir_exists_absolute(FRAMES), "existing evidence must not be overwritten")
	if failures > 0:
		quit(1)
		return
	var sources := {}
	for path in ["scripts/systems/NurseryEncounterDirector.gd", "scripts/systems/WaveDirector.gd", "scripts/art/VerifyNurseryEncounterRun.gd", "scripts/art/NaturalRunPolicy.gd", "scripts/actors/Player.gd", "scripts/actors/Enemy.gd", "scripts/systems/UpgradeSystem.gd", "scenes/world/mist_nursery.tscn", "scripts/world/NurseryMap.gd", "scripts/world/NurseryArenaLayout.gd", "scripts/world/NurseryFloor.gd", "scripts/world/NurseryObstacle.gd", "scripts/world/NurseryPropArt.gd"]:
		sources[path] = FileAccess.get_sha256("res://" + path)
	_release()
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.notify_mouse_entered()
	var map = Map.instantiate()
	map.map_seed = 521
	view.add_child(map)
	var enemies := Node2D.new()
	enemies.y_sort_enabled = true
	var projectiles := Node2D.new()
	projectiles.z_index = 8
	var portals := Node2D.new()
	for layer in [enemies, projectiles, portals]:
		map.add_child(layer)
	var player := Player.new()
	player.world_bounds = map.layout.world_bounds
	player.projectile_parent = projectiles
	map.add_child(player)
	map.layout.occlusion_target = player
	var camera := Camera2D.new()
	player.add_child(camera)
	player.fired.connect(func(projectile: Node) -> void:
		shots += 1
		projectile.world_bounds = map.layout.world_bounds
		projectiles.add_child(projectile)
	)
	var growth := Growth.new()
	map.add_child(growth)
	growth.setup(player)
	var director := Director.new()
	map.add_child(director)
	director.enemy_killed.connect(func(_enemy: Node, _source: StringName, _coins: int) -> void: kills += 1)
	check(director.start_run(521, player, enemies, projectiles, portals, growth, map.layout), "actual encounter refused")
	player.set_enemy_provider(director.get_active_enemies)
	player.begin_spawn_input_guard()
	player.begin_entrance()
	var overlay := CanvasLayer.new()
	view.add_child(overlay)
	var label := Label.new()
	label.position = Vector2(20, 16)
	label.add_theme_font_override("font", preload("res://themes/MintFarmTheme.tres").default_font)
	label.add_theme_font_size_override("font_size", 20)
	overlay.add_child(label)
	var policy := Policy.new(20261009)
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES)) == OK, "frame directory failed")
	for step in 600:
		_release()
		if director.state == director.State.INTRO and not player.is_entrance_active():
			check(director.begin_encounter(), "natural player entrance did not release combat")
		if director.state == director.State.FAILED:
			break
		if director.state == director.State.COMBAT:
			var threats: Array[Vector2] = []
			var nearest := Vector2.ZERO
			var distance := INF
			for enemy in director.get_active_enemies():
				if not is_instance_valid(enemy) or enemy.health.current_health <= 0:
					continue
				threats.append(enemy.global_position)
				if player.global_position.distance_squared_to(enemy.global_position) < distance:
					distance = player.global_position.distance_squared_to(enemy.global_position)
					nearest = enemy.global_position
			var direction := policy.choose_direction(player.position, Vector2.RIGHT.rotated(step / 90.0) * 180, threats, func(point: Vector2) -> bool: return map.layout.is_position_walkable(point, player.get_body_radius()))
			for axis in [["move_left", -direction.x], ["move_right", direction.x], ["move_up", -direction.y], ["move_down", direction.y]]:
				if axis[1] > 0:
					Input.action_press(axis[0], axis[1])
			var mouse := InputEventMouseMotion.new()
			mouse.position = view.get_canvas_transform() * policy.nonzero_aim(player.position, nearest)
			view.push_input(mouse, true)
			Input.action_press("fire")
		var before := player.position
		await physics_frame
		await process_frame
		adjacent_moves += 1 if player.position.distance_to(before) > 0.01 else 0
		var walkable: bool = map.layout.is_position_walkable(player.position, player.get_body_radius() - 0.5)
		if not walkable:
			var gap := INF
			for descriptor in map.layout.get_obstacle_descriptors():
				var rect: Rect2 = descriptor.rect
				gap = minf(gap, player.position.distance_to(player.position.clamp(rect.position, rect.end)) - player.get_body_radius())
			terrain_witnesses.append({"step": step, "position": [player.position.x, player.position.y], "circle_gap": gap})
		check(has_body_clearance(player.position, map.layout.world_bounds, map.layout.get_obstacle_descriptors(), player.get_body_radius()), "ordinary player circle penetrated terrain/bounds")
		label.text = "隔离首关普通输入 · 非Main/真人试玩 · 过渡玩家/吐弹怪    HP %.0f / 击杀 %d" % [player.health.current_health, kills]
		if step % 30 == 0:
			await RenderingServer.frame_post_draw
			var path := FRAMES + "frame_%03d.png" % samples.size()
			check(view.get_texture().get_image().save_png(path) == OK, "GPU frame save failed")
			samples.append({"step": step, "physics_frame": Engine.get_physics_frames(), "wall_usec": Time.get_ticks_usec(), "position": [player.position.x, player.position.y], "health": player.health.current_health, "alive_enemies": director.get_active_enemies().size(), "shots": shots, "kills": kills, "state": Director.State.keys()[director.state], "file": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path)})
			if samples.size() == 10:
				check(view.get_texture().get_image().save_png(OUTPUT + ".png") == OK, "preview save failed")
	_release()
	check(adjacent_moves > 200 and shots > 5 and kills > 0 and player.health.current_health > 0, "ordinary encounter input proof failed")
	for path in sources:
		check(FileAccess.get_sha256("res://" + path) == sources[path], "source changed during GPU probe")
	var report := {"scope": "Isolated real nursery map/director/player/enemies and ordinary input; not Main, Boss clear, saved unlock, human playtest or final all-new art", "valid": failures == 0, "assertions": assertions, "sources": sources, "adjacent_moves": adjacent_moves, "shots": shots, "kills": kills, "policy_random_heading_changes": policy.random_heading_changes, "terrain_witnesses": terrain_witnesses, "samples": samples}
	var file := FileAccess.open(OUTPUT + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	view.queue_free()
	await process_frame
	if failures == 0:
		print("TEST PASS: VerifyNurseryEncounterRun %d" % assertions)
	quit(1 if failures > 0 else 0)
