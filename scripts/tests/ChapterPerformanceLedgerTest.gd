extends SceneTree

const PATH := "res://scripts/art/ChapterPerformanceLedger.gd"
var assertions := 0
var failed := false

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failed = true
		push_error("TEST FAIL: ChapterPerformanceLedgerTest: " + message)

func _initialize() -> void:
	check(ResourceLoader.exists(PATH), "real frame timing ledger has not been implemented")
	if failed:
		quit(1)
		return
	var ledger = load(PATH)
	check(ledger.distribution(PackedFloat64Array()).is_empty(), "empty windows cannot become zero-latency success")
	check(ledger.distribution(PackedFloat64Array([NAN])).is_empty(), "invalid timer sample accepted")
	check(ledger.distribution(PackedFloat64Array([-1.0])).is_empty(), "negative duration accepted")
	var intervals := PackedFloat64Array()
	for i in range(100):
		intervals.append(float(i + 1))
	var stats: Dictionary = ledger.distribution(intervals)
	check(stats.count == 100 and stats.p50 == 50.0 and stats.p95 == 95.0 and stats.p99 == 99.0 and stats.maximum == 100.0, "nearest-rank quantile is incorrect")
	check(is_equal_approx(stats.mean, 50.5), "interval average incorrect")
	check(intervals[0] == 1.0 and intervals[-1] == 100.0, "statistics mutated caller samples")
	var spiky := PackedFloat64Array()
	for i in range(98): spiky.append(8.0)
	spiky.append(80.0)
	spiky.append(100.0)
	var spikes: Dictionary = ledger.distribution(spiky)
	check(spikes.p95 == 8.0 and spikes.p99 == 80.0 and spikes.maximum == 100.0, "slow frames were discarded")
	var rows: Array[Dictionary] = [
		{"interval_ms":8.0,"process_ms":2.0,"physics_ms":1.0,"enemies":1,"projectiles":5,"draw_calls":40},
		{"interval_ms":24.0,"process_ms":10.0,"physics_ms":5.0,"enemies":12,"projectiles":20,"draw_calls":80},
	]
	var summary: Dictionary = ledger.summarize(rows)
	check(summary.frames == 2 and is_equal_approx(summary.wall_seconds, 0.032), "observed interval duration incorrect")
	check(summary.enemy_peak == 12 and summary.projectile_peak == 20 and summary.draw_call_peak == 80, "entity/render pressure was lost")
	check(summary.intervals_over_16_667_ms == 1 and summary.intervals_over_33_333_ms == 0, "slow-frame counters incorrect")
	check(is_equal_approx(summary.effective_callback_fps, 62.5), "FPS must use actual interval sum, not CPU time")
	var empty_rows: Array[Dictionary] = []
	check(ledger.summarize(empty_rows).is_empty(), "no dense coverage incorrectly marked available")
	var invalid_rows: Array[Dictionary] = [{"interval_ms":-1.0,"process_ms":1.0,"physics_ms":1.0,"enemies":0,"projectiles":0,"draw_calls":0}]
	check(ledger.summarize(invalid_rows).is_empty(), "invalid window accepted")
	check(ledger.has_method("qualify_report"), "performance reports do not yet qualify inherited evidence and actual save checks")
	if ledger.has_method("qualify_report"):
		var inherited := {"native_scope":"source-bound GPU screenshots","native_player":{"facing":true},"health_events":[{"hit":1}]}
		var qualified: Dictionary = ledger.qualify_report(inherited,{"campaign":"abc","snapshot":"absent"},{"campaign":"abc","snapshot":"absent"})
		check(not qualified.has("native_scope") and qualified.native_player.sampled == false and qualified.health_events.sampled == false, "performance-only report retains unsampled native evidence")
		check(qualified.user_saves_preserved == true, "unchanged saves reported changed")
		check(ledger.qualify_report(inherited,{"campaign":"abc"},{"campaign":"xyz"}).user_saves_preserved == false, "changed save falsely reported preserved")
		check(ledger.qualify_report(inherited,{"campaign":"abc"},{}).user_saves_preserved == false, "missing save comparison falsely reported preserved")
		check(inherited.has("native_scope") and inherited.native_player.facing, "qualification mutated inherited input")
	if not failed: print("TEST PASS: ChapterPerformanceLedgerTest %d" % assertions)
	quit(1 if failed else 0)
