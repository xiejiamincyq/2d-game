extends "res://scripts/art/VerifyNaturalRun.gd"

const Lobbed = preload("res://scripts/components/LobbedProjectile.gd")
const CLIPS := ["opening", "crowd", "dash", "overlap", "boss", "shop"]
const CLIP_FRAMES := 30
var clips: Dictionary = {}
var pending_images: Array[Dictionary] = [] # At most 180 RGBA frames, ~633 MiB, diagnostic-only.
var capture_dir := ""
var last_capture_frame := -4
var boss_view_samples: Array[Dictionary] = []
var boss_view_truncated := false

static func measure_boss_view(sprite_rect: Rect2, viewport_rect: Rect2, ui_rects: Array) -> Dictionary:
	var total_area := sprite_rect.get_area()
	var on_screen := sprite_rect.intersection(viewport_rect)
	var overlaps: Array[float] = []
	for ui_rect: Rect2 in ui_rects:
		overlaps.append(on_screen.intersection(ui_rect).get_area())
	# Control overlaps are separate: summing overlapping UI cards would double-count.
	return {"offscreen_area": maxf(0.0, total_area - on_screen.get_area()), "ui_overlap_areas": overlaps}

static func eligible_tags(info: Dictionary) -> Array[String]:
	if info.state == "SETTLEMENT":
		return ["shop"] if info.get("shop_ready", false) else []
	if info.state != "PLAYING":
		return []
	var tags: Array[String] = []
	if info.wave == 1 and info.step >= 30:
		tags.append("opening")
	if info.visible_live >= 20:
		tags.append("crowd")
	if info.dash:
		tags.append("dash")
	if info.warning_overlap:
		tags.append("overlap")
	if info.boss_active:
		tags.append("boss")
	return tags

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Natural rendering capture requires a real display/rendering driver")
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--run="):
			var run_id := argument.trim_prefix("--run=")
			if RegEx.create_from_string("^[A-Za-z0-9_-]{1,80}$").search(run_id) == null:
				quit(2)
				return
			capture_dir = OUTPUT + "captures-" + run_id + "/"
	if capture_dir.is_empty() or DirAccess.dir_exists_absolute(capture_dir) or FileAccess.file_exists(capture_dir.trim_suffix("/") + ".json"):
		push_error("Natural capture refuses existing or missing output ID")
		quit(2)
		return
	RenderingServer.frame_post_draw.connect(_capture)
	await super._initialize()

func _capture() -> void:
	if started == 0 or reloading or not terminal.is_empty() or not is_instance_valid(view) or not view.is_inside_tree() or not is_instance_valid(scene) or not is_instance_valid(scene.player):
		return
	_record_boss_view() # Entire drawn fight, independent of the thirty-frame clip quota.
	var frame := Engine.get_physics_frames()
	if frame - last_capture_frame < 4:
		return
	var info := _visual_info()
	for tag in eligible_tags(info):
		if not clips.has(tag):
			clips[tag] = []
	var active: Array[String] = []
	for tag in clips:
		if clips[tag].size() < CLIP_FRAMES:
			active.append(tag)
	if active.is_empty():
		return
	last_capture_frame = frame
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir)) != OK:
		valid = false
		terminal = "capture_error"
		return
	var bitmap := view.get_texture().get_image()
	if bitmap == null or bitmap.is_empty() or bitmap.get_size() != Vector2i(1280, 720):
		valid = false
		terminal = "capture_error"
		return
	for tag in active:
		var path := capture_dir + "%s-%03d.png" % [tag, clips[tag].size()]
		var record := info.duplicate(true)
		record.merge({"path": path.trim_prefix("res://"), "sha256": "", "frame": frame, "process_frame": Engine.get_process_frames(), "wall": float(Time.get_ticks_usec() - started) / 1000000.0})
		pending_images.append({"image": bitmap, "record": record, "path": path})
		clips[tag].append(record)
		if clips[tag].size() == 1:
			print("NATURAL_CAPTURE_START tag=%s step=%d visible=%d" % [tag, samples.size(), info.visible_live])

