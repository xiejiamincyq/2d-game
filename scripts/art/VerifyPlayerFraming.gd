extends "res://scripts/tests/BossCameraFramingTest.gd"

var evidence_path := ""
var frames: Array[Dictionary] = []
var source_before: Dictionary = {}

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or arguments.size() != 1 or not arguments[0].begins_with("--run="):
		quit(2)
		return
	var run_id := arguments[0].trim_prefix("--run=")
	if RegEx.create_from_string("^[A-Za-z0-9_-]{1,60}$").search(run_id) == null:
		quit(2)
		return
	evidence_path = "res://build/diagnostics/player-framing/" + run_id
	if DirAccess.dir_exists_absolute(evidence_path) or DirAccess.make_dir_recursive_absolute(evidence_path) != OK:
		push_error("Player framing refuses existing/invalid evidence directory")
		quit(2)
		return
	source_before = _source_binding()
	await super._initialize()

func _observe_player_frame(label: String) -> void:
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await process_frame
	await RenderingServer.frame_post_draw
	var path := evidence_path + "/" + label + ".png"
	var image := view.get_texture().get_image()
	if not _check(image != null and image.get_size() == view.size and image.save_png(path) == OK, "native frame save failed: " + label):
		return
	var player_rect := _player_screen_rect()
	var overlaps: Array = []
	for rect in scene.ui.get_combat_occluder_rects():
		overlaps.append(player_rect.intersection(rect).get_area())
	frames.append({"label": label, "path": path, "sha256": FileAccess.get_sha256(path),
		"viewport": [view.size.x, view.size.y], "player_rect": _rect_data(player_rect),
		"player_world": [scene.player.global_position.x, scene.player.global_position.y],
		"zoom": [camera.zoom.x, camera.zoom.y], "ui_overlap_areas": overlaps,
		"offscreen_area": maxf(0.0, player_rect.get_area() - player_rect.intersection(Rect2(Vector2.ZERO, Vector2(view.size))).get_area())})

func _rect_data(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _source_binding() -> Dictionary:
	var binding := {}
	for path in ["scripts/art/VerifyPlayerFraming.gd", "scripts/tests/BossCameraFramingTest.gd", "scripts/Main.gd", "scripts/systems/BossCameraFraming.gd", "scripts/systems/CombatView.gd", "scripts/effects/CameraEffects.gd", "scripts/actors/Player.gd", "scripts/ui/GameUI.gd", "scripts/ui/HUD.gd", "scripts/world/ArenaLayout.gd"]:
		binding[path] = FileAccess.get_sha256("res://" + path)
	return binding

func _cleanup() -> void:
	if not evidence_path.is_empty():
		_check(_source_binding() == source_before, "source changed during native measurement")
		var file := FileAccess.open(evidence_path + "/report.json", FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"valid": not failed, "assertions": assertions, "frames": frames, "map_seed": scene.map_seed,
				"source_sha256": source_before, "scope": "controlled edge fixture, not natural gameplay or 20 maps",
				"display": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name()}))
			file.close()
		else:
			_check(false, "native framing report could not be written")
	super._cleanup()
