extends SceneTree

const CombatVfxScript = preload("res://scripts/effects/CombatVfx.gd")
const CameraEffectsScript = preload("res://scripts/effects/CameraEffects.gd")
const CombatFeedbackScript = preload("res://scripts/systems/CombatFeedback.gd")
const AudioManagerScript = preload("res://scripts/systems/AudioManager.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: CombatFeedbackTest: " + message)
	Engine.time_scale = 1.0
	quit(1)
	return false

func _initialize() -> void:
	var vfx: Node2D = CombatVfxScript.new()
	root.add_child(vfx)
	await process_frame
	var child_count_before: int = vfx.get_child_count()
	for effect_index in range(1000):
		var position := Vector2(float(effect_index % 25), float(effect_index % 17))
		vfx.request_effect(CombatVfxScript.SPARK, position, Vector2.RIGHT, 1.0)
		vfx.request_effect(CombatVfxScript.DEBRIS, position, Vector2.UP, 1.0)
		vfx.request_effect(CombatVfxScript.RING, position, Vector2.ZERO, 1.0)
		vfx.request_effect(CombatVfxScript.AFTERIMAGE, position, Vector2.LEFT, 1.0)
	if not _assert_true(vfx.get_effect_count(CombatVfxScript.SPARK) <= CombatVfxScript.MAX_SPARKS, "spark records exceeded their cap"):
		return
	if not _assert_true(vfx.get_effect_count(CombatVfxScript.DEBRIS) <= CombatVfxScript.MAX_DEBRIS, "debris records exceeded their cap"):
		return
	if not _assert_true(vfx.get_effect_count(CombatVfxScript.RING) <= CombatVfxScript.MAX_RINGS, "ring records exceeded their cap"):
		return
	if not _assert_true(vfx.get_effect_count(CombatVfxScript.AFTERIMAGE) <= CombatVfxScript.MAX_AFTERIMAGES, "afterimage records exceeded their cap"):
		return
	if not _assert_true(vfx.get_child_count() == child_count_before, "VFX requests created persistent child nodes"):
		return
	vfx.clear_all()
	if not _assert_true(vfx.get_total_effect_count() == 0, "VFX clear did not remove every record"):
		return

	var camera := Camera2D.new()
	root.add_child(camera)
	var camera_effects: Node = CameraEffectsScript.new()
	root.add_child(camera_effects)
	camera_effects.setup(camera)
	camera_effects.request_impact(5.0, Vector2(4.0, -2.0))
	camera_effects._process(0.016)
	if not _assert_true(camera.offset.length() <= camera_effects.max_offset + 0.001, "camera offset exceeded its clamp"):
		return
	if not _assert_true(absf(camera.rotation) <= camera_effects.max_rotation + 0.001, "camera rotation exceeded its clamp"):
		return
	camera_effects.clear_all()
	if not _assert_true(camera.offset == Vector2.ZERO and is_zero_approx(camera.rotation), "camera did not reset exactly to zero"):
		return

	var audio: Node = AudioManagerScript.new()
	root.add_child(audio)
	await process_frame
	if not _assert_true(audio.streams.has("kill_confirm"), "combat audio does not provide a dedicated kill confirmation cue"):
		return
	if not _assert_true(audio.streams.has("overdrive_kill"), "combat audio does not provide an overdrive kill confirmation cue"):
		return
	var overdrive_kill_stream: AudioStream = audio.streams["overdrive_kill"]
	if not _assert_true(overdrive_kill_stream.resource_path == "res://assets/audio/overdrive_bone_breaking.mp3", "overdrive confirmation did not use the approved Bone Breaking source"):
		return
	if not _assert_true(overdrive_kill_stream != audio.streams["kill_confirm"], "overdrive confirmation reused the ordinary kill cue"):
		return
	var feedback: Node = CombatFeedbackScript.new()
	root.add_child(feedback)
	feedback.setup(vfx, camera_effects, audio)
	var light_enemy: Node = EnemyScript.new()
	var medium_enemy: Node = EnemyScript.new()
	var heavy_enemy: Node = EnemyScript.new()
	root.add_child(light_enemy)
	root.add_child(medium_enemy)
	root.add_child(heavy_enemy)
	light_enemy.setup(EnemyScript.EnemyKind.DASHER, 1, root)
	medium_enemy.setup(EnemyScript.EnemyKind.SCRAPPER, 1, root)
	heavy_enemy.setup(EnemyScript.EnemyKind.BRUISER, 1, root)
	await process_frame
	for enemy in [light_enemy, medium_enemy, heavy_enemy]:
		enemy.set_physics_process(false)
		enemy.health.set_process(false)
	Engine.time_scale = 1.0
	feedback.on_damage_resolved(
		medium_enemy,
		DamageTypes.PROJECTILE,
		10.0,
		Vector2(30.0, 20.0),
		Vector2.RIGHT,
		false
	)
	if not _assert_true(is_equal_approx(Engine.time_scale, 1.0), "ordinary damage triggered hit-stop"):
		return
	if not _assert_true(vfx.get_effect_count(CombatVfxScript.SPARK) == 1, "ordinary damage did not request one spark record"):
		return
	if not _assert_true(
		not audio.play_hit(DamageTypes.PROJECTILE),
		"legacy Enemy.hit playback was not suppressed after the damage fact played its cue"
	):
		return

	feedback.on_damage_resolved(
		medium_enemy,
		DamageTypes.PROJECTILE,
		20.0,
		Vector2(40.0, 20.0),
		Vector2.RIGHT,
		true
	)
	if not _assert_true(Engine.time_scale < 1.0, "a kill did not trigger hit-stop"):
		return
	if not _assert_true(is_zero_approx(camera_effects.trauma), "a medium kill triggered forbidden screen shake"):
		return
	if not _assert_true(
		vfx.get_effect_count(CombatVfxScript.DEBRIS) >= 6
		and vfx.get_effect_count(CombatVfxScript.RING) >= 2,
		"a kill did not request a readable bounded debris and ring burst"
	):
		return
	var kill_cue_assigned := false
	for voice in audio.voice_pool:
		if voice.stream == audio.streams["kill_confirm"]:
			kill_cue_assigned = true
			break
	if not _assert_true(kill_cue_assigned, "a kill did not play the dedicated confirmation cue"):
		return
	feedback.reset_all()
	camera_effects.clear_all()
	audio._process(1.0)
	feedback.on_damage_resolved(
		light_enemy,
		DamageTypes.PROJECTILE,
		20.0,
		Vector2.ZERO,
		Vector2.RIGHT,
		true
	)
	if not _assert_true(is_zero_approx(camera_effects.trauma), "a light kill triggered forbidden screen shake"):
		return
	var light_cue_assigned := false
	for voice in audio.voice_pool:
		if voice.stream == audio.streams.get("hit_light"):
			light_cue_assigned = true
			break
	if not _assert_true(light_cue_assigned, "a light damage fact did not play the light hit cue"):
		return
	feedback.reset_all()
	camera_effects.clear_all()
	audio._process(1.0)
	feedback.on_damage_resolved(
		heavy_enemy,
		DamageTypes.PROJECTILE,
		20.0,
		Vector2.ZERO,
		Vector2.RIGHT,
		true
	)
	if not _assert_true(is_equal_approx(camera_effects.trauma, 0.45), "a projectile heavy kill did not use reduced trauma"):
		return
	var heavy_cue_assigned := false
	for voice in audio.voice_pool:
		if voice.stream == audio.streams.get("hit_heavy"):
			heavy_cue_assigned = true
			break
	if not _assert_true(heavy_cue_assigned, "a heavy damage fact did not play the heavy hit cue"):
		return
	for request_index in range(20):
		feedback.request_heavy_hit(Vector2.ZERO, Vector2.UP, 1.0)
	if not _assert_true(
		feedback.get_reserved_hit_stop_ms() <= CombatFeedbackScript.MAX_STOP_PER_WINDOW_MS,
		"rolling hit-stop reservations exceeded the 100ms/35ms budget"
	):
		return
	if not _assert_true(
		feedback.get_active_hit_stop_remaining_ms() <= CombatFeedbackScript.MAX_STOP_PER_WINDOW_MS,
		"merged active hit-stop exceeded its hard cap"
	):
		return
	feedback.reset_all()
	if not _assert_true(is_equal_approx(Engine.time_scale, 1.0), "feedback reset did not restore Engine.time_scale"):
		return
	feedback.request_hit_stop(10.0)
	feedback._hit_stop_until_ms = float(Time.get_ticks_msec()) - 1.0
	feedback._process(0.0)
	if not _assert_true(is_equal_approx(Engine.time_scale, 1.0), "completed hit-stop did not restore Engine.time_scale automatically"):
		return
	for index in range(feedback._stop_reservations.size()):
		feedback._stop_reservations[index]["time_ms"] = float(Time.get_ticks_msec()) - CombatFeedbackScript.HIT_STOP_WINDOW_MS - 1.0
	if not _assert_true(is_zero_approx(feedback.get_reserved_hit_stop_ms()), "expired rolling-window reservations were not released"):
		return
	if not _assert_true(
		is_equal_approx(feedback.request_hit_stop(CombatFeedbackScript.MAX_STOP_PER_WINDOW_MS), CombatFeedbackScript.MAX_STOP_PER_WINDOW_MS),
		"a fresh rolling window did not restore the full hit-stop budget"
	):
		return
	feedback.reset_all()

	vfx.queue_free()
	feedback.queue_free()
	camera_effects.queue_free()
	camera.queue_free()
	light_enemy.queue_free()
	medium_enemy.queue_free()
	heavy_enemy.queue_free()
	TestSupport.stop_audio(audio)
	await create_timer(0.25).timeout
	audio.queue_free()
	await process_frame
	print("TEST PASS: CombatFeedbackTest %d" % assertions)
	quit(0)
