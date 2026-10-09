extends SceneTree

const Player = preload("res://scripts/actors/Player.gd")
var assertions := 0
var failures := 0
var adjacent_moves := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NurseryMovementTest " + message)

func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]:
		Input.action_release(action)

func _tick(player: CharacterBody2D, direction: Vector2) -> void:
	_release()
	for axis in [["move_left", -direction.x], ["move_right", direction.x], ["move_up", -direction.y], ["move_down", direction.y]]:
		if axis[1] > 0:
			Input.action_press(axis[0], axis[1])
	var before := player.global_position
	await physics_frame
	await process_frame
	adjacent_moves += 1 if player.global_position.distance_to(before) > 0.01 else 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "res://scenes/world/mist_nursery.tscn"
	check(FileAccess.file_exists(path), "editable first-chapter map scene absent")
	if failures > 0:
		quit(1)
		return
	var scene_resource = load(path)
	var initial_hz := Engine.physics_ticks_per_second
	for case in [{"hz": 30, "seed": 0}, {"hz": 60, "seed": 521}, {"hz": 120, "seed": 20261009}]:
		Engine.physics_ticks_per_second = case.hz
		var map = scene_resource.instantiate()
		map.map_seed = case.seed
		root.add_child(map)
		var layout = map.get_node("Layout")
		var rect: Rect2 = layout.get_obstacle_descriptors()[0].rect
		var player := Player.new()
		player.world_bounds = layout.world_bounds
		player.position = Vector2(rect.position.x - 55, rect.get_center().y)
		map.add_child(player)
		await physics_frame
		await process_frame
		for step in ceili(case.hz * 0.65):
			await _tick(player, Vector2.RIGHT)
		check(player.global_position.x <= rect.position.x - player.get_body_radius() + 0.5, "%sHz real player passed through nursery collider" % case.hz)
		check(player.get_slide_collision_count() > 0, "straight input never encountered actual solid terrain")
		check(player.global_position.x > rect.position.x - 55, "player did not approach obstacle")
		var moves_before := adjacent_moves
		var waypoints: Array[Vector2] = [Vector2(rect.position.x - 55, rect.position.y - 60), Vector2(rect.end.x + 55, rect.position.y - 60), Vector2(rect.end.x + 55, rect.get_center().y)]
		# Ordinary movement around the box. No teleport, disabled collider, dash,
		# invulnerability, edited speed or direct pose/velocity updates after spawn.
		for target in waypoints:
			var reached := false
			for step in ceili(case.hz * 3):
				var delta: Vector2 = target - player.global_position
				if delta.length() < 10:
					reached = true
					break
				await _tick(player, delta.normalized())
				check(layout.is_position_walkable(player.global_position, player.get_body_radius() - 0.5), "normal route embeds player in terrain")
			check(reached, "%sHz normal player failed to walk around map obstacle to %s" % [case.hz, target])
		check(adjacent_moves > moves_before + 10, "input decisions counted as movement without adjacent position changes")
		_release()
		map.queue_free()
		await process_frame
	Engine.physics_ticks_per_second = initial_hz
	_release()
	if failures == 0:
		print("TEST PASS: NurseryMovementTest %d" % assertions)
	quit(1 if failures > 0 else 0)
