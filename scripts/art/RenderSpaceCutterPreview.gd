extends SceneTree
## Actual surveyor skin/shader, production gait and terrain-clipped cut snapshots.
## Combat snapshots manually advance time; not sixth-chapter natural input.
const Source = preload("res://scripts/actors/SpaceCutterEnemy.gd")
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const PlayerSource = preload("res://scripts/actors/Player.gd")
const CLIPS := ["idle","walk","warning","attack","hit","death"]
class BodyOnly extends Source:
	func _draw() -> void: pass
var failed := false
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error("CUTTER GPU FAIL: "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier():
		quit(1)
		return
	var output := "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU and unused output required")
	if failed:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderSpaceCutterPreview.gd","scripts/actors/SpaceCutterEnemy.gd","scripts/actors/Enemy.gd","scripts/campaign/RegionalEnemyFactory.gd","scripts/components/SpaceCutAttack.gd","scripts/components/NativeScrapperMotion.gd","scripts/components/NativeActorView.gd","scripts/actors/Player.gd","scenes/actors/native/player_paper_v1.tscn","scenes/actors/native/space_cutter_paper_v1.tscn","assets/art/actors/native/space_cutter_motion_v1.tres","assets/art/shaders/dasher_hit_flash.gdshader","scenes/art/technical/SpaceCutterDraft.gd","scenes/art/technical/SpaceCutterShapes.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
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
					check(counts.opaque>700 and counts.partial==0 and counts.edge==0,"translucent/cropped body "+clip)
					check(clip=="death" or counts.outside==0,"live armor outside reviewed bounds "+clip)
					counts.merge({"clip":clip,"phase":phase,"left":left,"flash":flash})
					samples.append(counts)
					if not left and flash==0:
						pixels.resize(256,256,Image.INTERPOLATE_NEAREST)
						sheet.blend_rect(pixels,Rect2i(0,0,256,256),Vector2i(column*256,row*256))
		enemy.free()
	check(sheet.save_png(output+"poses.png")==OK,"pose sheet write")
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
	check(changes>=50,"production gait frozen")
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
	var shots := Node2D.new()
	world.add_child(shots)
	var target := PlayerSource.new()
	target.position = Vector2(360,270)
	world.add_child(target)
	target.set_physics_process(false)
	var actual = Factory.create_actor(6,"space_cutter",0,shots,target)
	actual.position = Vector2(325,270)
	world.add_child(actual)
	actual.set_physics_process(false)
	actual.basic_attack.cooldown = 0
	actual._physics_process(0.01)
	var health_before: float = target.health.current_health
	var strike_pixels := 0
	var corpse = actual.native_visual
	for index in 3:
		if index==1: actual._physics_process(0.19)
		elif index==2: actual.take_damage(1000)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := arena.get_texture().get_image()
		check(pixels.save_png(output+"sweep-%d.png" % index)==OK,"actual sweep capture")
		if index==0: check(actual.should_show_attack_marker(),"head warning absent")
		if index==1:
			check(target.health.current_health==health_before-21 and shots.get_child_count()==0,"close strike not unique/also shoots")
			strike_pixels = _count_color(pixels,Color("c6b7a0"))
			check(strike_pixels>5,"compact cross strokes invisible")
	var corpse_deadline := Time.get_ticks_msec()+1200
	while is_instance_valid(corpse) and Time.get_ticks_msec()<corpse_deadline: await physics_frame
	check(not is_instance_valid(corpse),"native corpse does not finish")
	target.position = Vector2(430,270)
	var wall := StaticBody2D.new()
	wall.position = Vector2(400,270)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,100)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	var wall_visual := Polygon2D.new()
	wall_visual.polygon = PackedVector2Array([Vector2(-4,-50),Vector2(4,-50),Vector2(4,50),Vector2(-4,50)])
	wall_visual.color = Color("625e53")
	wall.add_child(wall_visual)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	var blocked = Factory.create_actor(6,"space_cutter",0,shots,target)
	blocked.position = Vector2(290,270)
	world.add_child(blocked)
	blocked.set_physics_process(false)
	blocked.basic_attack.cooldown = 0
	blocked._physics_process(0.01)
	await process_frame
	await RenderingServer.frame_post_draw
	check(blocked.should_show_attack_marker() and shots.get_child_count()==0,"cut lacks short head warning")
	check(arena.get_texture().get_image().save_png(output+"wall-warning.png")==OK,"wall warning write")
	blocked._physics_process(0.16)
	check(blocked.native_visual.player.current_animation=="attack" and blocked.basic_attack.line_end.x<=396.1,"actual cut not terrain-clipped")
	await process_frame
	await RenderingServer.frame_post_draw
	var blocked_pixels := arena.get_texture().get_image()
	check(blocked_pixels.save_png(output+"wall-active.png")==OK,"actual clipped line write")
	var clipped_pixels := _count_color(blocked_pixels,Color("c6b7a0"))
	var beyond := 0
	for y in blocked_pixels.get_height():
		for x in range(400,blocked_pixels.get_width()):
			beyond += 1 if blocked_pixels.get_pixel(x,y).is_equal_approx(Color("c6b7a0")) else 0
	check(clipped_pixels>20 and beyond==0,"visible cut missing or extends past wall")
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift during capture")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"samples":samples,"strike_visible_pixels":strike_pixels,"clipped_visible_pixels":clipped_pixels,"gait_frames":60,"adjacent_changes":changes,"sources":sources,"scope":"72 actual body/shader poses; 60 production gait frames; real factory/native-player cut and actual StaticBody clipped line screenshots with manually driven timing. Real autonomous clock is tested separately; not sixth chapter, natural input, performance or human acceptance."},"\t"))
	file.close()
	arena.free()
	await process_frame
	print("CUTTER GPU %s: 72 poses, 60 gait/%d changes, cut %d / clipped %d pixels" % ["FAIL" if failed else "PASS",changes,strike_pixels,clipped_pixels])
	quit(1 if failed else 0)
func _count_color(pixels: Image,color: Color) -> int:
	var result := 0
	for y in pixels.get_height():
		for x in pixels.get_width():
			result += 1 if pixels.get_pixel(x,y).is_equal_approx(color) else 0
	return result
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
