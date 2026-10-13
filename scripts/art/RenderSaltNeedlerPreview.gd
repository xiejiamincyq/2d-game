extends SceneTree
const EnemySource = preload("res://scripts/actors/Enemy.gd")
const Actor = preload("res://scenes/actors/native/salt_needler_paper_v1.tscn")
const OUT := "res://build/diagnostics/campaign-goal/salt-needler-preview-v2/"
const CLIPS := ["idle","walk","warning","attack","hit","death"]
class BodyOnly extends EnemySource:
	func _draw() -> void:
		pass # Only actor HUD excluded; actual native creation/shader retained.
var failed := false
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error("NEEDLER GPU FAIL: "+label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(OUT),"GPU and new output required")
	if failed:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var sources := {}
	for path in ["scripts/art/RenderSaltNeedlerPreview.gd","scripts/actors/Enemy.gd","scripts/components/NativeNeedlerMotion.gd","scripts/components/NativeSporelingMotion.gd","scripts/components/NativeActorView.gd","scenes/art/technical/SaltNeedlerDraft.gd","scenes/art/technical/SaltNeedlerShapes.gd","scenes/actors/native/salt_needler_paper_v1.tscn","assets/art/actors/native/salt_needler_motion_v1.tres","assets/art/shaders/dasher_hit_flash.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"missing source hash "+path)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192,192)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := SubViewport.new()
	sheet.size = Vector2i(1280,640)
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)
	var background := ColorRect.new()
	background.size = sheet.size
	background.color = Color("304138")
	sheet.add_child(background)
	var samples: Array[Dictionary] = []
	for left in [false,true]:
		var enemy := BodyOnly.new()
		enemy.setup(EnemySource.EnemyKind.MARKSMAN,0,viewport)
		enemy.position = Vector2(96,112)
		viewport.add_child(enemy)
		enemy.set_physics_process(false)
		var body: Node2D = enemy.native_visual
		body.set_facing_left(left)
		for column in 6:
			var clip: String = CLIPS[column]
			if not left:
				var title := Label.new()
				title.text = clip
				title.position = Vector2(column*200+78,12)
				sheet.add_child(title)
			for row in 3:
				var phase: float = [0.0,0.45,0.85][row]
				body.sample_clip(clip,body.player.get_animation(clip).length*phase)
				for flash in [0.0,0.35]:
					enemy.static_flash_material.set_shader_parameter("flash_amount",flash)
					await process_frame
					await RenderingServer.frame_post_draw
					var pixels := viewport.get_texture().get_image()
					var opaque := 0
					var partial := 0
					var edge := 0
					for y in 192:
						for x in 192:
							var alpha := pixels.get_pixel(x,y).a
							opaque += 1 if alpha>=0.99 else 0
							partial += 1 if alpha>0.01 and alpha<0.99 else 0
							edge += 1 if alpha>0.01 and (x==0 or y==0 or x==191 or y==191) else 0
					check(opaque>700 and partial==0 and edge==0,"actual native body translucent/clipped "+clip)
					samples.append({"clip":clip,"phase":phase,"left":left,"flash":flash,"opaque":opaque,"partial":partial,"edge":edge})
				if not left:
					var preview = Actor.instantiate()
					sheet.add_child(preview)
					preview.position = Vector2(column*200+115,150+row*170)
					preview.scale = Vector2.ONE*2
					preview.sample_clip(clip,body.player.get_animation(clip).length*phase)
		enemy.free()
	await process_frame
	await RenderingServer.frame_post_draw
	check(sheet.get_texture().get_image().save_png(OUT+"poses.png")==OK,"sheet write")
	# Actual Enemy motion adapter, eight directions: hand chain bends, no root spin.
	var aims := Image.create(1280,240,false,Image.FORMAT_RGBA8)
	aims.fill(Color("304138"))
	var target := Node2D.new()
	viewport.add_child(target)
	var aiming := BodyOnly.new()
	aiming.setup(EnemySource.EnemyKind.MARKSMAN,0,viewport,target)
	aiming.position = Vector2(96,112)
	viewport.add_child(aiming)
	aiming.set_physics_process(false)
	for index in 8:
		target.position = aiming.position+Vector2.RIGHT.rotated(index*PI/4)*300
		aiming._update_static_motion(0)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image()
		aims.blend_rect(pixels,Rect2i(24,24,144,168),Vector2i(index*160+8,36))
	check(aims.save_png(OUT+"aims.png")==OK,"actual aimed pose sheet write")
	aiming.free()
	target.free()
	var mover = Actor.instantiate()
	viewport.add_child(mover)
	mover.position = Vector2(96,112)
	var previous := PackedByteArray()
	var changes := 0
	for frame in 60:
		mover.sample_clip("walk",frame/60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image().get_data()
		changes += 1 if frame>0 and pixels!=previous else 0
		previous = pixels
	check(changes>=50,"walk sequence static")
	for path in sources:
		check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed during capture")
	var file := FileAccess.open(OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"samples":samples,"gait_frames":60,"adjacent_changes":changes,"actual_aim_directions":8,"sources":sources,"scope":"Actual Enemy-created body/shader 72 GPU poses, only HUD excluded; 18 resource review poses, eight actual adapter aim directions and 60 gait frames. Not natural Main input, chapter 3 or human acceptance."},"\t"))
	file.close()
	sheet.free()
	viewport.free()
	await process_frame
	print("NEEDLER GPU %s: 72 actual shader poses, 60 gait frames/%d changes" % ["FAIL" if failed else "PASS",changes])
	quit(1 if failed else 0)
