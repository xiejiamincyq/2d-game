extends SceneTree
## Author GPU sheet + real Player primary shots against map-owned nests.
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Nest = preload("res://scripts/world/ArchiveSporeNest.gd")
const Player = preload("res://scripts/actors/Player.gd")
const UI_THEME = preload("res://themes/MintFarmTheme.tres")
var failures := 0
var checks := 0
var shots := 0
var pointers := 0
var adjacent_moves := 0
var output: String
var captures: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("ARCHIVE SPORE GPU FAIL: "+label)
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
func tick() -> void: await physics_frame; await process_frame
func wait_for(predicate: Callable,seconds: float = 5.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline: await tick()
	return predicate.call()
func danger_pixels(image: Image,baseline: Image) -> int:
	var count := 0
	for x in range(602,679):
		for y in range(323,398):
			var offset := Vector2(x-640,y-360); var radius := offset.length()
			if radius<31 or radius>37 or absf(offset.x)<25: continue
			if image.get_pixel(x,y)!=baseline.get_pixel(x,y): count += 1
	return count
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU/fresh directory required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderArchiveSporePreview.gd","scripts/world/ArchiveSporeNest.gd","scripts/world/ArchiveSporeField.gd","scripts/world/ArchiveMap.gd","scenes/world/luminous_archive.tscn","scripts/world/ArchiveArenaLayout.gd","scripts/world/ArchiveObstacle.gd","scripts/world/ArchiveFloor.gd","scripts/world/ArchivePropArt.gd","scripts/world/ArenaLayout.gd","scripts/world/TerrainSweep.gd","scripts/actors/Player.gd","scripts/components/Projectile.gd","scripts/components/HealthComponent.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres","themes/MintFarmTheme.tres"]:
		check(FileAccess.file_exists("res://"+path),"missing source "+path); sources[path] = FileAccess.get_sha256("res://"+path)
	RenderingServer.set_default_clear_color(Color("303d3b"))
	var sheet := viewport(Vector2i(1280,720)); sheet.transparent_bg = true
	label(sheet,"菌光档案 / 原创可破坏孢巢 · 上2x样板 / 下真实尺度",Vector2(24,16))
	var opaque := 0
	for row in 2:
		for index in 4:
			var nest := Nest.new(); sheet.add_child(nest); nest.set_physics_process(false)
			nest.position = Vector2(160+index*320,240 if row==0 else 550); nest.scale = Vector2.ONE*(2 if row==0 else 1)
			# Sheet-only poses, never evidence of gameplay damage or state timing.
			nest.state = [Nest.State.COOLDOWN,Nest.State.WARNING,Nest.State.ACTIVE,Nest.State.BROKEN][index]
			nest.enabled = true; nest.destroyed = index==3; nest.remaining = 0.3; nest.queue_redraw()
			label(sheet,["冷却 / 可射击","短预警 / 0.45秒","菌息 / 34px","破坏 / 本战不再生"][index],Vector2(32+index*320,120 if row==0 else 445))
	label(sheet,"仅样板姿态；下列实战图才使用自然时钟与真实玩家射击。底座不透明、不阻挡移动。",Vector2(24,650))
	var art: Image = await capture(sheet,"native-sheet.png")
	for row in 2:
		for index in 4:
			var alpha := art.get_pixel(160+index*320,(240 if row==0 else 550)+5).a
			check(alpha>0.99,"opaque nest base"); opaque += 1 if alpha>0.99 else 0
	sheet.free(); await process_frame
	var live := viewport(Vector2i(1280,720)); var map = Map.instantiate(); map.map_seed = 521; live.add_child(map)
	var field = map.spore_field; var nest = field.get_child(0)
	var camera := Camera2D.new(); camera.position = nest.global_position; live.add_child(camera)
	var player := Player.new(); player.position = nest.position; player.world_bounds = map.layout.world_bounds; map.add_child(player)
	map.layout.occlusion_target = player
	var bullets := Node2D.new(); map.add_child(bullets)
	player.fired.connect(func(shot: Node) -> void: bullets.add_child(shot); shots += 1)
	var ui := CanvasLayer.new(); live.add_child(ui)
	label(ui,"真实地图孢巢 / 自然时钟 + 普通玩家射击 / 非第四关通关",Vector2(24,16))
	await tick(); await tick(); field.bind_player(player); field.set_active(true,1)
	var baseline: Image = await capture(live,"runtime-cooldown.png")
	check(await wait_for(func(): return nest.state==Nest.State.WARNING),"natural warning absent")
	var warning: Image = await capture(live,"runtime-warning.png")
	var warning_count := danger_pixels(warning,baseline); check(warning_count>30,"warning has no positive pixels outside body")
	check(await wait_for(func(): return nest.state==Nest.State.ACTIVE),"natural emission absent")
	var active: Image = await capture(live,"runtime-active.png")
	var active_count := danger_pixels(active,baseline); check(active_count>30,"active has no positive pixels outside body")
	check(player.health.current_health==82 and player.shield==0,"actual centered danger does not damage once")
	paused = true; await tick(); await tick()
	check(nest.state==Nest.State.INACTIVE and not nest.is_in_group(&"enemies"),"GPU pause leaves danger")
	await capture(live,"runtime-paused.png")
	paused = false; await tick(); await tick()
	check(nest.state==Nest.State.COOLDOWN and nest.remaining>3.1,"GPU resume lacks full safe interval")
	# Move out of the nest with ordinary input, without rewriting Player position.
	Input.action_press("move_down")
	for _frame in 25:
		var at := player.position; await tick()
		adjacent_moves += 1 if player.position.distance_to(at)>0.01 else 0
	Input.action_release("move_down")
	check(adjacent_moves>20 and player.position.distance_to(nest.position)>80,"normal GPU motion cannot cross live nonblocking nest")
	live.notify_mouse_entered()
	var deadline := Time.get_ticks_msec()+2500
	Input.action_press("fire")
	while not nest.destroyed and Time.get_ticks_msec()<deadline:
		var mouse := InputEventMouseMotion.new(); mouse.position = live.get_canvas_transform()*nest.global_position; live.push_input(mouse)
		await tick()
		pointers += 1; check(player.get_global_mouse_position().distance_to(nest.global_position)<1,"engine pointer does not aim at nest")
	Input.action_release("fire")
	check(nest.destroyed and nest.health.current_health==0 and shots>=4,"actual primary shots did not suppress nest")
	check(player.health.current_health==82 and player.shield==0 and player.weapon_damage==10 and player.fire_rate==13,"primary input bypasses default stats")
	await tick(); await capture(live,"runtime-broken.png")
	field.set_active(true,1); await tick(); check(nest.destroyed,"repeat encounter refresh regrows nest")
	field.set_active(false); live.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed "+path)
	var report := {"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"opaque_base_samples":opaque,"positive_warning_pixels":warning_count,"positive_active_pixels":active_count,"actual_player_primary_shots":shots,"engine_pointer_checks":pointers,"actual_adjacent_moves":adjacent_moves,"scope":"Transparent GPU original native environmental art; sheet poses only. Real map natural danger with Player standing inside/actual damage18/pause/ruins; normal Player moves across nest, engine pointer/primary fire and default stats break nest. No actor position writes after spawn, direct damage, enemy rewards, chapter victory, OS input, human playtest, dense performance or six-chapter completion."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	if not failures: print("ARCHIVE SPORE GPU PASS: %d checks/6 captures/%d primary shots/%d pointer checks/%d adjacent moves"%[checks,shots,pointers,adjacent_moves])
	quit(1 if failures else 0)
