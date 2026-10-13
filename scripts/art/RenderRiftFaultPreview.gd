extends "RenderEchoBeatPreview.gd"
## Actual native fault pixels, then an independent natural-clock ordinary-input dodge.
const RiftMap = preload("res://scenes/world/rift_observatory.tscn")
const Fault = preload("res://scripts/world/RiftFault.gd")
func check(ok: bool,label_text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RenderRiftFaultPreview "+label_text)
func point(view: SubViewport,camera: Camera2D,at: Vector2) -> Vector2i:
	return Vector2i(Vector2(view.size)/2+at-camera.position)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"real GPU/fresh output required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderRiftFaultPreview.gd","scripts/art/RenderEchoBeatPreview.gd","scripts/tests/RiftFaultTest.gd","scripts/tests/RiftFaultPhysicsTest.gd","scripts/tests/RiftFieldTest.gd","scripts/tests/RiftFieldPhysicsTest.gd","scripts/tests/EchoBeatTest.gd","scripts/tests/EchoBeatPhysicsTest.gd","scripts/tests/EchoFieldTest.gd","scripts/tests/EchoMovementTest.gd","scripts/world/RiftFault.gd","scripts/world/RiftField.gd","scripts/world/RiftMap.gd","scripts/world/RiftArenaLayout.gd","scripts/world/RiftObstacle.gd","scripts/world/RiftPropArt.gd","scripts/world/RiftFloor.gd","scripts/world/ArenaLayout.gd","scripts/world/TerrainSweep.gd","scenes/world/rift_observatory.tscn","scripts/actors/Player.gd","scripts/components/HealthComponent.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres","themes/MintFarmTheme.tres"]:
		check(FileAccess.file_exists("res://"+path),"source missing "+path); sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"invalid SHA "+path)
	RenderingServer.set_default_clear_color(Color("252b38")); release()
	var view := viewport(); var map = RiftMap.instantiate(); map.map_seed = 521; view.add_child(map)
	var fault = map.rift_field.get_child(0)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds
	player.position = fault.position-fault.direction*150; map.add_child(player); map.layout.occlusion_target = player
	var camera := Camera2D.new(); camera.position = fault.position; view.add_child(camera)
	var caption := label(view,"裂隙机关 / 受控真实状态像素（不是完整关卡试玩）")
	await tick(); await tick(); map.rift_field.bind_player(player); map.rift_field.set_active(true,1); fault.set_physics_process(false)
	var baseline: Image = await capture(view,"cooldown.png")
	fault.advance(fault.initial_delay); caption.text = "短提示 / 固定160px轨迹 / 不追踪玩家"
	var warning: Image = await capture(view,"warning.png")
	var warning_at := point(view,camera,fault.get_fault_path()[0]+fault.direction*4)
	check(differs(warning.get_pixelv(warning_at),baseline.get_pixelv(warning_at)),"short dashed path absent")
	fault.advance(0.4)
	var start_center: Vector2 = fault.get_current_center(); var samples: Array[Vector2] = []
	for sample in ["start","middle","end"]:
		if sample=="middle":
			for _index in 3: fault.advance(0.05)
			fault.advance(0.025)
		if sample=="end":
			for _index in 3: fault.advance(0.05)
			fault.advance(0.025)
		var center: Vector2 = fault.get_current_center(); samples.append(center)
		caption.text = "活动裂痕 / %s / 半径20 · 时钟与判定同源"%sample
		var pixels: Image = await capture(view,"active-"+sample+".png")
		var at := point(view,camera,center+fault.direction.orthogonal()*8+fault.direction*7)
		check(fault.state==Fault.State.ACTIVE and differs(pixels.get_pixelv(at),baseline.get_pixelv(at)),"actual finite disk invisible "+sample)
		check(pixels.get_pixelv(at).r>pixels.get_pixelv(at).b,"danger lacks hostile coral semantics")
		if sample=="end": check(center.distance_to(start_center)>159,"endpoint not actually rendered")
	map.rift_field.set_active(false); caption.text = "所有者取消 / 同时清除危险与可见裂痕"
	var cancelled: Image = await capture(view,"cancelled.png")
	for center in samples:
		var at := point(view,camera,center+fault.direction.orthogonal()*8+fault.direction*7)
		check(not differs(cancelled.get_pixelv(at),baseline.get_pixelv(at)),"cancelled danger remains on ground")
	view.free(); await process_frame
	# New real world: natural clock only, actual input after a 0.15s reaction.
	var live := viewport(); var actual_map = RiftMap.instantiate(); actual_map.map_seed = 521; live.add_child(actual_map)
	var actual_fault = actual_map.rift_field.get_child(0)
	var actual_player := Player.new(); actual_player.world_bounds = actual_map.layout.world_bounds; actual_player.position = actual_fault.position-actual_fault.direction*80; actual_map.add_child(actual_player)
	actual_map.layout.occlusion_target = actual_player
	var follower := Camera2D.new(); follower.position = actual_player.position; live.add_child(follower)
	var heading := label(live,"自然时钟 / 普通玩家 / 0.15秒反应后离开短轨迹")
	live.notify_mouse_entered(); var mouse := InputEventMouseMotion.new(); mouse.position = Vector2(900,360); live.push_input(mouse,true)
	check(live.get_mouse_position().distance_to(mouse.position)<0.001,"pointer mismatch")
	await tick(); await tick(); actual_map.rift_field.bind_player(actual_player); actual_map.rift_field.set_active(true,1)
	var before: float = actual_player.health.current_health+actual_player.shield
	var deadline := Time.get_ticks_msec()+6000
	while actual_fault.state!=Fault.State.WARNING and Time.get_ticks_msec()<deadline: await tick()
	check(actual_fault.state==Fault.State.WARNING,"natural GPU clock has no warning")
	await capture(live,"natural-warning.png")
	for _index in ceili(Engine.physics_ticks_per_second*0.15): await tick()
	Input.action_press("move_left" if actual_fault.direction.x>0 else "move_right")
	var moves := 0; var active_frames := 0; var natural_captures := 0
	var sample_fractions := [0.0,0.3,0.65]
	for _frame in ceili(Engine.physics_ticks_per_second*0.7):
		var at := actual_player.position; await physics_frame; follower.position = actual_player.position; await process_frame
		if actual_player.position.distance_to(at)>0.01: moves += 1
		if actual_fault.state==Fault.State.ACTIVE:
			active_frames += 1
			if natural_captures<3 and (Fault.ACTIVE_TIME-actual_fault.remaining)/Fault.ACTIVE_TIME>=sample_fractions[natural_captures]:
				await capture(live,"natural-active-%s.png"%natural_captures); natural_captures += 1
		check(Clearance.has_clearance(actual_player.position,actual_map.layout.world_bounds,actual_map.layout.get_obstacle_descriptors(),actual_player.get_body_radius()),"normal input embeds actual body")
		check(actual_player.health.current_health+actual_player.shield==before,"natural GPU dodge relies on invincibility")
	release(); check(moves>20 and active_frames>10 and natural_captures==3,"natural moving pixels not sampled")
	heading.text = "普通输入完成躲避 / 玩家235px/s · 半径16.9 / 未改血量、无传送"
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		live.size = size; await capture(live,"natural-%s.png"%size.x)
	actual_map.rift_field.set_active(false); live.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"actual_adjacent_moves":moves,"natural_active_frames":active_frames,"scope":"Six controlled true native fault clock-state samples then a separate natural-clock normal-Player dodge, three active GPU samples and three final resolutions. No encounters/Boss/sixth readiness, human/OS playtest, dense combat or whole goal completion."},"\t")); file.close()
	if not failures: print("TEST PASS: RenderRiftFaultPreview %d; %d captures; %d actual adjacent moves"%[checks,captures.size(),moves])
	quit(1 if failures else 0)