func _record_boss_view() -> void:
	if scene.run_state != scene.RunState.PLAYING:
		return
	var boss: Node = scene.wave_director.get_active_boss()
	if not is_instance_valid(boss) or boss.is_queued_for_deletion() or not boss.is_visible_in_tree() or not boss.entrance_resolved or boss.health.current_health <= 0.0:
		return
	if boss_view_samples.size() >= 60000:
		boss_view_truncated = true
		valid = false
		return
	var sprite_rect: Rect2 = boss.boss_visual.get_global_transform_with_canvas() * boss.boss_visual.get_rect()
	var ui_names: Array[String] = []
	var ui_rects: Array[Rect2] = []
	for control: Control in scene.ui.get_combat_occluders():
		ui_names.append(str(control.get_path()))
		ui_rects.append(control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size))
	var serialized_rects: Array = []
	for rect: Rect2 in ui_rects:
		serialized_rects.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	var camera := view.get_camera_2d()
	var camera_center := camera.get_screen_center_position() if camera != null else Vector2.ZERO
	var metrics := measure_boss_view(sprite_rect, Rect2(Vector2.ZERO, Vector2(view.size)), ui_rects)
	metrics.merge({"frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(),
		"wall": float(Time.get_ticks_usec() - started) / 1000000.0, "step": samples.size(),
		"sprite_rect": [sprite_rect.position.x, sprite_rect.position.y, sprite_rect.size.x, sprite_rect.size.y],
		"ui_names": ui_names, "ui_rects": serialized_rects,
		"boss_world": [boss.global_position.x, boss.global_position.y], "player_world": [scene.player.global_position.x, scene.player.global_position.y],
		"camera_center_world": [camera_center.x, camera_center.y], "boss_speed": boss.velocity.length(),
		"boss_alpha": boss.modulate.a, "nominal_safe_center_inside": boss.get_combat_safe_rect().has_point(boss.global_position)})
	var rig: Node = scene.boss_camera_framing
	if is_instance_valid(rig):
		var player_rect: Rect2 = scene.player.get_global_transform_with_canvas() * Rect2(-54, -54, 108, 108)
		var player_metrics := measure_boss_view(player_rect, Rect2(Vector2.ZERO, Vector2(view.size)), ui_rects)
		var cue: Control = scene.ui.boss_direction_indicator
		var cue_rect := cue.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, cue.size)
		metrics.merge({"framing_active": rig.active, "both_fit": rig.both_fit, "camera_zoom": camera.zoom.x,
			"safe_screen_rect": [rig.safe_screen_rect.position.x, rig.safe_screen_rect.position.y, rig.safe_screen_rect.size.x, rig.safe_screen_rect.size.y],
			"player_rect": [player_rect.position.x, player_rect.position.y, player_rect.size.x, player_rect.size.y],
			"player_offscreen_area": player_metrics.offscreen_area, "player_ui_overlap_areas": player_metrics.ui_overlap_areas,
			"direction_cue_visible": cue.is_visible_in_tree(), "direction_cue_rect": [cue_rect.position.x, cue_rect.position.y, cue_rect.size.x, cue_rect.size.y]})
	boss_view_samples.append(metrics)

func _visual_info() -> Dictionary:
	var screen := Rect2(Vector2.ZERO, Vector2(view.size))
	var visible_live := 0
	var visible_lobbers := 0
	for enemy in scene.wave_director.active_enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.health.current_health <= 0:
			continue
		if screen.has_point(view.canvas_transform * enemy.global_position):
			visible_live += 1
			if enemy is EnemyScript and enemy.kind == EnemyScript.EnemyKind.LOBBER:
				visible_lobbers += 1
	var warnings: Array[Dictionary] = []
	var overlap := false
	for shot in scene.projectiles.get_children():
		if not shot is Lobbed or shot.is_queued_for_deletion() or not screen.has_point(view.canvas_transform * shot.target_position):
			continue
		for warning in warnings:
			if shot.target_position.distance_to(Vector2(warning.position[0], warning.position[1])) < shot.splash_radius + warning.radius:
				overlap = true
		warnings.append({"position": [shot.target_position.x, shot.target_position.y], "radius": shot.splash_radius})
	var boss: Node = scene.wave_director.get_active_boss()
	var boss_active: bool = is_instance_valid(boss) and boss.entrance_resolved and screen.has_point(view.canvas_transform * boss.global_position) and (boss.tentacle_attack.is_attacking() or boss.attack_director.pattern.is_pattern_active())
	var player_screen: Vector2 = view.canvas_transform * scene.player.global_position
	return {"state": scene.RunState.keys()[scene.run_state], "step": samples.size(), "wave": scene.wave_director.wave_index + 1,
		"visible_live": visible_live, "live": scene.wave_director.active_enemies.size(), "visible_lobbers": visible_lobbers,
		"dash": scene.player.dash_active, "warning_overlap": overlap, "warnings": warnings, "boss_active": boss_active,
		"shop_ready": continued_once, "player_screen": [player_screen.x, player_screen.y], "health": scene.player.health.current_health,
		"player_alpha": scene.player.modulate.a, "cardinal": scene.player.chibi_cardinal_index(scene.player.gun_angle),
		"aim_screen": [scene.ui.aim_reticle.get_rect().get_center().x, scene.ui.aim_reticle.get_rect().get_center().y],
		"reticle_visible": scene.ui.aim_reticle.visible}

