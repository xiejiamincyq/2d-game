extends SceneTree

const Main = preload("res://scripts/Main.gd")
const Store = preload("res://scripts/systems/RunSnapshotStore.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const Support = preload("res://scripts/tests/TestSupport.gd")
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]
const TARGETS := [Vector2(-1120, 0), Vector2(1120, 0), Vector2(0, -680), Vector2(0, 680)]
const OUTPUT := "res://build/diagnostics/arena-runtime/"

class FixtureMain extends Main:
	func _ready() -> void:
		pass # The runner assigns the isolated store before any game startup.

var run_id := ""
var count := 20
var failed := false
var assertions := 0
var scene: Node
var view: SubViewport
var maps: Array[Dictionary] = []
var source_before: Dictionary
var saves_before: Dictionary
var orphan_before := 0
var evidence_dir := ""
var map_steps := 0

func _check(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failed = true
		push_error("TEST FAIL: ArenaRuntimeMatrix: " + message)
	return value

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() != 2 or pair[0] not in ["run", "count"]:
			quit(2)
			return
		if pair[0] == "run": run_id = pair[1]
		else: count = pair[1].to_int()
	if RegEx.create_from_string("^[A-Za-z0-9_-]{1,60}$").search(run_id) == null or count not in [1, 20]:
		quit(2)
		return
	evidence_dir = OUTPUT + run_id
	if DirAccess.dir_exists_absolute(evidence_dir) or DirAccess.make_dir_recursive_absolute(evidence_dir) != OK:
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute("user://arena-runtime/" + run_id) != OK:
		quit(2)
		return
	await process_frame
	saves_before = _save_hashes()
	source_before = _source_hashes()
	orphan_before = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	for index in range(count):
		await _measure_map(2026100401 + index)
		await _cleanup_scene()
		if failed: break
	await _finish()

func _measure_map(rng_seed: int) -> void:
	map_steps = 0
	_release_input()
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.disable_3d = true
	root.add_child(view)
	scene = FixtureMain.new()
	scene.audio_enabled = false
	view.add_child(scene)
	await process_frame
	scene.snapshot_store = Store.new()
	scene.snapshot_store.save_path = "user://arena-runtime/%s/run-%d.json" % [run_id, rng_seed]
	scene.add_child(scene.snapshot_store)
	seed(rng_seed)
	scene._build_world()
	scene._begin_run({})
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.set_process_input(false)
	scene.ui.process_mode = Node.PROCESS_MODE_DISABLED
	scene.player.advance_entrance(2.0)
	scene.player.set_process(false)
	scene.wave_director.set_process(false)
	scene.wave_director.set_physics_process(false)
	scene.portals.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	await physics_frame
	await process_frame
	var layout: ArenaLayout = scene.arena_layout
	var descriptors := layout.get_obstacle_descriptors()
	var rects: Array = []
	var collision_rects: Array = []
	for obstacle in layout.get_children():
		var shape: CollisionShape2D = obstacle.get_node("CollisionShape2D")
		collision_rects.append(_rect(Rect2(shape.global_position - shape.shape.size * 0.5, shape.shape.size)))
	for descriptor in descriptors:
		rects.append({"rect": _rect(descriptor.rect), "kind": String(descriptor.kind)})
	var row := {"rng_seed": rng_seed, "map_seed": scene.map_seed, "world_bounds": _rect(Main.WORLD_BOUNDS),
		"player_radius": scene.player.get_body_radius(), "move_speed": scene.player.move_speed,
		"descriptors": rects, "collision_rects": collision_rects, "probes": [], "spawns": [], "portals": [], "routes": []}
	maps.append(row)
	if not _check(descriptors.size() >= 9 and collision_rects.size() == descriptors.size(), "missing actual obstacles"): return
	if not _check(layout.map_seed == scene.map_seed and layout.generator_version == 2, "wrong live map binding"): return
	for i in range(descriptors.size()):
		var actual: Array = collision_rects[i]
		var expected: Array = rects[i].rect
		for axis in range(4):
			if not _check(absf(actual[axis] - expected[axis]) <= 0.0001, "collider differs from descriptor"): return
		scene.player.global_position = Vector2(descriptors[i].rect.position.x - row.player_radius - 8.0, descriptors[i].rect.get_center().y)
		await physics_frame
		await process_frame
		var start: Vector2 = scene.player.global_position
		var motion := Vector2(descriptors[i].rect.size.x + row.player_radius * 2 + 20, 0)
		var hit: KinematicCollision2D = scene.player.move_and_collide(motion, true)
		if not _check(hit != null and hit.get_collider() == layout.get_child(i), "live obstacle failed physical sweep"): return
		row.probes.append({"index": i, "collider_index": hit.get_collider().get_index(), "start": _point(start),
			"end": _point(scene.player.global_position), "motion": _point(motion), "travel": _point(hit.get_travel())})
	for kind in range(EnemyScript.EnemyKind.size()):
		scene.wave_director._spawn_enemy_at(kind, descriptors[0].rect.get_center())
		var enemy: Node2D = scene.wave_director.active_enemies.back()
		enemy.set_physics_process(false)
		enemy.set_process(false)
		await physics_frame
		await process_frame
		if not _check(enemy.arena_navigation == layout and layout.is_position_walkable(enemy.global_position, enemy.body_radius), "actual enemy spawn unsafe"): return
		row.spawns.append({"kind": EnemyScript.EnemyKind.keys()[kind], "position": _point(enemy.global_position),
			"radius": enemy.body_radius, "nav_shared": enemy.arena_navigation == layout})
		enemy.free()
	var boss: Node2D = scene.wave_director._spawn_boss_at(descriptors[0].rect.get_center())
	if not _check(boss != null, "actual boss spawn missing"): return
	boss.set_physics_process(false)
	boss.set_process(false)
	await physics_frame
	await process_frame
	if not _check(boss.arena_navigation == layout and layout.is_position_walkable(boss.global_position, boss.body_radius), "actual Boss spawn unsafe"): return
	row.spawns.append({"kind": "BOSS", "position": _point(boss.global_position), "radius": boss.body_radius, "nav_shared": boss.arena_navigation == layout})
	boss.free()
	scene.ui.hide_boss_health()
	scene.player.global_position = Vector2.ZERO # Reset obstacle-probe setup before normal first-wave sampling.
	scene.player.velocity = Vector2.ZERO
	await physics_frame
	await process_frame
	row["portal_player_start"] = _point(scene.player.global_position)
	scene.wave_director.spawn_rng.seed = rng_seed + 1000003
	row["portal_rng_seed"] = rng_seed + 1000003
	if not _check(scene.wave_director.begin_prepared_wave(), "actual first-wave portal startup failed"): return
	for portal in scene.wave_director.active_portals:
		row.portals.append(_point(portal.global_position))
		if not _check(layout.is_position_walkable(portal.global_position, 48), "actual portal inside terrain"): return
		if not _check(portal.global_position.distance_to(scene.player.global_position) >= 260 - 0.0001, "actual portal too close to initial player"): return
	for i in range(row.portals.size()):
		for j in range(i):
			if not _check(Vector2(row.portals[i][0], row.portals[i][1]).distance_to(Vector2(row.portals[j][0], row.portals[j][1])) >= 160 - 0.0001, "actual portals overlap safe separation"): return
	if not _check(row.portals.size() >= 3, "actual first-wave portals missing"): return
	scene.player.global_position = Vector2.ZERO # Explicit tour setup, never inside a route.
	scene.player.velocity = Vector2.ZERO
	if not _check(scene._transition_to(Main.RunState.PLAYING), "fixture could not enter PLAYING"): return
	await physics_frame
	await process_frame # Neutral real physics step releases the spawn-input guard.
	if not _check(not scene.player.spawn_input_guard_active and not scene.player.entrance_active, "input still guarded"): return
	for target in TARGETS:
		for goal in [target, Vector2.ZERO]:
			var path := _plan_route(scene.player.global_position, goal, row)
			if not _check(not path.is_empty(), "independent actual-collider route unavailable"): return
			var route := {"goal": _point(path.back()), "rows": []}
			row.routes.append(route)
			await _walk_route(path, route, row)
			if failed: return
	_release_input()
	scene.player.set_physics_process(false)
	if DisplayServer.get_name() != "headless":
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		scene.boss_camera_framing.set_process(false)
		scene.camera_effects.set_process(false)
		scene.ui.hide()
		var camera: Camera2D = view.get_camera_2d()
		camera.zoom = Vector2.ONE * 0.4
		camera.global_position = Vector2.ZERO
		camera.offset = Vector2.ZERO
		camera.rotation = 0
		camera.reset_smoothing()
		camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := view.get_texture().get_image()
		var path := evidence_dir + "/map-%02d.png" % (maps.size() - 1)
		if not _check(image != null and image.get_size() == view.size and _image_varies(image) and image.save_png(path) == OK, "native overview missing/flat/save failed"): return
		row["overview"] = {"path": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path),
			"scope": "isolated diagnostic 0.4x map overview with HUD hidden, not a normal gameplay screenshot"}
	print("ARENA_MATRIX_MAP run=%s rng=%d map=%d obstacles=%d" % [run_id, rng_seed, scene.map_seed, rects.size()])

