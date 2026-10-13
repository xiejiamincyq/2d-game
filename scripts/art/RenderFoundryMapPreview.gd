extends SceneTree
## Author-only original environment + real map/Player input. Not chapter completion.
const Map = preload("res://scenes/world/ember_foundry.tscn")
const Prop = preload("res://scripts/world/FoundryObstacle.gd")
const Player = preload("res://scripts/actors/Player.gd")
const UI_THEME = preload("res://themes/MintFarmTheme.tres")
var failures := 0
var checks := 0
var output: String
var captures: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FOUNDRY GPU FAIL: "+label)
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
func capture(view: SubViewport,name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	check(pixels!=null and not pixels.is_empty() and pixels.save_png(output+name)==OK,"capture failed "+name)
	captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name)})
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU/new output folder required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderFoundryMapPreview.gd","scenes/world/ember_foundry.tscn","scripts/world/FoundryMap.gd","scripts/world/FoundryArenaLayout.gd","scripts/world/FoundryObstacle.gd","scripts/world/FoundryPropArt.gd","scripts/world/FoundryFloor.gd","scripts/world/ArenaLayout.gd","scripts/actors/Player.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"missing source "+path)
	RenderingServer.set_default_clear_color(Color("303936"))
	var style := viewport(Vector2i(1600,900))
	label(style,"余烬铸坊 / 原创纸偶环境样板 · 上2x细节 / 下实战尺度",Vector2(24,18))
	var roles: Array[StringName] = [&"furnace",&"pipe_bank",&"slag_stack"]
	var sizes := [Vector2(190,160),Vector2(220,80),Vector2(148,116)]
	for index in 3:
		label(style,["熔炉（固体障碍）","管道组（实体断口可通行）","堆料工位"][index],Vector2(70+index*520,74))
		for row in 2:
			var prop := Prop.new()
			prop.setup(Rect2(Vector2.ZERO,sizes[index]),roles[index])
			prop.position = Vector2(270+index*520,540 if row==0 else 850)
			prop.scale = Vector2.ONE*(2 if row==0 else 1)
			style.add_child(prop)
			var safe := Rect2(8,100 if row==0 else 615,1584,465 if row==0 else 270)
			check(safe.encloses(prop.global_transform*prop.occlusion_rect.grow(3)),"style sample clipped/overlaps labels "+str(roles[index]))
	label(style,"实色底座对应完整碰撞；上部装饰在遮挡玩家时变淡。此地图夹具未启用热区危险。",Vector2(24,578))
	await capture(style,"props.png")
	style.free()
	for seed_value in [0,30,521,20261011]:
		var overview := viewport(Vector2i(1280,720))
		var map = Map.instantiate()
		map.map_seed = seed_value
		overview.add_child(map)
		var camera := Camera2D.new()
		camera.zoom = Vector2.ONE*0.31
		overview.add_child(camera)
		var ui := CanvasLayer.new()
		overview.add_child(ui)
		label(ui,"第2关地图资源 / 种子%s / 全图审查，非实战视野与关卡通关"%seed_value,Vector2(24,16))
		await capture(overview,"overview-%s.png"%seed_value)
		overview.free()
	var live := viewport(Vector2i(1280,720))
	var map = Map.instantiate()
	map.map_seed = 521
	live.add_child(map)
	var camera := Camera2D.new()
	camera.position = Vector2(700,-200)
	live.add_child(camera)
	var player := Player.new()
	player.world_bounds = map.layout.world_bounds
	player.position = map.layout.resolve_spawn_position(Vector2(650,80),player.get_body_radius())
	map.add_child(player)
	map.layout.occlusion_target = player
	var ui := CanvasLayer.new()
	live.add_child(ui)
	label(ui,"原生玩家 + 真实随机铸坊 / 普通移动输入夹具，非第二关战斗",Vector2(24,16))
	await capture(live,"runtime-start.png")
	var moves := 0
	Input.action_press("move_up")
	for _frame in 60:
		var before := player.position
		await physics_frame
		await process_frame
		moves += 1 if player.position.distance_to(before)>0.01 else 0
	Input.action_release("move_up")
	check(moves>10,"ordinary input produced no real movement")
	await capture(live,"runtime-end.png")
	live.free()
	await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed during proof "+path)
	var report := {"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"actual_adjacent_moves":moves,"scope":"Original native style group, 4 seeded map overviews including fixed failed seed30, actual Player/physics input fixture. No heat hazard, encounters, Boss fight, chapter readiness, human playtest or six chapter completion."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	if not failures: print("FOUNDRY GPU PASS: %d checks/%d captures/%d adjacent movements"%[checks,captures.size(),moves])
	quit(1 if failures else 0)
