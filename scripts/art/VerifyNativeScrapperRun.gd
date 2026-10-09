extends "res://scripts/art/VerifyNaturalRunRendered.gd"

# Observe the real Main/portals/Enemy and ordinary input pilot. No custom actor
# spawning, no invulnerability, no shortened waves, no direct animation posing.
const EVIDENCE := "res://docs/art/previews/campaign/native-scrapper-main-v1"
const FRAMES := "res://build/diagnostics/campaign-goal/native-scrapper-main-frames-v1/"
var native_frames := 0
var native_clips: Dictionary = {}
var native_samples: Array[Dictionary] = []
var native_last_frame := -4

func _capture() -> void:
	super._capture()
	if started == 0 or not terminal.is_empty() or not is_instance_valid(scene) or scene.run_state != scene.RunState.PLAYING:
		return
	var frame := Engine.get_physics_frames()
	if native_frames >= 60 or frame - native_last_frame < 4:
		return
	var screen := Rect2(Vector2.ZERO, Vector2(view.size))
	var observed: Array[Dictionary] = []
	for enemy in scene.wave_director.active_enemies:
		if not is_instance_valid(enemy) or not enemy is EnemyScript or enemy.death_resolved or enemy.native_visual == null:
			continue
		var art: Node2D = enemy.native_visual
		if not art.is_visible_in_tree() or not screen.intersects(art.get_global_transform_with_canvas() * enemy.get_visual_rect()):
			continue
		var clip: String = art.player.current_animation
		native_clips[clip] = int(native_clips.get(clip, 0)) + 1
		if observed.size() < 16:
			observed.append({"id": enemy.get_instance_id(), "clip": clip, "pose_time": art.player.current_animation_position,
				"position": [enemy.position.x, enemy.position.y], "velocity": [enemy.velocity.x, enemy.velocity.y],
				"native_bones": art.skeleton.get_bone_count(), "alpha": art.modulate.a, "hp": enemy.health.current_health,
				"flash": enemy.static_flash_material.get_shader_parameter("flash_amount"), "shoulder": art.skeleton.get_node("Torso/ArmR").rotation})
	if observed.is_empty():
		return
	if native_frames == 0 and (FileAccess.file_exists(EVIDENCE + ".png") or DirAccess.dir_exists_absolute(FRAMES)):
		valid = false
		terminal = "native_evidence_exists"
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES))
	var bitmap := view.get_texture().get_image()
	if bitmap == null or bitmap.is_empty() or bitmap.save_png(FRAMES + "frame_%03d.png" % native_frames) != OK:
		valid = false
		terminal = "native_capture_error"
		return
	if native_frames == 30 and bitmap.save_png(EVIDENCE + ".png") != OK:
		valid = false
		terminal = "native_capture_error"
		return
	native_samples.append({"frame": frame, "step": samples.size(), "actors": observed})
	native_frames += 1
	native_last_frame = frame

func _source_hashes() -> Dictionary:
	var hashes := super._source_hashes()
	hashes["scripts/art/VerifyNativeScrapperRun.gd"] = FileAccess.get_sha256("res://scripts/art/VerifyNativeScrapperRun.gd")
	return hashes

func _finish() -> void:
	var passed := native_frames == 60 and native_clips.has("walk") and FileAccess.file_exists(EVIDENCE + ".png")
	valid = valid and passed
	var file := FileAccess.open(EVIDENCE + ".json", FileAccess.WRITE)
	if file == null:
		valid = false
	else:
		file.store_string(JSON.stringify({"scope": "normal input pilot in actual Main, first native ordinary actors; not six chapters or human playtest or all-pose alpha", "run": config.run,
			"passed": passed, "frames": native_frames, "clips_seen": native_clips, "samples": native_samples, "source_sha256": source_before}, "\t"))
		file.close()
	print("NATIVE MAIN CAPTURE %s: %d frames, clips %s" % ["PASS" if passed else "FAIL", native_frames, native_clips])
	await super._finish()