func _image_varies(image: Image) -> bool:
	var first := image.get_pixel(0, 0)
	for y in range(0, image.get_height(), 32):
		for x in range(0, image.get_width(), 32):
			if image.get_pixel(x, y) != first: return true
	return false

func _plan_route(from: Vector2, target: Vector2, row: Dictionary) -> Array[Vector2]:
	# Independent four-neighbor BFS on the actual registered collider rectangles,
	# not ArenaLayout.is_reachable/flow_fields or a mere descriptor connectivity check.
	var bounds := Main.WORLD_BOUNDS
	var start := Vector2i((from - bounds.position) / 64.0)
	var goal := Vector2i((target - bounds.position) / 64.0)
	var frontier: Array[Vector2i] = [start]
	var parents := {start: start}
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == goal: break
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			var point := bounds.position + (Vector2(next) + Vector2.ONE * 0.5) * 64.0
			if parents.has(next) or not _point_clear(point, row.player_radius + 12, row): continue
			parents[next] = current
			frontier.append(next)
	var result: Array[Vector2] = []
	if not parents.has(goal): return result
	var current := goal
	while true:
		result.append(bounds.position + (Vector2(current) + Vector2.ONE * 0.5) * 64.0)
		if current == start: break
		current = parents[current]
	result.reverse()
	return result

