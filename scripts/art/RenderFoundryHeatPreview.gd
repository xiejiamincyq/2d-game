extends SceneTree
## Author-only native pixels and actual Player input; never chapter readiness.
const Map = preload("res://scenes/world/ember_foundry.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Vent = preload("res://scripts/world/FoundryHeatVent.gd")
var checks := 0
var failures := 0
var output: String
var captures: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FOUNDRY HEAT GPU FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func viewport(size: Vector2i) -> SubViewport:
	var view := SubViewport.new(); view.size = size; view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	return view
func capture(view: SubViewport,name: String) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	check(not pixels.is_empty() and pixels.save_png(output+name)==OK,"capture "+name)
	captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name)})
	return pixels
func wait_state(vent: Node,state: int) -> bool:
	var end := Time.get_ticks_msec()+3000
	while vent.state!=state and Time.get_ticks_msec()<end: await physics_frame
	return vent.state==state
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU/new folder required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderFoundryHeatPreview.gd","scripts/world/FoundryHeatVent.gd","scripts/world/FoundryHeatField.gd","scripts/world/FoundryMap.gd","scenes/world/ember_foundry.tscn","scripts/world/FoundryArenaLayout.gd","scripts/world/ArenaLayout.gd","scripts/world/FoundryObstacle.gd","scripts/world/FoundryPropArt.gd","scripts/world/FoundryFloor.gd","scripts/actors/Player.gd","scripts/components/NativePlayerMotion.gd","scripts/components/NativePlayerView.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"source missing "+path)
	RenderingServer.set_default_clear_color(Color("39403e"))
	var live := viewport(Vector2i(1280,720))
	var map = Map.instantiate(); map.map_seed = 521; live.add_child(map)
	var player := Player.new()
	var at: Vector2 = map.heat_field.get_sites()[0]
	player.position = map.layout.resolve_spawn_position(at+Vector2(-80,0),13)
	player.world_bounds = map.layout.world_bounds; map.add_child(player)
	map.layout.occlusion_target = player
	var camera := Camera2D.new(); camera.position = at; live.add_child(camera)
	map.heat_field.bind_player(player); map.heat_field.set_active(true)
	var vent = map.heat_field.get_child(0)
	check(await wait_state(vent,Vent.State.WARNING),"real warning")
	await capture(live,"runtime-warning.png")
	check(await wait_state(vent,Vent.State.ACTIVE),"real danger")
	var before: float = player.health.current_health+player.shield
	var moves := 0
	Input.action_press("move_right")
	for frame in 35:
		var previous := player.position
		await physics_frame; await process_frame
		moves += 1 if previous.distance_to(player.position)>0.01 else 0
		if frame==15: await capture(live,"runtime-active.png")
	Input.action_release("move_right")
	check(moves>10,"actual input stuck")
	var damage: float = before-player.health.current_health-player.shield
	check(is_equal_approx(damage,18),"real input vent crossing 18 damage, once")
	check(await wait_state(vent,Vent.State.COOLDOWN),"real cooling")
	await capture(live,"runtime-cooling.png")
	map.heat_field.set_active(false); await capture(live,"runtime-disabled.png")
	var detail := viewport(Vector2i(192,192))
	var sample := Vent.new(); detail.add_child(sample); sample.set_physics_process(false)
	sample.configure(map.layout,player,Vector2.ZERO)
	# Same runtime drawing, only phase is manually sampled for isolated pixels.
	sample.position = Vector2(96,96)
	sample.state = Vent.State.COOLDOWN; sample.queue_redraw()
	var base := await capture(detail,"vent-cooling-1x.png")
	var positive := {}
	for phase in [Vent.State.WARNING,Vent.State.ACTIVE]:
		sample.state = phase; sample.remaining = 0.3; sample.queue_redraw()
		var pixels := await capture(detail,"vent-%s-1x.png"%phase)
		var count := 0
		for y in pixels.get_height():
			for x in pixels.get_width():
				if pixels.get_pixel(x,y).is_equal_approx(base.get_pixel(x,y)): continue
				count += 1
				check(Vector2(x-96,y-96).length()<50,"danger pixels outside advertised compact footprint")
		check(count>100,"phase has no actual visible positive pixels")
		positive[str(phase)] = count
	detail.free(); live.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed "+path)
	var report := {"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"actual_adjacent_moves":moves,"real_crossing_damage":damage,"isolated_positive_pixels":positive,"scope":"Original native heat vent phases + actual map/Player ordinary-input crossing fixture. No second-chapter encounters, Boss victory, readiness, human playtest or performance claim."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	if not failures: print("FOUNDRY HEAT GPU PASS: %d checks/%d moves/18 damage"%[checks,moves])
	quit(1 if failures else 0)
