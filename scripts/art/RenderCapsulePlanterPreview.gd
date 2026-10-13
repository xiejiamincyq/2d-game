extends SceneTree
## Actual production skin/seed collision fixture, not fourth-chapter play.
const Source = preload("res://scripts/actors/CapsulePlanterEnemy.gd")
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const PlayerSource = preload("res://scripts/actors/Player.gd")
const Shot = preload("res://scripts/components/Projectile.gd")
const CLIPS := ["idle","walk","warning","attack","hit","death"]
class BodyOnly extends Source:
	func _draw() -> void: pass # Exclude HUD only for body alpha/bounds measurements.
var failed := false
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error("PLANTER GPU FAIL: "+label)
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
	for path in ["scripts/art/RenderCapsulePlanterPreview.gd","scripts/actors/CapsulePlanterEnemy.gd","scripts/actors/Enemy.gd","scripts/campaign/RegionalEnemyFactory.gd","scripts/components/CapsulePlantHazard.gd","scripts/components/Projectile.gd","scripts/components/NativeCapsulePlanterMotion.gd","scripts/components/NativeSporelingMotion.gd","scripts/components/NativeScrapperMotion.gd","scripts/components/NativeActorView.gd","scripts/actors/Player.gd","scenes/actors/native/player_paper_v1.tscn","scenes/actors/native/capsule_planter_paper_v1.tscn","assets/art/actors/native/capsule_planter_motion_v1.tres","assets/art/shaders/dasher_hit_flash.gdshader","scenes/art/technical/CapsulePlanterDraft.gd","scenes/art/technical/CapsulePlanterShapes.gd"]:
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
					check(clip=="death" or counts.outside==0,"living rack/clamp outside bounds "+clip)
					counts.merge({"clip":clip,"phase":phase,"left":left,"flash":flash})
					samples.append(counts)
					if not left and flash==0:
						pixels.resize(256,256,Image.INTERPOLATE_NEAREST)
						sheet.blend_rect(pixels,Rect2i(0,0,256,256),Vector2i(column*256,row*256))
		enemy.free()
	check(sheet.save_png(output+"poses.png")==OK,"complete six-motion review write")
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
	arena.size = Vector2i(640,360)
	arena.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(arena)
	var background := ColorRect.new()
	background.size = arena.size
	background.color = Color("47513c")
	background.z_index = -100 # Match the real nursery floor, below ground hazards.
	arena.add_child(background)
	var world := Node2D.new()
	arena.add_child(world)
	var target := PlayerSource.new()
	target.position = Vector2(430,220)
	world.add_child(target)
	target.set_physics_process(false)
	var actual = Factory.create_actor(4,"capsule_planter",0,world,target)
	actual.position = Vector2(260,220)
	world.add_child(actual)
	actual.set_physics_process(false)
	actual.shoot_cooldown = 0
	actual._physics_process(0.01)
	await _capture(arena,output+"plant-0.png")
	check(actual.should_show_attack_marker(),"actual fixture has no short head warning")
	actual._physics_process(0.19)
	# frame_post_draw resumes outside the normal deferred-message flush;
	# observe actual admission rather than assuming one process_frame is enough.
	var admission_deadline := Time.get_ticks_msec()+1500
	while get_nodes_in_group("capsule_plants").is_empty() and Time.get_ticks_msec()<admission_deadline:
		await process_frame
	var plants := get_nodes_in_group("capsule_plants")
	if plants.size()!=1:
		print("PLANTER ADMISSION DIAGNOSTIC: point=%s owned=%d pending=%s warning=%s" % [actual.planned_plant_position,actual.get_owned_plant_count(),actual.pending_plant,actual.ranged_is_winding_up])
		var diagnostic_shape := CircleShape2D.new()
		diagnostic_shape.radius = 32
		var diagnostic_query := PhysicsShapeQueryParameters2D.new()
		diagnostic_query.shape = diagnostic_shape
		diagnostic_query.transform = Transform2D(0,actual.planned_plant_position)
		diagnostic_query.collide_with_areas = true
		diagnostic_query.exclude = [actual.get_rid()]
		for hit in actual.get_world_2d().direct_space_state.intersect_shape(diagnostic_query):
			print("PLANTER ADMISSION BLOCKER: ",hit.collider.get_path()," groups=",hit.collider.get_groups())
		check(false,"actual placement absent before capture")
		arena.free()
		await process_frame
		quit(1)
		return
	var plant = plants[0]
	plant.set_physics_process(false)
	await _capture(arena,output+"plant-1.png")
	var seed_pixels := 0
	var seed_image := arena.get_texture().get_image()
	for y in range(-9,10):
		for x in range(-9,10):
			var pixel := seed_image.get_pixelv(Vector2i(plant.global_position)+Vector2i(x,y))
			seed_pixels += 1 if pixel.is_equal_approx(Color("93a16d")) else 0
	check(seed_pixels>50,"actual ground seed is hidden beneath fixture/background")
	var before: float = target.health.current_health
	target.global_position = plant.global_position+Vector2(20,0)
	plant._physics_process(0.56)
	await _capture(arena,output+"plant-2.png")
	check(target.health.current_health==before-9,"actual armed capsule does not damage actual player")
	var bullet := Shot.new()
	bullet.position = world.to_local(plant.global_position-Vector2(30,0))
	bullet.velocity = Vector2(240,0)
	bullet.damage = 20
	world.add_child(bullet)
	var deadline := Time.get_ticks_msec()+1500
	while is_instance_valid(plant) and Time.get_ticks_msec()<deadline: await physics_frame
	check(not is_instance_valid(plant),"actual player projectile did not break capsule")
	await _capture(arena,output+"plant-3.png")
	actual.take_damage(1000)
	await _capture(arena,output+"plant-4.png")
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift during capture")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"samples":samples,"seed_visible_pixels":seed_pixels,"gait_frames":60,"adjacent_changes":changes,"sources":sources,"scope":"Actual planter skin/shader, 72 body poses and 18-pose sheet, actual adapter gait; five factory/native-player/placement/pulse/destruction/death captures, positive seed visibility. Placement/pulse time is manually driven, projectile destruction is actual physics. Not fourth chapter, natural input, performance or human acceptance."},"\t"))
	file.close()
	arena.free()
	await process_frame
	print("PLANTER GPU %s: 72 poses, 60 gait frames/%d changes" % ["FAIL" if failed else "PASS",changes])
	quit(1 if failed else 0)
func _capture(arena: SubViewport,path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(arena.get_texture().get_image().save_png(path)==OK,"actual planting fixture capture")
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
