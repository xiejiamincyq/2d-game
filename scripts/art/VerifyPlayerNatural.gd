extends "res://scripts/art/VerifyNaturalRunRendered.gd"

var player_view: Array[Dictionary] = []
var player_view_truncated := false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--run="):
			var run_id := argument.trim_prefix("--run=")
			if RegEx.create_from_string("^[A-Za-z0-9_-]{1,80}$").search(run_id) == null or FileAccess.file_exists(OUTPUT + "captures-" + run_id + "-player-view.json"):
				quit(2)
				return
	await super._initialize()

func _capture() -> void:
	super._capture()
	if started == 0 or reloading or not terminal.is_empty() or not is_instance_valid(view) or not view.is_inside_tree() or not is_instance_valid(scene) or not is_instance_valid(scene.player) or scene.player.is_queued_for_deletion() or not scene.player.is_visible_in_tree() or scene.run_state != scene.RunState.PLAYING:
		return
	if player_view.size() >= 40000:
		player_view_truncated = true
		valid = false
		return
	var rect: Rect2 = scene.player.get_global_transform_with_canvas() * Rect2(-54, -54, 108, 108)
	var ui_rects: Array[Rect2] = scene.ui.get_combat_occluder_rects()
	var row := measure_boss_view(rect, Rect2(Vector2.ZERO, Vector2(view.size)), ui_rects)
	var serialized: Array = []
	for ui_rect in ui_rects:
		serialized.append([ui_rect.position.x, ui_rect.position.y, ui_rect.size.x, ui_rect.size.y])
	var camera := view.get_camera_2d()
	row.merge({"player_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"ui_rects": serialized, "step": samples.size(), "frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(),
		"player_world": [scene.player.global_position.x, scene.player.global_position.y],
		"framing_active": scene.boss_camera_framing.active, "zoom": camera.zoom.x})
	player_view.append(row)

func _source_hashes() -> Dictionary:
	var hashes := super._source_hashes()
	hashes["scripts/art/VerifyPlayerNatural.gd"] = FileAccess.get_sha256("res://scripts/art/VerifyPlayerNatural.gd")
	return hashes

func _finish() -> void:
	valid = valid and not player_view_truncated and not player_view.is_empty()
	var file := FileAccess.open(capture_dir.trim_suffix("/") + "-player-view.json", FileAccess.WRITE)
	if file == null:
		valid = false
	else:
		file.store_string(JSON.stringify({"run": config.run, "source_sha256": source_before, "viewport": [view.size.x, view.size.y],
			"rows": player_view, "truncated": player_view_truncated, "scope": "all drawn PLAYING 108px player/weapon AABBs; not opaque masks, 20 maps, performance or human acceptance"}))
		file.close()
	await super._finish()
