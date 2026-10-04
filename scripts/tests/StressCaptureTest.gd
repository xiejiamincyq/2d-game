extends SceneTree

var assertions := 0

func require_condition(condition: bool, message: String) -> bool:
	assertions += 1
	if not condition:
		push_error("TEST FAIL: StressCaptureTest: " + message)
		quit(1)
	return condition

func _initialize() -> void:
	if not require_condition(FileAccess.file_exists("res://scripts/art/StressCaptureObserver.gd"), "stress peak observer not implemented"):
		return
	var Observer = load("res://scripts/art/StressCaptureObserver.gd")
	var observer = Observer.new()
	for index in range(5):
		var sample := {"step": index + 1, "physics_frame": 100 + index, "wall_seconds": index * 0.1,
			"health": 100.0 if index < 4 else 0.0, "position": [0.0,0.0], "input": [1.0,0.0]}
		var bodies := {"bodies": [{"id":1}, {"id":2}] if index > 0 else [{"id":1}], "visible":1}
		observer.observe_sample(sample, bodies, [])
	if not require_condition(observer.valid and observer.observations.size() == 5, "continuous physics samples not retained"):
		return
	if not require_condition(observer.ledger.peak.index == 2 and observer.ledger.peak.live == 2, "peak tie must retain earliest live physics step"):
		return
	if not require_condition(observer.ledger.visible_peak.index == 1, "visible peak tie drifted"):
		return
	if not require_condition(not observer.observations[-1].eligible, "dead terminal sample accepted into playing peak"):
		return
	if not require_condition(observer.observations[1].frame == 101 and observer.observations[1].wall == 0.1, "sample identity or physics wall lost"):
		return
	var broken = Observer.new()
	broken.observe_sample({"step":1,"physics_frame":10,"wall_seconds":0.0,"health":100.0}, {"bodies":[],"visible":0}, [])
	broken.observe_sample({"step":2,"physics_frame":10,"wall_seconds":0.1,"health":100.0}, {"bodies":[],"visible":0}, [])
	if not require_condition(not broken.valid, "duplicate physics frame accepted"):
		return
	if not require_condition(observer.has_method("window_summary"), "window truncation contract missing"):
		return
	var timestamps: Array[Dictionary] = []
	for index in range(10):
		timestamps.append({"wall":index*0.1})
	var window: Dictionary = observer.window_summary(1.0, "death", timestamps)
	if not require_condition(window.truncated_left and window.truncated_right and window.left_reason == "startup" and window.right_reason == "death", "boundary truncation not explicit"):
		return
	if not require_condition(window.observed_interval_complete and window.coverage_start == 0.0 and window.coverage_end == 1.0, "legal short lifespan rejected"):
		return
	window = observer.window_summary(3.1, "step_budget", [{"wall":0.1}])
	if not require_condition(not window.observed_interval_complete and window.max_gap > 0.25, "one image accepted as full peak interval"):
		return
	window = observer.window_summary(1.0, "death", [])
	if not require_condition(not window.observed_interval_complete, "empty window accepted"):
		return
	print("TEST PASS: StressCaptureTest %d" % assertions)
	quit(0)
