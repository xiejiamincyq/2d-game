extends SceneTree
## Controlled actual clock-state pixels plus a separate natural-clock/input route.
const Map = preload("res://scenes/world/echo_court.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Beat = preload("res://scripts/world/EchoBeat.gd")
const Clearance = preload("res://scripts/tests/EchoMovementTest.gd")
const UI_THEME = preload("res://themes/MintFarmTheme.tres")
var checks := 0
var failures := 0
var output: String
var captures: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RenderEchoBeatPreview "+label)
func _initialize() -> void: call_deferred("run")
func viewport() -> SubViewport:
	var view := SubViewport.new(); view.size = Vector2i(1280,720); view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view); return view
func label(parent: Node,value: String) -> Label:
	var ui := CanvasLayer.new(); parent.add_child(ui)
	var node := Label.new(); node.text = value; node.position = Vector2(24,16)
	node.add_theme_font_override("font",UI_THEME.default_font); node.add_theme_font_size_override("font_size",22)
	node.add_theme_color_override("font_color",Color("d0c5b6")); ui.add_child(node); return node
func capture(view: SubViewport,name: String) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	check(pixels!=null and not pixels.is_empty() and pixels.save_png(output+name)==OK,"GPU capture "+name)
	captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name)}); return pixels
func tick() -> void: await physics_frame; await process_frame
func release() -> void:
	for action in ["move_left","move_right","move_up","move_down","fire","dash_melee"]: Input.action_release(action)
