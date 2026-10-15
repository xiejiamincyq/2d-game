extends "res://scripts/art/VerifyChapterBuildRun.gd"
## Read-only native frame-callback baseline during actual ordinary gameplay.
const Timing = preload("res://scripts/art/ChapterPerformanceLedger.gd")
const Snapshot = preload("res://scripts/tests/fixtures/LegacyRunSnapshotStore.gd")
const EXTENTS := {"960":Vector2i(960,540),"1280":Vector2i(1280,720),"1920":Vector2i(1920,1080)}
const SAMPLE_LIMIT := 60000
var extent := Vector2i(1280,720)
var timing_rows: Array[Dictionary] = []
var last_wall_usec := 0
var phase_started_usec := 0
var last_phase := ""
var warmup_frames := 0
var user_save_hashes := {}
var sample_overflow := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 5 or not ChainEvidence.safe_id(args[0]) or args[1] not in EVOLUTION_IDS or args[2] not in ["supply","risk"] or not args[3].is_valid_int() or not EXTENTS.has(args[4]):
		quit(1)
		return
	initial_rng_seed = int(args[3])
	if initial_rng_seed < 0 or initial_rng_seed > 2147483647:
		quit(1)
		return
	family = args[1]
	build_route = StringName(args[2])
	aim_mode = "compensated"
	extent = EXTENTS[args[4]]
	output = ChainEvidence.EVIDENCE_ROOT + args[0] + "/"
	chain_context = ChainEvidence.parse_arguments(PackedStringArray(),1)
	additional_sources = ["scripts/art/VerifyChapterPerformance.gd","scripts/art/ChapterPerformanceLedger.gd","scripts/art/VerifyChapterBuildRun.gd","scripts/art/DiagnosticProjectileAim.gd","scripts/art/VerifyNativePlayerChapter.gd"]
	call_deferred("_run")

func prepare_campaign_progress(path: String) -> bool:
	for save in [Store.DEFAULT_PATH,Snapshot.DEFAULT_PATH]:
		user_save_hashes[save] = FileAccess.get_sha256(save) if FileAccess.file_exists(save) else "absent"
	return super.prepare_campaign_progress(path)

func prepare_scene_host() -> void:
	root.size = extent
	await super.prepare_scene_host()
	build_view.size = extent
	# Main's compatibility SnapshotStore is isolated before its _ready reads it.
	build_view.child_entered_tree.connect(func(node: Node) -> void:
		if node.get_script() != null and node.get_script().resource_path == "res://scripts/Main.gd":
			node.set("audio_enabled",true)
			node.child_entered_tree.connect(func(child: Node) -> void:
				if child is Snapshot: child.save_path = output + "isolated-wave-snapshot.json"
			)
	)

func prepare_layout_capture(chapter: Node) -> void:
	super.prepare_layout_capture(chapter)
	check(chapter.get_viewport() == build_view and build_view.size == extent, "actual viewport resolution mismatch")
	check(chapter.audio_enabled and not chapter.audio.silent_mode, "real audio nodes disabled in performance fixture")
	RenderingServer.frame_post_draw.connect(_observe_frame)

func _capture(chapter: Node, step: int, label: String) -> void:
	# Intentionally no GPU image readbacks/file hashing during sampling.
	samples.append({"step":step,"label":label,"physics_frame":Engine.get_physics_frames(),"state":chapter.director.state,"kills":chapter.kills,"shots":shots,"image_readback":false})

