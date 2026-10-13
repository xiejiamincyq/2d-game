extends SceneTree
## Author-only GPU map review with real Player input, never a chapter clear.
const Map = preload("res://scenes/world/salt_waterway.tscn")
const Prop = preload("res://scripts/world/SaltObstacle.gd")
const Player = preload("res://scripts/actors/Player.gd")
const UI_THEME = preload("res://themes/MintFarmTheme.tres")
var failures := 0
var checks := 0
var output: String
var captures: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("SALT MAP GPU FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func viewport(size: Vector2i) -> SubViewport:
	var view := SubViewport.new()
	view.size = size
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	return view
func label(parent: Node,value: String,at: Vector2) -> void:
	var text := Label.new()
	text.text = value
	text.position = at
	text.add_theme_font_override("font",UI_THEME.default_font)
	text.add_theme_font_size_override("font_size",22)
	text.add_theme_color_override("font_color",Color("e3d4b3"))
	parent.add_child(text)
func capture(view: SubViewport,name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	check(pixels!=null and not pixels.is_empty() and pixels.save_png(output+name)==OK,"capture "+name)
	captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name)})
	return pixels
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU/new directory required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderSaltMapPreview.gd","scenes/world/salt_waterway.tscn","scripts/world/SaltMap.gd","scripts/world/SaltArenaLayout.gd","scripts/world/SaltObstacle.gd","scripts/world/SaltPropArt.gd","scripts/world/SaltFloor.gd","scripts/world/ArenaLayout.gd","scripts/actors/Player.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"missing source "+path)
	RenderingServer.set_default_clear_color(Color("303f43"))
	var style := viewport(Vector2i(1280,900))
	label(style,"盐蚀水道 / 原创原生纸面样板 · 上2x细节 / 下实战尺度",Vector2(24,18))
	var roles: Array[StringName] = [&"reservoir",&"sluice_wall"]
	var sizes := [Vector2(290,180),Vector2(72,112)]
	for index in 2:
		label(style,["不可通行蓄水池（实色全碰撞）","矮闸墙（上部遮挡可淡化）"][index],Vector2(50+index*620,74))
		for row in 2:
			var prop := Prop.new()
			prop.setup(Rect2(Vector2.ZERO,sizes[index]),roles[index])
			prop.position = Vector2(330+index*620,540 if row==0 else 850)
			prop.scale = Vector2.ONE*(2 if row==0 else 1)
			style.add_child(prop)
			var safe := Rect2(8,100 if row==0 else 615,1264,465 if row==0 else 270)
			check(safe.encloses(prop.global_transform*prop.occlusion_rect.grow(3)),"sample clipped "+str(roles[index]))
	label(style,"深色水体与闸墙是真实障碍；浅色堤道与外圈可通行。潮带危险机制尚未接入。",Vector2(24,578))
	var style_pixels: Image = await capture(style,"props.png")
	check(style_pixels.get_pixel(626,196).is_equal_approx(Color("303f43")),"salt bank ornament extends outside its solid footprint")
	style.free()
	for seed_value in [0,521,20261011]:
		var overview := viewport(Vector2i(1280,720))
		var map = Map.instantiate()
		map.map_seed = seed_value
		overview.add_child(map)
		var camera := Camera2D.new()
		camera.zoom = Vector2.ONE*0.30
		overview.add_child(camera)
		var ui := CanvasLayer.new()
		overview.add_child(ui)
		label(ui,"第3关地图资源 / 种子%s / 全图审查，非玩家实战视野与通关"%seed_value,Vector2(24,16))
		await capture(overview,"overview-%s.png"%seed_value)
		overview.free()
	var live := viewport(Vector2i(1280,720))
	var map = Map.instantiate()
	map.map_seed = 521
	live.add_child(map)
	var camera := Camera2D.new()
	var passage: Rect2 = map.layout.get_causeways()[0]
	camera.position = passage.get_center()
	live.add_child(camera)
	var player := Player.new()
	player.world_bounds = map.layout.world_bounds
	player.position = passage.get_center()
	map.add_child(player)
	map.layout.occlusion_target = player
	live.notify_mouse_entered()
	var mouse := InputEventMouseMotion.new()
	mouse.position = Vector2(840,360)
	live.push_input(mouse)
	var ui := CanvasLayer.new()
	live.add_child(ui)
	label(ui,"原生玩家 + 真实堤道普通移动 / 非第三关战斗、桌面鼠标或真人试玩",Vector2(24,16))
	var start_pixels: Image = await capture(live,"runtime-start.png")
	var probe: Vector2 = live.get_canvas_transform()*map.layout.get_obstacle_descriptors()[0].rect.get_center()
	check(Rect2(Vector2.ZERO,Vector2(live.size)).has_point(probe),"basin pixel probe outside camera")
	if Rect2(Vector2.ZERO,Vector2(live.size)).has_point(probe):
		var color := start_pixels.get_pixelv(Vector2i(probe))
		check(color.a>0.99 and color.b>color.r+0.05,"blocked basin lacks opaque blue identity")
	var moves := 0
	var vertical := passage.size.x<passage.size.y
	var action := "move_up" if vertical else "move_right"
	Input.action_press(action)
	for _frame in 60:
		var before := player.position
		await physics_frame
		await process_frame
		moves += 1 if player.position.distance_to(before)>0.01 else 0
		check(map.layout.is_position_walkable(player.position,12.5),"real Player embeds in blocked water")
	Input.action_release(action)
	check(moves>10,"input produced no real movement")
	await capture(live,"runtime-end.png")
	live.free()
	await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed "+path)
	var report := {"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"actual_adjacent_moves":moves,"scope":"Original native scenery, three seeded geometry overviews, GPU opaque basin pixel and actual Player/physics dry causeway input fixture. No tidal hazard, encounter, Boss, readiness, OS mouse, human playtest or six-chapter completion."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	if not failures: print("SALT MAP GPU PASS: %d checks/6 captures/%d adjacent movements"%[checks,moves])
	quit(1 if failures else 0)