func differs(a: Color,b: Color) -> bool: return Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))>0.03
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"actual GPU/fresh directory required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderEchoBeatPreview.gd","scripts/tests/EchoMovementTest.gd","scripts/tests/EchoBeatPhysicsTest.gd","scenes/world/echo_court.tscn","scripts/world/EchoMap.gd","scripts/world/EchoArenaLayout.gd","scripts/world/EchoObstacle.gd","scripts/world/EchoPropArt.gd","scripts/world/EchoFloor.gd","scripts/world/EchoBeat.gd","scripts/world/EchoField.gd","scripts/world/ArenaLayout.gd","scripts/world/TerrainSweep.gd","scripts/actors/Player.gd","scripts/components/HealthComponent.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres","themes/MintFarmTheme.tres"]:
		check(FileAccess.file_exists("res://"+path),"source missing "+path); sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"invalid SHA "+path)
	release(); RenderingServer.set_default_clear_color(Color("393542"))
	var view := viewport(); var map = Map.instantiate(); map.map_seed = 521; view.add_child(map)
	var beat = map.echo_field.get_child(0)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds
	player.position = beat.position-beat.secondary_offset.normalized()*100; map.add_child(player)
	map.layout.occlusion_target = player
	var camera := Camera2D.new(); camera.position = beat.position+beat.secondary_offset/2; view.add_child(camera)
	var heading := label(view,"回声机关 / 实战尺度的真实时钟状态采样（非游玩证明）")
	await tick(); await tick(); map.echo_field.bind_player(player); map.echo_field.set_active(true,1); beat.set_physics_process(false)
	var axis: Vector2 = beat.secondary_offset.normalized()
	var points: Array[Vector2i] = []
	for center in beat.get_beat_centers(): points.append(Vector2i(Vector2(640,360)+center-camera.position+axis.orthogonal()*20))
	var baseline: Image = await capture(view,"cooldown.png")
	for sample in [{"name":"warning-first","delta":3.4,"second":false,"pulse":false},{"name":"pulse-first","delta":0.4,"second":false,"pulse":true},{"name":"warning-second","delta":0.12,"second":true,"pulse":false},{"name":"pulse-second","delta":0.4,"second":true,"pulse":true}]:
		beat.advance(sample.delta); heading.text = "回声机关 / 受控状态 %s / 相邻双落点，单轮最多一次伤害"%sample.name
		var pixels: Image = await capture(view,sample.name+".png")
		var index := 1 if sample.second else 0; var at := points[index]; var other := points[1-index]
		check(differs(pixels.get_pixelv(at),baseline.get_pixelv(at)),"current damaging/warning disk absent "+sample.name)
		check(not differs(pixels.get_pixelv(other),baseline.get_pixelv(other)),"previous/noncurrent disk remains harmful-looking "+sample.name)
		if sample.pulse: check(pixels.get_pixelv(at).r>pixels.get_pixelv(at).b,"actual pulse lacks hostile coral semantics")
	map.echo_field.set_active(false); heading.text = "回声机关 / 所有者取消：落点与伤害一同取消，仅保留中性钟座"
	var cancelled: Image = await capture(view,"cancelled.png")
	for at in points: check(not differs(cancelled.get_pixelv(at),baseline.get_pixelv(at)),"cancelled hazard still has ground danger")
	view.free(); await process_frame
	# New independent viewport: no manual clock advancement, actor teleport or stat edits.
	var live := viewport(); var actual_map = Map.instantiate(); actual_map.map_seed = 521; live.add_child(actual_map)
	var actual_beat = actual_map.echo_field.get_child(0)
	var actual_player := Player.new(); actual_player.world_bounds = actual_map.layout.world_bounds; actual_player.position = actual_beat.position; actual_map.add_child(actual_player)
	actual_map.layout.occlusion_target = actual_player
	var follower := Camera2D.new(); follower.position = actual_player.position; live.add_child(follower)
	var caption := label(live,"自然时钟 / 真实玩家 / 0.15秒反应后普通方向输入离开首拍")
	live.notify_mouse_entered(); var mouse := InputEventMouseMotion.new(); mouse.position = Vector2(900,360); live.push_input(mouse,true)
	check(live.get_mouse_position().distance_to(mouse.position)<0.001,"actual pointer differs")
	await tick(); await tick(); actual_map.echo_field.bind_player(actual_player); actual_map.echo_field.set_active(true,1)
	var before: float = actual_player.health.current_health+actual_player.shield
	var deadline := Time.get_ticks_msec()+6000
	while actual_beat.state!=Beat.State.WARNING_FIRST and Time.get_ticks_msec()<deadline: await tick()
	check(actual_beat.state==Beat.State.WARNING_FIRST,"natural GPU clock has no warning")
	await capture(live,"natural-warning.png")
	for _step in ceili(Engine.physics_ticks_per_second*0.15): await tick()
	var away: Vector2 = -actual_beat.secondary_offset.normalized(); var moves := 0; var pulses := 0
	for axis_input in [["move_left",-away.x],["move_right",away.x],["move_up",-away.y],["move_down",away.y]]:
		if axis_input[1]>0: Input.action_press(axis_input[0],axis_input[1])
	for _step in ceili(Engine.physics_ticks_per_second*0.7):
		var at := actual_player.position; await physics_frame; follower.position = actual_player.position; await process_frame
		if actual_player.position.distance_to(at)>0.01: moves += 1
		pulses += 1 if actual_beat.state in [Beat.State.PULSE_FIRST,Beat.State.PULSE_SECOND] else 0
		check(Clearance.has_clearance(actual_player.position,actual_map.layout.world_bounds,actual_map.layout.get_obstacle_descriptors(),actual_player.get_body_radius()),"full Player overlaps terrain")
		check(actual_player.health.current_health+actual_player.shield==before,"natural GPU route requires invulnerability")
	release(); check(moves>20 and pulses>0 and is_equal_approx(actual_player.move_speed,235),"normal GPU escape does not observe actual motion/pulse")
	caption.text = "自然时钟 / 普通输入已离开两拍 / 当前生命100，无加速、无传送、无冲刺"
	await capture(live,"natural-escape.png"); live.size = Vector2i(960,540); await capture(live,"natural-960.png")
	live.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"actual_adjacent_moves":moves,"natural_pulse_frames":pulses,"scope":"Original native local two-beat ground pixels and cancellation; six explicitly controlled clock-state captures, then a separate natural-clock actual-Player ordinary-input escape at1280/960. No fifth-region encounters/Boss/readiness/save-unlock6, OS mouse, human playtest, dense performance, final licensing or six-chapter completion."},"\t")); file.close()
	if not failures: print("TEST PASS: RenderEchoBeatPreview %d; %d captures; %d adjacent moves"%[checks,captures.size(),moves])
	quit(1 if failures else 0)
