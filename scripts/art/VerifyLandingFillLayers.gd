extends SceneTree

# Rendered diagnostic only: --audio-driver Dummy --resolution 1280x720
# --script res://scripts/art/VerifyLandingFillLayers.gd -- --run=before
const PlayerScript = preload("res://scripts/actors/Player.gd")
const LobScript = preload("res://scripts/components/LobbedProjectile.gd")
const OUTPUT_DIR := "res://build/diagnostics/landing-fill/"
const COUNTS := [0, 1, 8]
const OFFSETS := [Vector2i.ZERO, Vector2i(-10, 0), Vector2i(10, 0), Vector2i(0, -16), Vector2i(0, 16), Vector2i(50, 0), Vector2i(80, 0)]
var canvas: SubViewport

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_id := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--run="):
			run_id = argument.trim_prefix("--run=")
		else:
			push_error("Expected only --run=before or --run=after")
			quit(1)
			return
	var output := OUTPUT_DIR + run_id
	if run_id not in ["before", "after"] or FileAccess.file_exists(output + ".png") or FileAccess.file_exists(output + ".json"):
		push_error("Invalid run or existing evidence; refusing overwrite")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR)) != OK:
		quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	for action in ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]:
		Input.action_release(action)
	await process_frame
	canvas = SubViewport.new()
	canvas.size = Vector2i(1280, 720)
	canvas.world_2d = World2D.new()
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var screen := TextureRect.new()
	screen.texture = canvas.get_texture()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	await process_frame
	canvas.canvas_transform = Transform2D.IDENTITY # Fixed 1:1 camera, no tracking or zoom.
	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)])
	floor.color = Color("d9e7dc")
	floor.z_index = -100
	canvas.add_child(floor)
	_label("LANDING FILL / %s / actual Player + LobbedProjectile / native scale" % run_id, Vector2(20, 25), 24)
	_label("Frozen at flight progress 0.5. Diagnostic only: no Main, saves, damage simulation or full-game visual pass.", Vector2(20, 670), 18)
	var cases: Array[Dictionary] = []
	for index in range(COUNTS.size()):
		cases.append(await _make_case(index))
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := canvas.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.save_png(ProjectSettings.globalize_path(output + ".png")) != OK:
		push_error("Landing-fill capture failed; a rendering-capable driver is required")
		quit(1)
		return
	for case_index in range(cases.size()):
		var points: Array[Dictionary] = []
		for offset: Vector2i in OFFSETS:
			var point := Vector2i(cases[case_index].center[0], cases[case_index].center[1]) + offset
			var color := capture.get_pixelv(point)
			var control := capture.get_pixelv(Vector2i(213, 360) + offset)
			points.append({"offset": [offset.x, offset.y], "pixel": [point.x, point.y], "rgba": [color.r, color.g, color.b, color.a], "rgb_abs_difference_from_control": absf(color.r - control.r) + absf(color.g - control.g) + absf(color.b - control.b)})
		cases[case_index]["pixel_samples"] = points
	var report := {"run": run_id, "acceptance": "diagnostic_capture_only", "engine": Engine.get_version_info().string,
		"viewport": [1280, 720], "camera": "identity_1_to_1", "floor_effective_z": _effective_z(floor), "cases": cases,
		"source_sha256": {"Player.gd": FileAccess.get_sha256("res://scripts/actors/Player.gd"), "LobbedProjectile.gd": FileAccess.get_sha256("res://scripts/components/LobbedProjectile.gd"), "VerifyLandingFillLayers.gd": FileAccess.get_sha256("res://scripts/art/VerifyLandingFillLayers.gd")},
		"materials": {"body": PlayerScript.PLAYER_CARDINAL_ATLAS_PATH, "weapon": PlayerScript.PLAYER_WEAPON_PATH, "lob": "procedural circles/arcs from actual LobbedProjectile._draw"},
		"limitations": "Static component layering evidence, not real-input combat, collision, damage, performance or whole-game visual acceptance. Pixel offsets include body-region candidates and floor controls; inspect PNG before assigning opaque-body meaning."}
	var file := FileAccess.open(output + ".json", FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	screen.texture = null
	screen.queue_free()
	canvas.queue_free()
	await process_frame
	await process_frame
	print("LANDING_FILL_CAPTURE_COMPLETE run=%s output=%s" % [run_id, output])
	quit(0)

func _make_case(index: int) -> Dictionary:
	var center := Vector2(213 + index * 427, 360)
	_label("%s / %d fills" % ["CONTROL" if index == 0 else "OVERLAP", COUNTS[index]], Vector2(center.x - 135, 135), 23)
	var player := PlayerScript.new()
	player.position = center
	player.z_index = 0
	canvas.add_child(player)
	if not player.is_node_ready():
		await player.ready
	player.set_physics_process(false)
	player.set_process(false)
	player.begin_entrance()
	player.advance_entrance(player.get_entrance_duration() + 0.01)
	player.gun_angle = PI * 0.5
	player.queue_redraw()
	var projectiles := Node2D.new()
	projectiles.z_index = 22
	canvas.add_child(projectiles)
	var fills: Array[Dictionary] = []
	for index_in_case in range(COUNTS[index]):
		var lob := LobScript.new()
		var origin := center + Vector2.LEFT.rotated(TAU * index_in_case / maxi(1, COUNTS[index])) * 180.0
		lob.position = origin
		projectiles.add_child(lob)
		if not lob.is_node_ready():
			await lob.ready
		lob.set_physics_process(false)
		lob.set_process(false)
		lob.configure(origin, center, player)
		lob.elapsed = lob.flight_duration * 0.5
		lob.global_position = origin.lerp(center, 0.5)
		lob._update_landing_fill()
		lob.queue_redraw()
		fills.append({"effective_z": _effective_z(lob.landing_fill), "local_z": lob.landing_fill.z_index, "z_as_relative": lob.landing_fill.z_as_relative, "rim_and_projectile_z": _effective_z(lob), "radius": lob.splash_radius, "damage": lob.damage, "flight_duration": lob.flight_duration, "physics_frozen": not lob.is_physics_processing()})
	return {"count": COUNTS[index], "center": [center.x, center.y], "body_effective_z": _effective_z(player), "body_size": [player.CHIBI_BODY_DRAW_SIZE.x, player.CHIBI_BODY_DRAW_SIZE.y], "ready": player.is_node_ready(), "entrance_finished": not player.entrance_active, "physics_frozen": not player.is_physics_processing(), "fills": fills}

func _effective_z(item: CanvasItem) -> int:
	var parent: CanvasItem = item.get_parent() as CanvasItem
	return item.z_index + (_effective_z(parent) if item.z_as_relative and parent != null else 0)

func _label(message: String, position: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = message
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("123b3b"))
	canvas.add_child(label)
