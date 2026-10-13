extends SceneTree
## Actual actor/skin and player/pincer fixture, not a third-chapter playthrough.
const Source = preload("res://scripts/actors/FlankingCrabEnemy.gd")
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const PlayerSource = preload("res://scripts/actors/Player.gd")
const CLIPS := ["idle","walk","warning","attack","hit","death"]
class BodyOnly extends Source:
	func _draw() -> void: pass # Omit HUD only for body alpha measurement.
var failed := false
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error("CRAB GPU FAIL: "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier():
		quit(1)
		return
	var output := "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU and new output required")
	if failed:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderFlankingCrabPreview.gd","scripts/actors/FlankingCrabEnemy.gd","scripts/actors/Enemy.gd","scripts/campaign/RegionalEnemyFactory.gd","scripts/components/CrabPincerAttack.gd","scripts/components/ScrapperAttack.gd","scripts/components/NativeScrapperMotion.gd","scripts/components/NativeActorView.gd","scripts/actors/Player.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","scenes/actors/native/flanking_crab_paper_v1.tscn","assets/art/actors/native/flanking_crab_motion_v1.tres","assets/art/shaders/dasher_hit_flash.gdshader","scenes/art/technical/FlankingCrabDraft.gd","scenes/art/technical/FlankingCrabShapes.gd"]:
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
		enemy.setup(Source.EnemyKind.SCRAPPER,0,viewport)
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
					check(clip=="death" or counts.outside==0,"live pincer/leg exceeds production bounds "+clip)
					counts.merge({"clip":clip,"phase":phase,"left":left,"flash":flash})
					samples.append(counts)
					if not left and flash==0:
						pixels.resize(256,256,Image.INTERPOLATE_NEAREST)
						sheet.blend_rect(pixels,Rect2i(0,0,256,256),Vector2i(column*256,row*256))
		enemy.free()
	check(sheet.save_png(output+"poses.png")==OK,"six-clip review sheet write")
	var walker := BodyOnly.new()
	walker.setup(Source.EnemyKind.SCRAPPER,0,viewport)
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
	check(changes>=50,"actual four-leg gait static")
	viewport.free()
	await process_frame
	var arena := SubViewport.new()
	arena.size = Vector2i(640,320)
	arena.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(arena)
	var background := ColorRect.new()
	background.size = arena.size
	background.color = Color("47513c")
	arena.add_child(background)
	var target := PlayerSource.new()
	target.position = Vector2(350,190)
	arena.add_child(target)
	target.set_physics_process(false)
	var actual = Factory.create_actor(3,"flanking_crab",0,arena,target)
	actual.position = Vector2(290,190)
	arena.add_child(actual)
	actual.set_physics_process(false)
	actual.basic_attack.cooldown = 0
	actual._physics_process(0.01)
	var health_before: float = target.health.current_health
	for index in 4:
		if index>0: actual._physics_process([0.0,0.08,0.1,0.07][index])
		await process_frame
		await RenderingServer.frame_post_draw
		check(arena.get_texture().get_image().save_png(output+"attack-%d.png" % index)==OK,"actual pincer/player fixture capture")
	check(target.health.current_health<health_before and not actual.should_show_attack_marker(),"actual factory pincer does not damage/end warning")
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift during capture")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"samples":samples,"gait_frames":60,"adjacent_changes":changes,"sources":sources,"scope":"Actual FlankingCrabEnemy body/shader, 72 poses (HUD omitted only), 18 full-body poses, 60 adapter gait frames; four actual regional-factory/player/pincer/head-marker/health-bar captures with explicit attack timing. Not natural input, chapter 3 readiness, real-time performance or human acceptance."},"\t"))
	file.close()
	arena.free()
	await process_frame
	print("CRAB GPU %s: 72 poses, 60 gait frames/%d changes" % ["FAIL" if failed else "PASS",changes])
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
