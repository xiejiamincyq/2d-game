extends SceneTree
const Vfx = preload("res://scripts/effects/CombatVfx.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: " + suite_name() + " " + message)
func _initialize() -> void:
	await process_frame
	var source: Script = Vfx
	var constants := source.get_script_constant_map()
	check(constants.has("HIT_ART") and not constants.has("HIT_TEXTURE"), "actual impact still depends on unreviewed bitmap")
	if failures: quit(1); return
	var art: Script = constants.HIT_ART
	_check_source_contract(art)
	for radius in [1.0, 5.0, 17.0]:
		for angle in [0.0, 0.23, PI, 5.4]:
			var points: PackedVector2Array = art.points(Vector2(41,77), radius, angle)
			check(points.size() == 8, "compact four-point paper spark geometry")
			for point in points:
				check(point.is_finite() and point.distance_to(Vector2(41,77)) <= radius + 0.001, "drawing exceeds declared radius")
	var actual := Vfx.new()
	root.add_child(actual)
	actual.set_process(false)
	check(actual.z_index == -1 and not actual.z_as_relative, "impact paints over actors")
	for hit in 20: actual.request_effect(actual.SPARK, Vector2.ZERO)
	var burst_count := 0
	for record in actual._sparks:
		burst_count += 1 if record.burst else 0
		check(not record.has("textured") and is_equal_approx(record.max_life,0.16), "obsolete raster record or changed timing")
	check(burst_count == 3 and actual._sparks.size() == 20, "local native bursts no longer capped at three")
	actual.request_effect(actual.SPARK,Vector2(100,0))
	check(actual._sparks[-1].burst, "distant spark suppressed")
	for hit in 200: actual.request_effect(actual.SPARK,Vector2.ZERO)
	check(actual._sparks.size() == 96 and actual.get_child_count() == 0, "global cap/node budget changed")
	actual._process(1)
	check(actual.get_total_effect_count() == 0, "expired native impacts retained")
	actual.free()
	await process_frame
	if not failures: print("TEST PASS: %s %d" % [suite_name(), checks])
	quit(1 if failures else 0)
func suite_name() -> String: return "NativeImpactRuntimeTest"
func _check_source_contract(art: Script) -> void:
	check(art.resource_path == "res://scripts/effects/PaperImpactArt.gd", "original drawing source absent")
