extends SceneTree
## Actual GPU map/Player/authoritative tidal clock. Not a third-chapter encounter.
const Map = preload("res://scenes/world/salt_waterway.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Band = preload("res://scripts/world/SaltTidalBand.gd")
const UI_THEME = preload("res://themes/MintFarmTheme.tres")
var checks := 0
var failures := 0
var output: String
var captures: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("SALT TIDE GPU FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func wait_for(predicate: Callable,seconds: float = 4.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline: await tick()
	return predicate.call()
func capture(view: SubViewport,name: String) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	check(not pixels.is_empty() and pixels.save_png(output+name)==OK,"capture "+name)
	captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name)})
	return pixels
func label(parent: Node) -> void:
	var text := Label.new()
	text.text = "盐蚀潮带 / 真实时钟与普通输入资源验证 · 非第三关战斗、桌面鼠标或真人试玩"
	text.position = Vector2(24,16)
	text.add_theme_font_override("font",UI_THEME.default_font)
	text.add_theme_font_size_override("font_size",22)
	text.add_theme_color_override("font_color",Color("e3d4b3"))
	parent.add_child(text)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU/new directory required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderSaltTidalPreview.gd","scenes/world/salt_waterway.tscn","scripts/world/SaltMap.gd","scripts/world/SaltArenaLayout.gd","scripts/world/SaltObstacle.gd","scripts/world/SaltPropArt.gd","scripts/world/SaltFloor.gd","scripts/world/SaltTidalBand.gd","scripts/world/SaltTidalField.gd","scripts/world/ArenaLayout.gd","scripts/actors/Player.gd","scripts/components/HealthComponent.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"missing source "+path)
	RenderingServer.set_default_clear_color(Color("303f43"))
	var view := SubViewport.new(); view.size = Vector2i(1280,720)
	view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var map = Map.instantiate(); map.map_seed = 521; view.add_child(map)
	var field = map.tidal_field
	var area: Rect2 = field.get_sites()[0]
	var band = field.get_child(0)
	var camera := Camera2D.new(); camera.position = area.get_center(); view.add_child(camera)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds
	player.position = area.get_center(); view.add_child(player)
	map.layout.occlusion_target = player
	view.notify_mouse_entered()
	var mouse := InputEventMouseMotion.new(); mouse.position = Vector2(840,360); view.push_input(mouse)
	var ui := CanvasLayer.new(); view.add_child(ui); label(ui)
	await tick(); await tick()
	field.bind_player(player)
	var before: float = player.health.current_health+player.shield
	var idle: Image = await capture(view,"inactive.png")
	check(not field.active and band.state==Band.State.INACTIVE,"default field harms")
	field.set_active(true,1)
	check(await wait_for(func(): return band.state==Band.State.WARNING),"actual warning missing")
	var warning: Image = await capture(view,"warning.png")
	check(player.health.current_health+player.shield==before,"warning damages")
	check(await wait_for(func(): return band.state==Band.State.ACTIVE),"actual active missing")
	var active: Image = await capture(view,"active.png")
	check(is_equal_approx(before-player.health.current_health-player.shield,18),"actual damage path18")
	# Probe only hazard pixels away from the actor/HUD; no negative-only art proof.
	var image_rect: Rect2 = view.get_canvas_transform()*area.grow(-5)
	var warning_pixels := 0; var active_pixels := 0
	for y in range(int(image_rect.position.y),int(image_rect.end.y)):
		for x in range(int(image_rect.position.x),int(image_rect.end.x)):
			if Vector2(x,y).distance_to(Vector2(640,360))<90: continue
			if x<0 or y<80 or x>=1280 or y>=720: continue
			var base := idle.get_pixel(x,y)
			if not warning.get_pixel(x,y).is_equal_approx(base): warning_pixels += 1
			if not active.get_pixel(x,y).is_equal_approx(base): active_pixels += 1
	check(warning_pixels>400 and active_pixels>1000,"independent positive warning/danger pixels absent")
	var damaged: float = player.health.current_health+player.shield
	paused = true; await tick(); await tick()
	var canceled: Image = await capture(view,"paused.png")
	check(band.state==Band.State.INACTIVE,"pause leaves visual danger")
	var residual := 0
	for y in range(int(image_rect.position.y),int(image_rect.end.y)):
		for x in range(int(image_rect.position.x),int(image_rect.end.x)):
			if Vector2(x,y).distance_to(Vector2(640,360))<90: continue
			if x<0 or y<80 or x>=1280 or y>=720: continue
			if not canceled.get_pixel(x,y).is_equal_approx(idle.get_pixel(x,y)): residual += 1
	check(residual==0,"pause leaves hazard pixels outside actors")
	paused = false; await tick(); await tick()
	check(band.state==Band.State.COOLDOWN and band.remaining>1.6,"unsafe resume")
	await capture(view,"resume.png")
	var action := "move_right" if area.size.x<area.size.y else "move_down"
	Input.action_press(action)
	var moves := 0
	for _frame in 24:
		var prior := player.position; await tick()
		moves += 1 if player.position.distance_to(prior)>0.01 else 0
		check(map.layout.is_position_walkable(player.position,12.5),"ordinary movement enters water")
	Input.action_release(action)
	check(moves>10 and not area.grow(13).has_point(player.position),"ordinary move cannot exit channel")
	check(player.health.current_health+player.shield==damaged,"safe cooldown/movement hurts")
	await capture(view,"ordinary-exit.png")
	player.health.damage(player.health.current_health,true)
	check(not field.active and field.get_children().all(func(child): return not child.enabled),"actual death leaves armed tides")
	await tick(); await capture(view,"death-cleared.png")
	view.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed "+path)
	var report := {"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"actual_adjacent_moves":moves,"warning_positive_pixels":warning_pixels,"active_positive_pixels":active_pixels,"paused_residual_pixels":residual,"actual_damage":before-damaged,"scope":"Actual native map, live tidal clock, real Player take_damage, pause/resume/ordinary directional input and direct health-death lifecycle fixture. Not chapter encounter, natural victory, OS mouse, human playtest, performance or six-chapter completion."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	if not failures: print("SALT TIDE GPU PASS: %d checks/7 captures/%d actual moves"%[checks,moves])
	quit(1 if failures else 0)
