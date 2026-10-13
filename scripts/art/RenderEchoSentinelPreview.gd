extends SceneTree
## Production bell skin and positive sound-rim visibility, not fifth-chapter play.
const Source = preload("res://scripts/actors/EchoSentinelEnemy.gd")
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const PlayerSource = preload("res://scripts/actors/Player.gd")
const CLIPS := ["idle","walk","warning","attack","hit","death"]
class BodyOnly extends Source:
	func _draw() -> void: pass # Exclude HUD only from body alpha measurements.
var failed := false
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error("SENTINEL GPU FAIL: "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier():
		quit(1)
		return
	var output := "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU/new evidence directory required")
	if failed:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderEchoSentinelPreview.gd","scripts/actors/EchoSentinelEnemy.gd","scripts/actors/Enemy.gd","scripts/campaign/RegionalEnemyFactory.gd","scripts/components/EchoRingAttack.gd","scripts/components/ScrapperAttack.gd","scripts/components/NativeScrapperMotion.gd","scripts/components/NativeActorView.gd","scripts/actors/Player.gd","scenes/actors/native/player_paper_v1.tscn","scenes/actors/native/echo_sentinel_paper_v1.tscn","assets/art/actors/native/echo_sentinel_motion_v1.tres","assets/art/shaders/dasher_hit_flash.gdshader","scenes/art/technical/EchoSentinelDraft.gd","scenes/art/technical/EchoSentinelShapes.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"source hash missing "+path)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192,192)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := Image.create(1536,768,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("304138"))
	var samples: Array[Dictionary] = []
	for left in [false,true]:
		var enemy := BodyOnly.new()
		enemy.setup(Source.EnemyKind.SPITTER,0,viewport)
		enemy.position = Vector2(96,98)
		viewport.add_child(enemy)
		enemy.set_physics_process(false)
		var body = enemy.native_visual
		body.set_facing_left(left)
		for column in 6:
			for row in 3:
				var clip: String = CLIPS[column]
				var phase: float = [0,0.45,0.85][row]
				body.sample_clip(clip,body.player.get_animation(clip).length*phase)
				for flash in [0.0,0.35]:
					enemy.static_flash_material.set_shader_parameter("flash_amount",flash)
					await process_frame
					await RenderingServer.frame_post_draw
					var pixels := viewport.get_texture().get_image()
					var counts := _measure(pixels,body.get_global_transform_with_canvas()*enemy.get_visual_rect())
					check(counts.opaque>700 and counts.partial==0 and counts.edge==0,"body translucent/clipped "+clip)
					check(clip=="death" or counts.outside==0,"live ear-wing outside production bounds "+clip)
					counts.merge({"clip":clip,"phase":phase,"left":left,"flash":flash})
					samples.append(counts)
					if not left and flash==0:
						pixels.resize(256,256,Image.INTERPOLATE_NEAREST)
						sheet.blend_rect(pixels,Rect2i(0,0,256,256),Vector2i(column*256,row*256))
		enemy.free()
	check(sheet.save_png(output+"poses.png")==OK,"six-motion review write")
	var walker := BodyOnly.new()
	walker.setup(Source.EnemyKind.SPITTER,0,viewport)
	walker.position = Vector2(96,98)
	viewport.add_child(walker)
	walker.set_physics_process(false)
	walker.velocity = Vector2(90,0)
	var previous := PackedByteArray()
	var changes := 0
	for frame in 60:
		walker._update_static_motion(1/60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image().get_data()
		changes += 1 if frame>0 and pixels!=previous else 0
		previous = pixels
	check(changes>=50,"actual adapter gait static")
	walker.free()
	viewport.free()
	await process_frame
	var arena := SubViewport.new()
	arena.size = Vector2i(640,480)
	arena.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(arena)
	var background := ColorRect.new()
	background.size = arena.size
	background.color = Color("47513c")
	background.z_index = -100
	arena.add_child(background)
	var world := Node2D.new()
	arena.add_child(world)
	var target := PlayerSource.new()
	target.position = Vector2(360,270)
	world.add_child(target)
	target.set_physics_process(false)
	var actual = Factory.create_actor(5,"echo_sentinel",0,world,target)
	actual.position = Vector2(260,270)
	world.add_child(actual)
	actual.set_physics_process(false)
	actual.basic_attack.cooldown = 0
	actual._physics_process(0.01)
	var before: float = target.health.current_health
	var rim_pixels := 0
	for index in 4:
		if index==1: actual._physics_process(0.28)
		elif index==2: actual._physics_process(0.19)
		elif index==3: actual.take_damage(1000)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := arena.get_texture().get_image()
		check(pixels.save_png(output+"ring-%d.png" % index)==OK,"actual warning/ring/hit/death capture")
		if index==0: check(actual.should_show_attack_marker(),"fixture has no short head warning")
		if index==1:
			for y in pixels.get_height():
				for x in pixels.get_width():
					rim_pixels += 1 if pixels.get_pixel(x,y).is_equal_approx(Color("b5a9bd")) else 0
			check(rim_pixels>40 and target.health.current_health==before,"wave not visibly expanding before hit")
		if index==2: check(target.health.current_health==before-15,"visible ring does not damage actual player once")
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift during capture")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"samples":samples,"rim_visible_pixels":rim_pixels,"gait_frames":60,"adjacent_changes":changes,"sources":sources,"scope":"Actual sentry skin/shader: 72 poses, 18-pose sheet, actual adapter gait. Four actual factory/native-player/short-warning/hollow-wave/hit/death captures and positive rim visibility; attack time explicitly manual. Not fifth chapter, natural input, performance or human acceptance."},"\t"))
	file.close()
	arena.free()
	await process_frame
	print("SENTINEL GPU %s: 72 poses, 60 gait frames/%d changes, rim pixels %d" % ["FAIL" if failed else "PASS",changes,rim_pixels])
	quit(1 if failed else 0)
func _measure(pixels: Image,bounds: Rect2) -> Dictionary:
	var counts := {"opaque":0,"partial":0,"edge":0,"outside":0}
	for y in pixels.get_height():
		for x in pixels.get_width():
			var a := pixels.get_pixel(x,y).a
			counts.opaque += 1 if a>=0.99 else 0
			counts.partial += 1 if a>0.01 and a<0.99 else 0
			counts.edge += 1 if a>0.01 and (x==0 or y==0 or x==pixels.get_width()-1 or y==pixels.get_height()-1) else 0
			counts.outside += 1 if a>=0.99 and not bounds.grow(1).has_point(Vector2(x+0.5,y+0.5)) else 0
	return counts
