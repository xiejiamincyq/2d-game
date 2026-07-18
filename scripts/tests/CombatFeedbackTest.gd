extends SceneTree

const CombatVfxScript = preload("res://scripts/effects/CombatVfx.gd")
const CameraEffectsScript = preload("res://scripts/effects/CameraEffects.gd")
const CombatFeedbackScript = preload("res://scripts/systems/CombatFeedback.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")

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

	var feedback: Node = CombatFeedbackScript.new()
	root.add_child(feedback)
	feedback.setup(vfx, camera_effects)
	Engine.time_scale = 1.0
	feedback.on_damage_resolved(
		null,
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

	feedback.on_damage_resolved(
		null,
		DamageTypes.PROJECTILE,
		20.0,
		Vector2(40.0, 20.0),
		Vector2.RIGHT,
		true
	)
	if not _assert_true(Engine.time_scale < 1.0, "a kill did not trigger hit-stop"):
		return
	if not _assert_true(
		vfx.get_effect_count(CombatVfxScript.DEBRIS) == 1
		and vfx.get_effect_count(CombatVfxScript.RING) == 1,
		"a kill did not request bounded debris and ring feedback"
	):
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
	await create_timer(0.06, true, false, true).timeout
	feedback._process(0.0)
	if not _assert_true(is_equal_approx(Engine.time_scale, 1.0), "completed hit-stop did not restore Engine.time_scale automatically"):
		return
	await create_timer(0.12, true, false, true).timeout
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
	await process_frame
	print("TEST PASS: CombatFeedbackTest %d" % assertions)
	quit(0)