func _observe_frame() -> void:
	var live: Node = actual_scene()
	if not is_instance_valid(live) or not live.has_method("_chapter_number") or paused or live.director.state not in [live.director.State.COMBAT,live.director.State.BOSS]:
		last_wall_usec = 0
		last_phase = ""
		return
	var now := Time.get_ticks_usec()
	var phase := "%s:%d" % [live.director.State.keys()[live.director.state],live.director.encounter_index]
	if phase != last_phase:
		last_phase = phase
		phase_started_usec = now
		last_wall_usec = now
		return
	var interval_ms := float(now - last_wall_usec) / 1000.0
	last_wall_usec = now
	if now - phase_started_usec < 2000000:
		warmup_frames += 1
		return
	if timing_rows.size() >= SAMPLE_LIMIT:
		sample_overflow = true
		return
	timing_rows.append({"frame":Engine.get_process_frames(),"wall_usec":now,"phase":phase,
		"interval_ms":interval_ms,"process_ms":float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0,
		"physics_ms":float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.0,
		"enemies":live.director.get_active_enemies().size(),"projectiles":live.projectiles.get_child_count(),
		"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects":int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))})

func additional_report() -> Dictionary:
	if RenderingServer.frame_post_draw.is_connected(_observe_frame): RenderingServer.frame_post_draw.disconnect(_observe_frame)
	var report := super.additional_report()
	var dense: Array[Dictionary] = []
	var combat: Array[Dictionary] = []
	var boss: Array[Dictionary] = []
	for row in timing_rows:
		if row.enemies >= 12: dense.append(row)
		if row.phase.begins_with("BOSS"): boss.append(row)
		else: combat.append(row)
	var dense_streak_ms := 0.0
	var longest_dense_ms := 0.0
	var previous_frame := -1
	var previous_phase := ""
	for row in dense:
		if row.frame != previous_frame + 1 or row.phase != previous_phase:
			dense_streak_ms = 0.0
		else:
			dense_streak_ms += row.interval_ms
		longest_dense_ms = maxf(longest_dense_ms,dense_streak_ms)
		previous_frame = row.frame
		previous_phase = row.phase
	check(not sample_overflow and timing_rows.size() >= 1000 and not combat.is_empty() and not boss.is_empty(), "incomplete or overflowing performance sample")
	var save_hashes_after := {}
	for save in user_save_hashes:
		var after: String = FileAccess.get_sha256(save) if FileAccess.file_exists(save) else "absent"
		save_hashes_after[save] = after
		check(after == user_save_hashes[save], "real player save changed during isolated measurement")
	report = Timing.qualify_report(report,user_save_hashes,save_hashes_after)
	report["performance"] = {"schema":1,"viewport":[extent.x,extent.y],"engine":Engine.get_version_info(),
		"adapter":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"audio_driver":AudioServer.get_driver_name(),"warmup_seconds_per_phase":2,"warmup_frames":warmup_frames,
		"overflow":sample_overflow,"raw_rows":timing_rows,"all":Timing.summarize(timing_rows),
		"combat":Timing.summarize(combat),"boss":Timing.summarize(boss),"dense_at_least_12":Timing.summarize(dense),
		"longest_contiguous_dense_seconds":longest_dense_ms / 1000.0,"dense_coverage_available":longest_dense_ms >= 5000.0,
		"user_save_hashes_before":user_save_hashes,"user_save_hashes_after":save_hashes_after,
		"user_saves_preserved":report.user_saves_preserved,"sampling_image_readbacks":0,
		"cpu_monitor_scope":"Godot Performance telemetry, not independent per-frame profiling; monitors may update less frequently than callbacks. Repeated values are retained, never interpreted as precise per-frame CPU cost attribution.",
		"scope":"Actual first-chapter ordinary risk/supply combat and real Boss; no actor stat/damage/reward/spawn writes or frozen actors. Wall intervals are native frame_post_draw callbacks including diagnostic input/clearance overhead, not OS presented-frame or minimum-hardware guarantees. CPU process/physics telemetry is separate from frame intervals. Audio nodes enabled; actual audio driver recorded. Two-second phase warmups, no outlier filtering or capture readbacks. Dense coverage excludes the first interval of each dense streak, is explicit, not assumed. Source-bound original build driver and isolated saves; no screenshots or native pose/health observations in this run."}
	return report

func proof_marker() -> String: return "VerifyChapterPerformance"