func _point_clear(point: Vector2, radius: float, row: Dictionary) -> bool:
	if not Main.WORLD_BOUNDS.grow(-radius).has_point(point): return false
	for values in row.collision_rects:
		var rect := Rect2(values[0], values[1], values[2], values[3])
		var nearest := point.clamp(rect.position, rect.end)
		if point.distance_to(nearest) < radius - 0.0001: return false
	return true

func _set_movement(direction: Vector2) -> void:
	_release_input()
	if direction.x < 0: Input.action_press("move_left", -direction.x)
	if direction.x > 0: Input.action_press("move_right", direction.x)
	if direction.y < 0: Input.action_press("move_up", -direction.y)
	if direction.y > 0: Input.action_press("move_down", direction.y)

func _walk_route(path: Array[Vector2], route: Dictionary, row: Dictionary) -> void:
	for waypoint in path:
		while scene.player.global_position.distance_to(waypoint) > 4.8:
			if not _check(route.rows.size() < 3000 and map_steps < 12000, "route exhausted step budget; not reached"): return
			var before: Vector2 = scene.player.global_position
			var direction := (waypoint - before).normalized()
			_set_movement(direction)
			var actual := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			await physics_frame
			await process_frame
			var after: Vector2 = scene.player.global_position
			map_steps += 1
			route.rows.append({"before": _point(before), "after": _point(after), "input": _point(direction),
				"actual_input": _point(actual), "frame": Engine.get_physics_frames(), "delta": scene.player.get_physics_process_delta_time()})
			if not _check(_point_clear(after, row.player_radius, row), "actual Player entered terrain/outside world"): return
			if not _check(scene.run_state == Main.RunState.PLAYING and not scene.player.player_collision.disabled, "runtime/input state changed"): return
	_release_input()

func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _point(point: Vector2) -> Array:
	return [point.x, point.y]

func _release_input() -> void:
	for action in ACTIONS: Input.action_release(action)

func _save_hashes() -> Dictionary:
	var hashes := {}
	for path in [Store.DEFAULT_PATH, Main.HEADLESS_SNAPSHOT_PATH]:
		for suffix in ["", ".tmp", ".bak"]:
			hashes[path + suffix] = FileAccess.get_sha256(path + suffix) if FileAccess.file_exists(path + suffix) else "absent"
	return hashes

func _source_hashes() -> Dictionary:
	var hashes := {}
	for path in ["scripts/art/VerifyArenaRuntimeMatrix.gd", "scripts/art/check_arena_runtime_report.py", "scripts/Main.gd",
		"scripts/actors/Player.gd", "scripts/actors/Enemy.gd", "scripts/actors/OverseerBoss.gd", "scripts/systems/WaveDirector.gd",
		"scripts/systems/RunSnapshotStore.gd", "scripts/world/ArenaLayout.gd", "scripts/world/ArenaObstacle.gd", "scripts/world/SpawnPortal.gd",
		"scripts/systems/BossCameraFraming.gd", "scripts/systems/CombatView.gd", "scripts/world/TerrainSweep.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes

func _cleanup_scene() -> void:
	_release_input()
	paused = false
	if is_instance_valid(scene):
		scene.snapshot_store.clear_snapshot()
		Support.stop_audio(scene.audio)
	if is_instance_valid(view): view.queue_free()
	await process_frame
	await process_frame

func _finish() -> void:
	var after := _source_hashes()
	var orphan_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check(after == source_before and _save_hashes() == saves_before and orphan_after <= orphan_before, "source/save/orphan isolation changed")
	var seeds: Array = []
	for i in range(count): seeds.append(2026100401 + i)
	var file := FileAccess.open(evidence_dir + "/report.json", FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify({"valid": not failed, "run": run_id, "rng_seeds": seeds, "maps": maps, "assertions": assertions,
		"real_saves_before": saves_before, "real_saves_after": _save_hashes(), "source_sha256": source_before, "source_sha256_after": after,
		"orphan_before": orphan_before, "orphan_after": orphan_after, "display": DisplayServer.get_name(),
		"scope": "controlled runtime terrain fixture; battle timers frozen; not natural full runs/performance/human acceptance"}))
	file.close()
	print("ARENA_MATRIX_COMPLETE run=%s valid=%s maps=%d assertions=%d" % [run_id, not failed, maps.size(), assertions])
	quit(1 if failed else 0)
