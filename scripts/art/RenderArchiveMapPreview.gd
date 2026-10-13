extends SceneTree
## Author-only GPU map proof; no hazards, enemies or chapter victory fabricated.
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Prop = preload("res://scripts/world/ArchiveObstacle.gd")
const Player = preload("res://scripts/actors/Player.gd")
const UI_THEME = preload("res://themes/MintFarmTheme.tres")
var failures := 0
var checks := 0
var output: String
var captures: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("ARCHIVE MAP GPU FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func viewport(size: Vector2i) -> SubViewport:
	var view := SubViewport.new(); view.size = size; view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view); return view
func label(parent: Node,value: String,at: Vector2) -> void:
	var text := Label.new(); text.text = value; text.position = at
	text.add_theme_font_override("font",UI_THEME.default_font); text.add_theme_font_size_override("font_size",22)
	text.add_theme_color_override("font_color",Color("ddd2b1")); parent.add_child(text)
func capture(view: SubViewport,name: String) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	check(pixels!=null and not pixels.is_empty() and pixels.save_png(output+name)==OK,"capture "+name)
	captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name)}); return pixels
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU/new output folder required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderArchiveMapPreview.gd","scenes/world/luminous_archive.tscn","scripts/world/ArchiveMap.gd","scripts/world/ArchiveArenaLayout.gd","scripts/world/ArchiveObstacle.gd","scripts/world/ArchivePropArt.gd","scripts/world/ArchiveFloor.gd","scripts/world/ArenaLayout.gd","scripts/world/TerrainSweep.gd","scripts/actors/Player.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres","themes/MintFarmTheme.tres"]:
		check(FileAccess.file_exists("res://"+path),"missing source "+path); sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"invalid source SHA "+path)
	if failures: quit(1); return
	RenderingServer.set_default_clear_color(Color("303d3b"))
	var style := viewport(Vector2i(1280,900)); style.transparent_bg = true
	label(style,"菌光档案 / 原创原生书架 · 上2x细节 / 下实战尺度",Vector2(24,18))
	for index in 2:
		label(style,["横向书架（下图演示上部淡化）","竖向书架（实色底座始终保留）"][index],Vector2(32+index*640,74))
		for row in 2:
			var prop := Prop.new(); prop.setup(Rect2(Vector2.ZERO,Vector2(280,52) if index==0 else Vector2(52,180)),&"bookcase")
			prop.position = Vector2(320+index*640,540 if row==0 else 850); prop.scale = Vector2.ONE*(2 if row==0 else 1)
			style.add_child(prop)
			check(Rect2(8,100 if row==0 else 615,1264,465 if row==0 else 270).encloses(prop.global_transform*prop.occlusion_rect.grow(3)),"sample clipped")
			if index==0 and row==1: prop.update_player_occlusion(prop.position-Vector2(0,52),true,1)
	label(style,"书架底座与完整碰撞一致；门洞和外圈可绕行。静态菌斑不是危险提示。",Vector2(24,578))
	var pixels: Image = await capture(style,"props.png")
	check(pixels.get_pixel(320,536).a>0.99 and pixels.get_pixel(320,848).a>0.99,"normal/faded shelf plinth is translucent")
	# Crown and cap overlap here; two 0.32-alpha primitives composite to
	# 1-(1-0.32)^2, not a single primitive's alpha. No plinth under this pixel.
	var upper_alpha := pixels.get_pixel(320,778).a
	check(absf(upper_alpha-(1-pow(1-0.32,2)))<0.02,"upper crown/cap alpha composition differs")
	style.free()
	for seed_value in [0,521,20261011]:
		var overview := viewport(Vector2i(1280,720)); var map = Map.instantiate(); map.map_seed = seed_value; overview.add_child(map)
		var camera := Camera2D.new(); camera.zoom = Vector2.ONE*0.30; overview.add_child(camera)
		var ui := CanvasLayer.new(); overview.add_child(ui)
		label(ui,"第4关地图资源 / 种子%s / 全图审查，非玩家实战视野或关卡通关"%seed_value,Vector2(24,16))
		await capture(overview,"overview-%s.png"%seed_value); overview.free()
	var live := viewport(Vector2i(1280,720)); var map = Map.instantiate(); map.map_seed = 521; live.add_child(map)
	var room: Rect2 = map.layout.get_chambers()[0]; var door: Rect2 = map.layout.get_doorways()[0]
	var camera := Camera2D.new(); camera.position = room.get_center(); live.add_child(camera)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; player.position = room.get_center(); map.add_child(player)
	map.layout.occlusion_target = player
	live.notify_mouse_entered(); var mouse := InputEventMouseMotion.new(); mouse.position = Vector2(900,360); live.push_input(mouse)
	var ui := CanvasLayer.new(); live.add_child(ui)
	label(ui,"原生玩家 + 真实双出口房室 / 普通输入，不是第四关战斗或真人试玩",Vector2(24,16))
	await capture(live,"runtime-start.png")
	var moves := 0
	var outward := Vector2(signf(door.get_center().x-room.get_center().x),0) if door.size.x<door.size.y else Vector2(0,signf(door.get_center().y-room.get_center().y))
	var target := door.get_center()+outward*100
	for _frame in 150:
		var direction: Vector2 = map.layout.get_navigation_direction(player.position,target,player.get_body_radius())
		for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
		for axis in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
			if axis[1]>0: Input.action_press(axis[0],axis[1])
		var before := player.position; await physics_frame
		camera.position = player.position # Real play follows the moving player, not a fixed room crop.
		await process_frame
		if player.position.distance_to(before)>0.01: moves += 1
		check(map.layout.is_position_walkable(player.position,12.5),"real input embeds player in shelf")
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	check(moves>20 and player.position.distance_to(target)<24,"real door was not traversed")
	await capture(live,"runtime-end.png"); live.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed "+path)
	var report := {"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"actual_adjacent_moves":moves,"upper_crown_cap_composite_alpha":upper_alpha,"scope":"Original native shelf art/transparent GPU opaque plinth and separate upper fading; three seeded map overviews; actual Player normal physics input through room door. No hazards, enemies, Boss, readiness, chapter win, OS mouse, human playtest, dense performance or six-chapter completion."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	if not failures: print("ARCHIVE MAP GPU PASS: %d checks/6 captures/%d adjacent moves"%[checks,moves])
	quit(1 if failures else 0)
