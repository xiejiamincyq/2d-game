extends SceneTree
## Actual Floor/Obstacle/Player and compatibility Main; controlled GPU fixture.
const Floor = preload("res://scripts/world/FloorGrid.gd")
const Obstacle = preload("res://scripts/world/ArenaObstacle.gd")
const Layout = preload("res://scripts/world/ArenaLayout.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Main = preload("res://scripts/Main.gd")
const Support = preload("res://scripts/tests/TestSupport.gd")
const Evidence = preload("res://scripts/art/CampaignChainEvidence.gd")
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("NATIVE ARENA GPU FAIL: " + message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not Evidence.safe_id(args[0]): quit(1); return
	var output := "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name() != "headless" and not DirAccess.dir_exists_absolute(output), "fresh GPU output required")
	if failed: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := Evidence.build_source_bank()
	check(not sources.is_empty(), "canonical fixed-root source bank absent")
	var view := SubViewport.new()
	view.size = Vector2i(640,420)
	view.world_2d = World2D.new()
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var rows: Array[Dictionary] = []
	var sheet := Image.create(2560,1260,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("343d40"))
	for column in Layout.OBSTACLE_TYPES.size():
		var role: Dictionary = Layout.OBSTACLE_TYPES[column]
		for size_scale in [0.5,1.0,2.0]:
			var size: Vector2 = role.size*size_scale
			var obstacle := Obstacle.new()
			obstacle.setup(Rect2(Vector2(320-size.x*.5,350-size.y),size),role.kind)
			view.add_child(obstacle)
			for state in 3:
				obstacle.update_player_occlusion(obstacle.to_global(Vector2(0,-size.y*.6)),state == 1,1)
				await process_frame; await RenderingServer.frame_post_draw
				var pixels := view.get_texture().get_image()
				var outside := 0; var edge := 0; var opaque := 0
				for y in 420:
					for x in 640:
						var alpha := pixels.get_pixel(x,y).a
						if alpha >= 0.99:
							opaque += 1
							outside += 1 if not obstacle.occlusion_rect.has_point(Vector2(x+.5-320,y+.5-350)) else 0
						edge += 1 if alpha > .01 and (x == 0 or y == 0 or x == 639 or y == 419) else 0
				var footprint_nonopaque := 0
				for y in range(int(350-size.y)+8,342):
					for x in range(int(320-size.x*.5)+8,int(320+size.x*.5)-8):
						footprint_nonopaque += 1 if pixels.get_pixel(x,y).a < .99 else 0
				check(opaque > 1000 and outside == 0 and edge == 0, "prop clipped/visual bounds wrong " + String(role.kind))
				check(footprint_nonopaque == 0 and obstacle.modulate.a == 1, "solid collision footprint becomes translucent")
				check(is_equal_approx(obstacle.art.modulate.a,.32 if state == 1 else 1), "upper decoration occlusion does not restore")
				rows.append({"role":String(role.kind),"scale_fixture":size_scale,"state":["opaque","occluded","restored"][state],"opaque_pixels":opaque,"outside_visual_bounds":outside,"edge":edge,"footprint_nonopaque":footprint_nonopaque})
				if size_scale == 1:
					sheet.blend_rect(pixels,Rect2i(0,0,640,420),Vector2i(column*640,state*420))
			obstacle.free()
	check(sheet.save_png(output+"props.png") == OK, "props sheet write")
	# Real player behind one tall greenhouse, physically outside its collider.
	# Before/after decoration yield is visual evidence, not movement input proof.
	var behind_world := Node2D.new()
	behind_world.y_sort_enabled = true
	view.add_child(behind_world)
	var behind_player := Player.new()
	behind_player.position = Vector2(320,212)
	behind_world.add_child(behind_player)
	behind_player.set_physics_process(false)
	behind_player.advance_entrance(behind_player.get_entrance_duration()+.01)
	behind_player.get_visual_node().sample_clip("idle",0)
	var behind_prop := Obstacle.new()
	var behind_collision := Rect2(215,230,210,120)
	behind_prop.setup(behind_collision,&"greenhouse")
	behind_world.add_child(behind_prop)
	check(not behind_collision.grow(behind_player.get_body_radius()).has_point(behind_player.position), "behind player is embedded in collision")
	var behind_samples: Array[Dictionary] = []
	for covered in [false,true]:
		behind_prop.update_player_occlusion(behind_player.global_position,covered,1)
		await process_frame; await RenderingServer.frame_post_draw
		var name := "behind_yield.png" if covered else "behind_opaque.png"
		check(view.get_texture().get_image().save_png(output+name) == OK, "behind-player capture")
		check(behind_player.modulate.a == 1 and behind_prop.modulate.a == 1, "behind-player yield fades physical roots")
		behind_samples.append({"covered":covered,"player_root_alpha":behind_player.modulate.a,"obstacle_root_alpha":behind_prop.modulate.a,"decor_alpha":behind_prop.art.modulate.a,"physically_outside_collision":true})
	behind_world.free()
	var floor := Floor.new()
	view.add_child(floor)
	var floor_samples: Array[Dictionary] = []
	view.transparent_bg = false
	var camera := Camera2D.new()
	view.add_child(camera)
	for camera_at in [Vector2.ZERO,Vector2(-2200,-1600),Vector2(2200,1600)]:
		camera.position = camera_at
		camera.force_update_scroll()
		await process_frame; await RenderingServer.frame_post_draw
		var pixels := view.get_texture().get_image()
		var black := 0; var alpha_bad := 0; var minimum := 1.0; var maximum := 0.0
		for y in range(0,420,7):
			for x in range(0,640,7):
				var color := pixels.get_pixel(x,y)
				var luminance := color.get_luminance()
				black += 1 if luminance < .10 else 0
				alpha_bad += 1 if color.a < .99 else 0
				minimum = minf(minimum,luminance); maximum = maxf(maximum,luminance)
		check(black == 0 and alpha_bad == 0 and maximum-minimum < .08 and floor.last_draw_command_count == 1, "native floor black/transparent/high contrast/budget")
		floor_samples.append({"camera":[camera_at.x,camera_at.y],"black_samples":black,"alpha_bad":alpha_bad,"luminance_min":minimum,"luminance_max":maximum,"draw_commands":floor.last_draw_command_count})
		if camera_at == Vector2.ZERO: check(pixels.save_png(output+"floor.png") == OK, "floor capture")
	view.free()
	# Actual Main compatibility entry; starts normally, only views controlled.
	# Every write is scoped to this fresh evidence folder, never user saves.
	var mains: Array[Dictionary] = []
	for size in [Vector2i(960,540),Vector2i(1280,720)]:
		var viewport := SubViewport.new()
		viewport.size = size
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var main := Main.new()
		main.audio_enabled = false
		main.campaign_store_path = output+"campaign_%d.json" % size.x
		viewport.add_child(main)
		main.snapshot_store.save_path = output+"snapshot_%d.json" % size.x
		main._start_run()
		for frame in 180:
			await physics_frame
			if not main.player.is_entrance_active() and main.run_state == main.RunState.PLAYING: break
		check(main.run_started and not main.player.is_entrance_active(), "actual Main/player entrance not completed")
		check(main.world.get_node("CyberWastelandFloor").material.shader.resource_path == "res://assets/art/shaders/paper_arena_floor_v1.gdshader", "Main still uses raster floor")
		for obstacle in main.arena_layout.get_children():
			check(obstacle.get_node("Art").get_script().resource_path == "res://scripts/world/ArenaPaperPropArt.gd", "actual generated Main prop is legacy raster")
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(output+"main_%d.png" % size.x) == OK, "Main capture")
		mains.append({"viewport":[size.x,size.y],"actual_map_seed":main.map_seed,"obstacles":main.arena_layout.get_child_count(),"state":main.RunState.keys()[main.run_state],"snapshot":main.snapshot_store.save_path,"campaign":main.campaign_store_path})
		Support.stop_audio(main.audio)
		paused = false
		viewport.free()
		await process_frame
	check(Evidence.source_bank_matches(sources), "source drift during GPU capture")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"checks":checks,"props":rows,"behind_player":behind_samples,"floor":floor_samples,"main":mains,"source_bank":sources,"scope":"Actual native compatibility Floor/Obstacle, four roles at three size fixtures and opaque/faded/restored states; opaque bounds/edge and footprint interior inset8px GPU checks (not rounded antialias edges). One real player physically behind greenhouse with before/after decor yield images. Three sampled world camera centers for floor opacity/contrast/single draw. Actual compatibility Main starts and initial Player entrance at two viewports with fresh owned output saves and normal random seeds; no injected combat stats. Not ordinary-input victory, all-floor pixels, six regional map redesign, complete performance, external PCK or human acceptance."},"\t")); file.close()
	print("NATIVE ARENA GPU %s: %d checks, 36 prop samples, 3 floor positions, 2 Main viewports" % ["FAIL" if failed else "PASS",checks])
	quit(1 if failed else 0)
