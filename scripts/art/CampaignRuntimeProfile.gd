extends RefCounted
## Author-only real frame callback recorder; never advances or modifies gameplay.
const Timing=preload("res://scripts/art/ChapterPerformanceLedger.gd")
const MAX_ROWS:=60000
var rows: Array[Dictionary]=[]
var overflow:=false
var invalid_clock:=false
var warmup_frames:=0
var limit:=MAX_ROWS
var last_wall:=0
var phase_started:=0
var last_phase:=""
var last_frame:=-1
var callback_index:=0
var window_id:=0
var provider:=Callable()

func _init(row_limit: int=MAX_ROWS) -> void:
	limit=clampi(row_limit,1,MAX_ROWS)

func ingest(now: int,frame: int,phase: String,enemies: int,projectiles: int,stats: Dictionary) -> void:
	callback_index+=1
	if phase.is_empty():
		last_wall=0; last_phase=""; last_frame=-1
		return
	if last_wall>0 and (now<=last_wall or frame<=last_frame):
		invalid_clock=true
		return
	if phase!=last_phase or last_wall==0:
		window_id+=1
		last_phase=phase; phase_started=now; last_wall=now; last_frame=frame
		return
	var previous_wall:=last_wall
	var interval:=float(now-last_wall)/1000.0
	last_wall=now; last_frame=frame
	if now-phase_started<2000000:
		warmup_frames+=1
		return
	if rows.size()>=limit:
		overflow=true
		return
	var row:=stats.duplicate()
	row.merge({"frame":frame,"callback_index":callback_index,"window_id":window_id,"wall_usec":now,"previous_wall_usec":previous_wall,"phase":phase,"interval_ms":interval,"enemies":enemies,"projectiles":projectiles},true)
	rows.append(row)

func attach(lookup: Callable) -> bool:
	if not lookup.is_valid() or RenderingServer.frame_post_draw.is_connected(_observe): return false
	provider=lookup
	RenderingServer.frame_post_draw.connect(_observe)
	return true

func _observe() -> void:
	var live: Node=provider.call() if provider.is_valid() else null
	var director: Node=live.get("director") if is_instance_valid(live) and live.has_method("_chapter_number") else null
	if not is_instance_valid(director) or live.get_tree().paused or director.state not in [director.State.COMBAT,director.State.BOSS]:
		ingest(0,0,"",0,0,{})
		return
	var phase:="%s:%d"%[director.State.keys()[director.state],director.encounter_index]
	ingest(Time.get_ticks_usec(),Engine.get_process_frames(),phase,director.get_active_enemies().size(),live.projectiles.get_child_count(),{
		"process_ms":float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0,
		"physics_ms":float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.0,
		"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects":int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))})

func finish() -> Dictionary:
	if RenderingServer.frame_post_draw.is_connected(_observe): RenderingServer.frame_post_draw.disconnect(_observe)
	provider=Callable()
	var combat: Array[Dictionary]=[]
	var boss: Array[Dictionary]=[]
	var dense: Array[Dictionary]=[]
	var streak:=0.0
	var longest:=0.0
	var previous_frame:=-1
	var previous_phase:=""
	var previous_window:=-1
	for row in rows:
		if row.phase.begins_with("BOSS"): boss.append(row)
		else: combat.append(row)
		if row.enemies<12: continue
		dense.append(row)
		streak=streak+row.interval_ms if row.callback_index==previous_frame+1 and row.phase==previous_phase and row.window_id==previous_window else 0.0
		longest=maxf(longest,streak)
		previous_frame=row.callback_index; previous_phase=row.phase
		previous_window=row.window_id
	var fixed_argument:=false
	for argument in OS.get_cmdline_args():
		if argument=="--fixed-fps" or argument.begins_with("--fixed-fps="): fixed_argument=true
	return {"sampled":true,"raw_rows":rows,"overflow":overflow,"invalid_clock":invalid_clock,"warmup_frames":warmup_frames,
		"all":Timing.summarize(rows),"combat":Timing.summarize(combat),"boss":Timing.summarize(boss),"dense_at_least_12":Timing.summarize(dense),
		"longest_contiguous_dense_seconds":longest/1000.0,"dense_coverage_available":longest>=5000.0,
		"complete":not overflow and not invalid_clock and rows.size()>=1000 and not combat.is_empty() and not boss.is_empty(),
		"warmup_seconds_per_phase":2,"sampling_image_readbacks":0,"fixed_fps_argument":fixed_argument,
		"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),
		"driver":RenderingServer.get_current_rendering_driver_name(),"audio_driver":AudioServer.get_driver_name(),"display_server":DisplayServer.get_name(),
		"scope":"Actual frame_post_draw wall intervals in ordinary COMBAT/BOSS including diagnostic input/clearance and telemetry overhead; not OS presentation or minimum-hardware FPS. CPU monitors may update less often than frames. Slow frames retained; two-second phase warmups; no GPU image readbacks during sampled combat. Dense coverage is measured, never assumed."}