func _source_hashes() -> Dictionary:
	var hashes := super._source_hashes()
	# The visible mouse marker must be bound to the actual captured version, too.
	for path in ["scripts/ui/GameUI.gd", "scripts/ui/AimReticle.gd", "scripts/ui/BossHealthBar.gd", "themes/MintFarmTheme.tres", "scenes/ui/HUD.tscn", "scripts/effects/CameraEffects.gd", "scripts/systems/CombatView.gd", "scripts/systems/BossCameraFraming.gd", "scripts/ui/BossDirectionIndicator.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	for path in ["scripts/art/VerifyNaturalRunRendered.gd", "scripts/components/LobbedProjectile.gd", "scripts/components/TentacleAttack.gd", "scripts/components/BossAttackDirector.gd", "scripts/components/BossProjectilePattern.gd", "scripts/ui/HUD.gd", "scripts/world/FloorGrid.gd", "scripts/world/ArenaObstacle.gd", "assets/art/actors/player/player_chibi_b_cardinal_atlas_v1.png", "assets/art/actors/player/player_chibi_b_weapon_cardinal_atlas_v1.png", "assets/art/environment/mint_farm_floor_b_v1.png", "assets/art/environment/mint_farm_props_b_packed_v1.png", "assets/art/environment/floor_surface.gdshader", "assets/art/environment/prop_alpha.gdshader", "assets/art/shaders/dasher_hit_flash.gdshader"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	for filename in DirAccess.get_files_at("res://assets/art/actors/enemies/"):
		if filename.ends_with("_chibi_b_v1.png"):
			var path: String = "assets/art/actors/enemies/" + filename
			hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes

func _finish() -> void:
	RenderingServer.frame_post_draw.disconnect(_capture)
	paused = true
	for index in range(pending_images.size()):
		var pending: Dictionary = pending_images[index]
		if pending.image.save_png(ProjectSettings.globalize_path(pending.path)) != OK:
			valid = false
		pending.record.sha256 = FileAccess.get_sha256(pending.path)
		pending.image = null
		if (index + 1) % 30 == 0:
			print("NATURAL_CAPTURE_FLUSH saved=%d/%d" % [index + 1, pending_images.size()])
	pending_images.clear()
	var missing: Array[String] = []
	for tag in CLIPS:
		if not clips.has(tag) or clips[tag].size() != CLIP_FRAMES:
			missing.append(tag)
	var file := FileAccess.open(capture_dir.trim_suffix("/") + ".json", FileAccess.WRITE)
	if file == null:
		valid = false
	else:
		file.store_string(JSON.stringify({"run": config.run, "clips": clips, "missing": missing, "viewport": [1280, 720], "source_sha256": source_before,
			"boss_view": boss_view_samples, "boss_view_truncated": boss_view_truncated,
			"adapter": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(), "scope": "natural rendered frame readbacks; Boss view rectangles are conservative texture AABBs, not opaque-pixel masks; not performance, paired before/after or human acceptance"}))
		file.close()
	valid = valid and not boss_view_truncated
	print("NATURAL_CAPTURE_COMPLETE run=%s missing=%s" % [config.run, missing])
	await super._finish()
