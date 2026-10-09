extends SceneTree

var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NurseryMapTest " + message)

func _initialize() -> void:
	var path := "res://scripts/world/NurseryArenaLayout.gd"
	check(FileAccess.file_exists(path), "distinct nursery chapter map is absent")
	if failures > 0:
		quit(1)
		return
	var layout_script = load(path)
	check(layout_script != null and layout_script.can_instantiate(), "nursery layout failed to parse")
	if failures > 0:
		quit(1)
		return
	var layout = layout_script.new()
	root.add_child(layout)
	var fingerprints := {}
	for seed_value in [0, 1, 2, 3, 7, 13, 29, 97, 123, 521, 20261009, -1]:
		layout.generate_map(seed_value)
		var descriptors: Array[Dictionary] = layout.get_obstacle_descriptors()
		var fingerprint := str(descriptors)
		fingerprints[fingerprint] = true
		check(descriptors.size() >= 13 and descriptors.size() <= 20, "nursery cluster count outside design range")
		check(layout.is_position_walkable(Vector2.ZERO, 56), "spawn buffer not safe for every supported actor radius")
		check(layout.is_position_walkable(layout.BOSS_CENTER, 56), "Boss center blocked")
		for radius in [13.0, 14.0, 16.9, 24.0, 56.0]:
			for target in [layout.BOSS_CENTER, Vector2(-1120, 0), Vector2(1120, 0), Vector2(0, 680)]:
				check(layout.is_reachable(Vector2.ZERO, target, radius), "radius %s route to %s disconnected for seed %s" % [radius, target, seed_value])
		check(layout.get_child_count() == descriptors.size(), "visual/collider count differs from navigation descriptors")
		var kinds := {}
		for index in descriptors.size():
			var descriptor: Dictionary = descriptors[index]
			var rect: Rect2 = descriptor.rect
			kinds[descriptor.kind] = true
			check(layout.world_bounds.grow(-72).encloses(rect), "obstacle protrudes beyond arena margin")
			check(not rect.intersects(layout.SPAWN_BUFFER) and not rect.intersects(layout.BOSS_BUFFER), "obstacle invades spawn/Boss buffer")
			var obstacle: StaticBody2D = layout.get_child(index)
			var collision: CollisionShape2D = obstacle.get_node("CollisionShape2D")
			check(collision.shape is RectangleShape2D and collision.shape.size == rect.size, "collider does not match its complete visible footprint")
			check(Rect2(obstacle.position + collision.position - rect.size * 0.5, rect.size).is_equal_approx(rect), "collider pivot displaced navigation box")
			check(not layout.is_position_walkable(rect.get_center(), 13), "solid terrain ignored by navigation")
			check(obstacle.collision_layer & 1 != 0 and obstacle.is_in_group("arena_obstacles"), "real physics/group contract missing")
			check(obstacle.get_node("Art") is Node2D and not obstacle.get_node("Art") is Sprite2D, "old raster atlas substituted for new environment")
			obstacle.update_player_occlusion(obstacle.position - Vector2(0, rect.size.y), true, 1)
			check(is_equal_approx(obstacle.modulate.a, 1), "occlusion fades collision footprint/body")
			check(obstacle.get_node("Art").modulate.a < 1, "foreground decor does not yield to player")
			obstacle.update_player_occlusion(Vector2(9000, 9000), true, 1)
			check(is_equal_approx(obstacle.get_node("Art").modulate.a, 1), "decoration never returns to opaque")
			for other in descriptors.slice(index + 1):
				check(not rect.grow(64).intersects(other.rect), "route gap too narrow between nursery obstacles")
		check(kinds.has(&"seed_house") and kinds.has(&"plant_bed") and kinds.has(&"root_wall"), "distinct nursery scenery roles missing")
		layout.generate_map(seed_value)
		check(str(layout.get_obstacle_descriptors()) == fingerprint, "same seed changed nursery positions/sizes/roles")
		var exported: Array[Dictionary] = layout.get_obstacle_descriptors()
		exported[0].rect = Rect2()
		check(str(layout.get_obstacle_descriptors()) == fingerprint, "caller changed live terrain through export")
		await process_frame
	check(fingerprints.size() == 12, "different seeds did not produce distinct chapter maps")
	layout.queue_free()
	await process_frame
	if failures == 0:
		print("TEST PASS: NurseryMapTest %d" % assertions)
	quit(1 if failures > 0 else 0)
