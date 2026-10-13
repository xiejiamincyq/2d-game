extends "RenderEchoMapPreview.gd"
## Reuse capture/input helpers only. Actual sixth map; no encounter/Boss claim.
const RiftMap = preload("res://scenes/world/rift_observatory.tscn")
const RiftProp = preload("res://scripts/world/RiftObstacle.gd")
func check(ok: bool,label_text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RenderRiftMapPreview "+label_text)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU and fresh evidence required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderRiftMapPreview.gd","scripts/art/RenderEchoMapPreview.gd","scripts/tests/RiftLayoutTest.gd","scripts/tests/RiftPropArtTest.gd","scripts/tests/RiftMapTest.gd","scripts/tests/RiftMovementTest.gd","scripts/tests/EchoMovementTest.gd","scenes/world/rift_observatory.tscn","scripts/world/RiftMap.gd","scripts/world/RiftArenaLayout.gd","scripts/world/RiftObstacle.gd","scripts/world/RiftPropArt.gd","scripts/world/RiftFloor.gd","scripts/world/ArenaLayout.gd","scripts/world/TerrainSweep.gd","scripts/actors/Player.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres","themes/MintFarmTheme.tres"]:
		check(FileAccess.file_exists("res://"+path),"missing source "+path); sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"invalid SHA "+path)
	RenderingServer.set_default_clear_color(Color("252b38")); release()
	var style := viewport(Vector2i(1280,860)); style.transparent_bg = true
	label(style,"裂隙观测站 / 原创原生设备 · 上2x细节 / 下实际尺度",Vector2(24,18))
	for index in 2:
		label(style,["手摇观测台（下图只淡化上部）","分节中继柱（静态设备，不是伤害源）"][index],Vector2(24+index*640,74))
		for row in 2:
			var prop := RiftProp.new(); prop.setup(Rect2(Vector2.ZERO,Vector2(160,112)),&"scope_bench" if index==0 else &"relay_plinth")
			prop.position = Vector2(320+index*640,460 if row==0 else 820); prop.scale = Vector2.ONE*(2 if row==0 else 1); style.add_child(prop)
			check(Rect2(8,96 if row==0 else 622,1264,380 if row==0 else 222).encloses(prop.global_transform*prop.occlusion_rect),"original sample cropped")
			if index==0 and row==1: prop.update_player_occlusion(prop.to_global(Vector2(0,-128)),true,1)
	label(style,"实色基座与真实碰撞同源；透明仅用于玩家被上部设备遮挡。",Vector2(24,552))
	var pixels: Image = await capture(style,"props.png")
	check(pixels.get_pixel(320,456).a>0.99 and pixels.get_pixel(320,816).a>0.99 and pixels.get_pixel(960,816).a>0.99,"physical bases translucent")
	check(pixels.get_pixel(320,216).a>0.99 and pixels.get_pixel(960,182).a>0.99,"normal original upper art translucent")
	var upper_alpha := pixels.get_pixel(320,698).a
	check(upper_alpha>0.25 and upper_alpha<0.5,"faded upper layer absent or opaque")
	style.free()
	for seed_value in [0,521,20261011]:
		var view := viewport(Vector2i(1280,720)); var map = RiftMap.instantiate(); map.map_seed = seed_value; view.add_child(map)
		var camera := Camera2D.new(); camera.zoom = Vector2.ONE*0.25; view.add_child(camera)
		var ui := CanvasLayer.new(); view.add_child(ui)
		label(ui,"第6关随机设备岛 / 种子%s / 全图审查，不是正式游玩视野"%seed_value,Vector2(24,16))
		await capture(view,"overview-%s.png"%seed_value); view.free()
	var live := viewport(Vector2i(1280,720)); var map = RiftMap.instantiate(); map.map_seed = 521; live.add_child(map)
	var island: Dictionary = map.layout.get_islands()[0]
	var upper: Rect2 = map.layout.get_bypass_routes()[0].rect
	var lower: Rect2 = map.layout.get_bypass_routes()[1].rect
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; player.position = island.left; map.add_child(player)
	map.layout.occlusion_target = player
	var camera := Camera2D.new(); camera.position = player.position; live.add_child(camera)
	live.notify_mouse_entered(); var mouse := InputEventMouseMotion.new(); mouse.position = Vector2(900,360); live.push_input(mouse,true)
	check(live.get_mouse_position().distance_to(mouse.position)<0.001,"actual pointer differs")
	var ui := CanvasLayer.new(); live.add_child(ui)
	label(ui,"实际原生玩家 / 普通输入绕设备上侧与下侧 / 尚无第六敌群或Boss",Vector2(24,16))
	check(is_equal_approx(player.get_body_radius(),16.9) and is_equal_approx(player.move_speed,235),"fixture modifies Player")
	await capture(live,"runtime-start.png")
	var moves := 0
	var targets: Array[Vector2] = [Vector2(island.left.x,upper.get_center().y),Vector2(island.right.x,upper.get_center().y),island.right,Vector2(island.right.x,lower.get_center().y),Vector2(island.left.x,lower.get_center().y),island.left]
	for index in targets.size():
		var target := targets[index]; var reached := false
		for _frame in 900:
			if player.position.distance_to(target)<12: reached = true; break
			var direction: Vector2 = map.layout.get_navigation_direction(player.position,target,player.get_body_radius())
			release()
			for axis in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
				if axis[1]>0: Input.action_press(axis[0],axis[1])
			var before := player.position; await physics_frame
			camera.position = player.position; await process_frame
			if player.position.distance_to(before)>0.01: moves += 1
			check(Clearance.has_clearance(player.position,map.layout.world_bounds,map.layout.get_obstacle_descriptors(),player.get_body_radius()),"actual full Player enters terrain")
		check(reached,"ordinary bypass input fails target %s"%target)
		if index in [0,1,3,4]: await capture(live,"runtime-path-%s.png"%index)
	release(); check(moves>200,"decisions replace actual movement")
	# Review the real equipment beside the finished ordinary route at three sizes.
	camera.position = island.center
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		live.size = size; await capture(live,"runtime-%s.png"%size.x)
	live.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"actual_adjacent_moves":moves,"faded_upper_alpha":upper_alpha,"scope":"Original native crank benches/split-ring relays, transparent GPU opaque bases and separate upper fading, three actual seeded maps, ordinary full-radius Player inputs via upper/lower bypass, real 960/1280/1920 viewports. No in-run transform/stat injection, live faults, enemies, Boss, sixth readiness/unlock/save, OS input, human playtest, dense performance or whole-goal completion."},"\t")); file.close()
	if not failures: print("TEST PASS: RenderRiftMapPreview %d; %d captures; %d adjacent moves"%[checks,captures.size(),moves])
	quit(1 if failures else 0)
