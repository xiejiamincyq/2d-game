extends SceneTree

const Map = preload("res://scenes/world/mist_nursery.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Prop = preload("res://scripts/world/NurseryObstacle.gd")
const DIR := "res://docs/art/previews/campaign/"
const FRAMES := "res://build/diagnostics/campaign-goal/nursery-map-frames-v2/"
var assertions := 0
var failures := 0
var captures: Array[Dictionary] = []
var movement_samples: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyNurseryMap " + message)

func _label(parent: Node, text: String, at: Vector2, font_size := 18) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font", preload("res://themes/MintFarmTheme.tres").default_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f3eddc"))
	parent.add_child(label)

func _save(view: SubViewport, filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	check(image != null and not image.is_empty() and image.save_png(filename) == OK, "GPU capture failed " + filename)
	captures.append({"path": filename.trim_prefix("res://"), "sha256": FileAccess.get_sha256(filename)})

func _view() -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	return view

func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]:
		Input.action_release(action)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	RenderingServer.set_default_clear_color(Color("20342b"))
	var source_paths := ["scenes/world/mist_nursery.tscn", "scripts/world/NurseryMap.gd", "scripts/world/NurseryArenaLayout.gd", "scripts/world/NurseryFloor.gd", "scripts/world/NurseryObstacle.gd", "scripts/world/NurseryPropArt.gd", "scripts/actors/Player.gd", "scripts/art/VerifyNurseryMap.gd"]
	var sources := {}
	for path in source_paths:
		sources[path] = FileAccess.get_sha256("res://" + path)
	# Small asset style group at gameplay scale and 2x detail, before adopting.
	var group := _view()
	group.size = Vector2i(1440, 900)
	_label(group, "雾苔苗圃 / 原创原生环境样板 · 非关卡通关", Vector2(28, 18), 24)
	var roles: Array[StringName] = [&"seed_house", &"plant_bed", &"root_wall"]
	var sizes := [Vector2(220, 150), Vector2(210, 110), Vector2(110, 180)]
	for index in 3:
		_label(group, ["育苗棚", "错位植床", "根系隔断"][index], Vector2(80 + index * 480, 82))
		for row in 2:
			var prop := Prop.new()
			prop.setup(Rect2(Vector2.ZERO, sizes[index]), roles[index])
			prop.position = Vector2(240 + index * 480, 530 if row == 0 else 840)
			prop.scale = Vector2.ONE * (2 if row == 0 else 1)
			group.add_child(prop)
			var safe_area := Rect2(8, 110 if row == 0 else 610, group.size.x - 16, 440 if row == 0 else group.size.y - 618)
			check(safe_area.encloses(prop.global_transform * prop.occlusion_rect.grow(2)), "style sample clipped/overlaps caption: %s row %s" % [roles[index], row])
	if failures > 0:
		group.queue_free()
		await process_frame
		quit(1)
		return
	_label(group, "上：2x细节    下：1x实战尺度    底座是实际碰撞区域，上层遮挡可变淡。", Vector2(28, 565), 18)
	await _save(group, DIR + "nursery-prop-style-v2.png")
	group.queue_free()
	await process_frame
	for seed_value in [0, 521, 20261009]:
		var view := _view()
		var map = Map.instantiate()
		map.map_seed = seed_value
		view.add_child(map)
		var camera := Camera2D.new()
		camera.zoom = Vector2.ONE * 0.36
		view.add_child(camera)
		var overlay := CanvasLayer.new()
		view.add_child(overlay)
		_label(overlay, "全图审查缩略图 / 非实战视野 · 种子 %s" % seed_value, Vector2(24, 16), 22)
		await _save(view, DIR + "nursery-map-overview-%s-v2.png" % seed_value)
		view.queue_free()
		await process_frame
	# Actual Player + real collision + ordinary input, no teleport after spawn.
	var view := _view()
	var map = Map.instantiate()
	map.map_seed = 521
	view.add_child(map)
	var layout = map.get_node("Layout")
	var rect: Rect2 = layout.get_obstacle_descriptors()[0].rect
	var player := Player.new()
	player.world_bounds = layout.world_bounds
	player.position = Vector2(rect.position.x - 55, rect.get_center().y)
	map.add_child(player)
	layout.occlusion_target = player
	var camera := Camera2D.new()
	camera.position = rect.get_center()
	view.add_child(camera)
	var overlay := CanvasLayer.new()
	view.add_child(overlay)
	_label(overlay, "地图候选 · 实际玩家普通移动/碰撞检查（玩家为现有过渡资源）", Vector2(24, 16), 20)
	await _save(view, DIR + "nursery-map-player-start-v2.png")
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES)) == OK, "frame directory unavailable")
	var targets: Array[Vector2] = [Vector2(rect.position.x - 55, rect.position.y - 60), Vector2(rect.end.x + 55, rect.position.y - 60), Vector2(rect.end.x + 55, rect.get_center().y)]
	var waypoint := 0
	var moved := 0
	var last := player.position
	var initial_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 60
	for step in 480:
		_release()
		if waypoint >= targets.size():
			break
		var offset: Vector2 = targets[waypoint] - player.position
		if offset.length() < 10:
			waypoint += 1
			continue
		var direction := offset.normalized()
		for axis in [["move_left", -direction.x], ["move_right", direction.x], ["move_up", -direction.y], ["move_down", direction.y]]:
			if axis[1] > 0:
				Input.action_press(axis[0], axis[1])
		await physics_frame
		await process_frame
		moved += 1 if player.position.distance_to(last) > 0.01 else 0
		last = player.position
		check(layout.is_position_walkable(player.position, player.get_body_radius() - 0.5), "rendered route embedded actual player")
		if step % 3 == 0 and movement_samples.size() < 60:
			await RenderingServer.frame_post_draw
			var filename := FRAMES + "frame_%03d.png" % movement_samples.size()
			check(view.get_texture().get_image().save_png(filename) == OK, "movement frame save failed")
			movement_samples.append({"file": filename.trim_prefix("res://"), "physics_frame": Engine.get_physics_frames(), "wall_usec": Time.get_ticks_usec(), "position": [player.position.x, player.position.y], "waypoint": waypoint, "sha256": FileAccess.get_sha256(filename)})
	_release()
	Engine.physics_ticks_per_second = initial_hz
	check(waypoint == 3 and moved > 30, "actual rendered player failed normal route")
	check(not movement_samples.is_empty(), "movement proof has no rendered frames")
	await _save(view, DIR + "nursery-map-player-end-v2.png")
	view.queue_free()
	await process_frame
	for path in sources:
		check(FileAccess.get_sha256("res://" + path) == sources[path], "source changed during capture")
	var report := {"contract": "nursery-map-native-proof-v1", "valid": failures == 0, "assertions": assertions, "sources": sources, "captures": captures, "movement_samples": movement_samples, "adjacent_player_moves": moved, "waypoints_reached": waypoint, "limits": ["Isolated chapter map, not Main encounter integration or Boss clear.", "Player is actual existing transitional renderer; not new player skeleton acceptance.", "Overview zoom only for review, not normal gameplay camera.", "Input route is scripted, not a human playtest or pathfinder performance test.", "Frame timing is measured; video nominal frame rate is not a performance claim."]}
	var file := FileAccess.open(DIR + "nursery-map-runtime-v2.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if failures == 0:
		print("TEST PASS: VerifyNurseryMap %d" % assertions)
	quit(1 if failures > 0 else 0)
