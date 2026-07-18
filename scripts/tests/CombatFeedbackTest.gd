extends SceneTree

const CombatVfxScript = preload("res://scripts/effects/CombatVfx.gd")
const CameraEffectsScript = preload("res://scripts/effects/CameraEffects.gd")

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

	vfx.queue_free()
	camera_effects.queue_free()
	camera.queue_free()
	await process_frame
	print("TEST PASS: CombatFeedbackTest %d" % assertions)
	quit(0)
