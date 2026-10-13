extends SceneTree
## Author-only original map/opaque bases/current Player input. Not chapter combat.
const Map = preload("res://scenes/world/echo_court.tscn")
const Prop = preload("res://scripts/world/EchoObstacle.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Clearance = preload("res://scripts/tests/EchoMovementTest.gd")
const UI_THEME = preload("res://themes/MintFarmTheme.tres")
var checks := 0
var failures := 0
var output: String
var captures: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RenderEchoMapPreview "+label)
func _initialize() -> void: call_deferred("run")
func viewport(size: Vector2i) -> SubViewport:
	var view := SubViewport.new(); view.size = size; view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view); return view
func label(parent: Node,text: String,at: Vector2) -> void:
	var node := Label.new(); node.text = text; node.position = at
	node.add_theme_font_override("font",UI_THEME.default_font); node.add_theme_font_size_override("font_size",22)
	node.add_theme_color_override("font_color",Color("d0c5b6")); parent.add_child(node)
func capture(view: SubViewport,name: String) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	check(pixels!=null and not pixels.is_empty() and pixels.save_png(output+name)==OK,"actual GPU capture "+name)
	captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name)}); return pixels
func release() -> void:
	for action in ["move_left","move_right","move_up","move_down","fire","dash_melee"]: Input.action_release(action)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU and fresh evidence required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderEchoMapPreview.gd","scripts/tests/EchoMovementTest.gd","scenes/world/echo_court.tscn","scripts/world/EchoMap.gd","scripts/world/EchoArenaLayout.gd","scripts/world/EchoObstacle.gd","scripts/world/EchoPropArt.gd","scripts/world/EchoFloor.gd","scripts/world/ArenaLayout.gd","scripts/world/TerrainSweep.gd","scripts/actors/Player.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres","themes/MintFarmTheme.tres"]:
		check(FileAccess.file_exists("res://"+path),"missing proof source "+path); sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"invalid source SHA "+path)
	if failures: quit(1); return
	RenderingServer.set_default_clear_color(Color("393542")); release()
	var style := viewport(Vector2i(1280,860)); style.transparent_bg = true
	label(style,"回声墓庭 / 原创原生碑柱 · 上2x细节 / 下实战尺度",Vector2(24,18))
	for index in 2:
		label(style,["切角碑石（下方只淡化上部）","悬钟柱（静态装饰，不是伤害源）"][index],Vector2(32+index*640,74))
		for row in 2:
			var prop := Prop.new(); prop.setup(Rect2(Vector2.ZERO,Vector2(96,80)),&"gravestone" if index==0 else &"bell_column")
			prop.position = Vector2(320+index*640,380 if row==0 else 792); prop.scale = Vector2.ONE*(2 if row==0 else 1); style.add_child(prop)
			check(Rect2(8,100 if row==0 else 620,1264,330 if row==0 else 210).encloses(prop.global_transform*prop.occlusion_rect.grow(3)),"sample cropped")
			if index==0 and row==1: prop.update_player_occlusion(prop.position-Vector2(0,80),true,1)
	label(style,"底座与真实碰撞一致；上部淡化不改变碰撞。地图钟座暂未启用回声拍。",Vector2(24,532))
	var pixels: Image = await capture(style,"props.png")
	check(pixels.get_pixel(320,376).a>0.99 and pixels.get_pixel(320,788).a>0.99 and pixels.get_pixel(960,788).a>0.99,"base is not opaque")
	var upper_alpha := pixels.get_pixel(320,668).a
	check(upper_alpha>0.25 and upper_alpha<0.8,"faded upper art is absent or opaque")
	check(pixels.get_pixel(320,132).a>0.99 and pixels.get_pixel(960,124).a>0.99,"normal upper art is translucent")
	style.free()
	for seed_value in [0,521,20261011]:
		var view := viewport(Vector2i(1280,720)); var map = Map.instantiate(); map.map_seed = seed_value; view.add_child(map)
		var camera := Camera2D.new(); camera.zoom = Vector2.ONE*0.24; view.add_child(camera)
		var ui := CanvasLayer.new(); view.add_child(ui)
		label(ui,"第5关地图资源 / 种子%s / 全图审查，不是实战视野或正式关卡"%seed_value,Vector2(24,16))
		await capture(view,"overview-%s.png"%seed_value); view.free()
	var live := viewport(Vector2i(1280,720)); var map = Map.instantiate(); map.map_seed = 521; live.add_child(map)
	var gate: Dictionary = map.layout.get_gateways()[0]
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; player.position = gate.inside; map.add_child(player)
	map.layout.occlusion_target = player
	var camera := Camera2D.new(); camera.position = player.position; live.add_child(camera)
	live.notify_mouse_entered(); var mouse := InputEventMouseMotion.new(); mouse.position = Vector2(900,360); live.push_input(mouse,true)
	check(live.get_mouse_position().distance_to(mouse.position)<0.001,"actual engine pointer differs")
	var ui := CanvasLayer.new(); live.add_child(ui)
	label(ui,"真实原生玩家 / 普通输入穿越内外圈 / 尚无第五关敌群或Boss",Vector2(24,16))
	await capture(live,"runtime-start.png")
	var moves := 0
	for _frame in 420:
		var direction: Vector2 = map.layout.get_navigation_direction(player.position,gate.outside,player.get_body_radius())
		release()
		for axis in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
			if axis[1]>0: Input.action_press(axis[0],axis[1])
		var before := player.position; await physics_frame
		camera.position = player.position; await process_frame
		if player.position.distance_to(before)>0.01: moves += 1
		check(Clearance.has_clearance(player.position,map.layout.world_bounds,map.layout.get_obstacle_descriptors(),player.get_body_radius()),"actual full Player overlaps terrain")
		if player.position.distance_to(gate.outside)<12: break
	release(); check(moves>100 and player.position.distance_to(gate.outside)<24,"real ring crossing not completed")
	await capture(live,"runtime-end.png")
	live.size = Vector2i(960,540); await capture(live,"runtime-960.png")
	live.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"actual_adjacent_moves":moves,"faded_upper_alpha":upper_alpha,"scope":"Original native stone/bell props, transparent GPU opaque base and separate upper fading; three seeded pillar-ring overviews; actual Player full-radius ordinary inputs through a gateway, current1280/960 viewport. No live echo hazard, enemy, Boss, readiness, save-unlock6, OS mouse, human playtest, dense performance or six-chapter completion."},"\t")); file.close()
	if not failures: print("TEST PASS: RenderEchoMapPreview %d; %d captures; %d adjacent moves"%[checks,captures.size(),moves])
	quit(1 if failures else 0)
