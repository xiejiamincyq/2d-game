extends SceneTree
## GPU native companion poses plus real Player/laser ownership fixture.
const Drone = preload("res://scripts/actors/DroneVisual.gd")
const PlayerSource = preload("res://scripts/actors/Player.gd")
const EnemySource = preload("res://scripts/actors/Enemy.gd")
const CLIPS := ["idle","walk","shoot","entrance","death"]
var failed := false
func check(ok: bool,message: String) -> void:
	if not ok:
		failed = true
		push_error("DRONE GPU FAIL: "+message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier():
		push_error("DRONE GPU FAIL: expected one unused identifier output name")
		quit(1)
		return
	var output := "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU and unused output required")
	if failed:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderNativeDronePreview.gd","scripts/actors/DroneVisual.gd","scripts/actors/Player.gd","scenes/actors/native/ranger_drone_paper_v1.tscn","assets/art/actors/native/ranger_drone_motion_v1.tres","scenes/art/technical/RangerDroneDraft.gd","scenes/art/technical/RangerDroneShapes.gd","scripts/components/NativeActorView.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96,96)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := Image.create(960,576,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("304138"))
	var samples: Array[Dictionary] = []
	for angle in [0.0,PI/4]:
		for column in CLIPS.size():
			for row in 3:
				var actor := Drone.new()
				actor.position = Vector2(48,48)
				actor.rotation = angle
				viewport.add_child(actor)
				var body = actor.get_visual_node()
				var clip: String = CLIPS[column]
				var phase: float = [0,0.45,0.85][row]
				body.sample_clip(clip,body.player.get_animation(clip).length*phase)
				await process_frame
				await RenderingServer.frame_post_draw
				var pixels := viewport.get_texture().get_image()
				var counts := measure(pixels)
				check(counts.opaque>150 and counts.partial==0 and counts.edge==0,"invisible/translucent/cropped "+clip)
				counts.merge({"clip":clip,"phase":phase,"angle":angle})
				samples.append(counts)
				if angle==0:
					pixels.resize(192,192,Image.INTERPOLATE_NEAREST)
					sheet.blend_rect(pixels,Rect2i(0,0,192,192),Vector2i(column*192,row*192))
				actor.free()
	check(sheet.save_png(output+"poses.png")==OK,"pose save")
	var flier := Drone.new()
	flier.position = Vector2(48,48)
	viewport.add_child(flier)
	flier.advance_visual(0.4,false)
	var previous := PackedByteArray()
	var changes := 0
	for frame in 60:
		flier.advance_visual(1/60.0,false)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image().get_data()
		changes += 1 if frame>0 and previous!=pixels else 0
		previous = pixels
	check(changes>=30,"tiny production flight frozen")
	flier.free()
	viewport.free()
	var arena := SubViewport.new()
	arena.size = Vector2i(640,360)
	arena.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(arena)
	var background := ColorRect.new()
	background.size = arena.size
	background.color = Color("304138")
	background.z_index = -10 # Real beams deliberately draw at absolute -1.
	arena.add_child(background)
	var fixture := Node2D.new()
	arena.add_child(fixture)
	var player = PlayerSource.new()
	player.projectile_parent = fixture
	player.position = Vector2(240,180)
	player.drone_count = 3
	fixture.add_child(player)
	player.set_physics_process(false)
	var target = EnemySource.new()
	target.setup(EnemySource.EnemyKind.SCRAPPER,0,fixture,player)
	target.position = Vector2(460,180)
	fixture.add_child(target)
	target.set_physics_process(false)
	player.set_enemy_provider(func() -> Array[Node]: return [target])
	for step in 30:
		player._update_passives(1/60.0)
		player._update_visual_animation(1/60.0)
	check(player.drone_visuals.size()==3 and player.drone_lasers[0].visible and target.health.current_health<target.health.max_health,"actual companion laser fixture not engaged")
	await process_frame
	await RenderingServer.frame_post_draw
	var production := arena.get_texture().get_image()
	var beam_pixels := 0
	var beam_tint: Color = player.drone_lasers[0].tint
	for y in production.get_height():
		for x in production.get_width():
			var color := production.get_pixel(x,y)
			if absf(color.r-beam_tint.r)<0.01 and absf(color.g-beam_tint.g)<0.01 and absf(color.b-beam_tint.b)<0.01: beam_pixels += 1
	check(beam_pixels>500,"actual friendly laser pixels absent/hidden")
	check(production.save_png(output+"production.png")==OK,"production fixture save")
	fixture.free()
	arena.free()
	await process_frame
	var report := {"passed":not failed,"samples":samples,"flight_frames":60,"flight_changes":changes,"beam_pixels":beam_pixels,"sources":sources,"scope":"native companion plus manually advanced real Player/laser fixture; not natural Main or mixed performance proof"}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	check(file!=null,"report open")
	if file:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	if not failed: print("DRONE GPU PASS: 30 opaque poses; 60 flight frames/%d changes; actual Player/laser fixture"%changes)
	quit(1 if failed else 0)
func measure(pixels: Image) -> Dictionary:
	var counts := {"opaque":0,"partial":0,"edge":0}
	for y in pixels.get_height():
		for x in pixels.get_width():
			var alpha := pixels.get_pixel(x,y).a
			counts.opaque += 1 if is_equal_approx(alpha,1) else 0
			counts.partial += 1 if alpha>0 and alpha<1 else 0
			counts.edge += 1 if alpha>0 and (x==0 or y==0 or x==pixels.get_width()-1 or y==pixels.get_height()-1) else 0
	return counts
