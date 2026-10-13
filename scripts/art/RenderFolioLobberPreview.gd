extends SceneTree
const EnemySource = preload("res://scripts/actors/Enemy.gd")
const OUT := "res://build/diagnostics/campaign-goal/folio-lobber-preview-v2/"
const CLIPS := ["idle","walk","warning","attack","hit","death"]
class BodyOnly extends EnemySource:
	func _draw() -> void:
		pass # Excludes HUD only; actual Enemy-created rig and shader retained.
var failed := false
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error("FOLIO GPU FAIL: "+label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(OUT),"GPU/new output required")
	if failed:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var sources := {}
	for path in ["scripts/art/RenderFolioLobberPreview.gd","scripts/actors/Enemy.gd","scripts/components/NativeFolioMotion.gd","scripts/components/NativeSporelingMotion.gd","scripts/components/NativeActorView.gd","scripts/components/LobbedProjectile.gd","scenes/art/technical/FolioLobberDraft.gd","scenes/art/technical/FolioLobberShapes.gd","scenes/actors/native/folio_lobber_paper_v1.tscn","assets/art/actors/native/folio_lobber_motion_v1.tres","assets/art/shaders/dasher_hit_flash.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"missing source hash "+path)
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
		enemy.setup(EnemySource.EnemyKind.LOBBER,0,viewport)
		enemy.position = Vector2(96,112)
		viewport.add_child(enemy)
		enemy.set_physics_process(false)
		var body: Node2D = enemy.native_visual
		body.set_facing_left(left)
		for column in 6:
			var clip: String = CLIPS[column]
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
					check(opaque>700 and partial==0 and edge==0,"actual body translucent/clipped "+clip)
					samples.append({"clip":clip,"phase":phase,"left":left,"flash":flash,"opaque":opaque,"partial":partial,"edge":edge})
					if not left and flash==0:
						# Entire viewport, not a head-only crop: review must show gait
						# shins, feet, thrown hand and the full sideways death pose.
						pixels.resize(256,256,Image.INTERPOLATE_NEAREST)
						sheet.blend_rect(pixels,Rect2i(0,0,256,256),Vector2i(column*256,row*256))
		enemy.free()
	check(sheet.save_png(OUT+"poses.png")==OK,"sheet write")
	var target := Node2D.new()
	target.position = Vector2(165,120)
	viewport.add_child(target)
	var actual := EnemySource.new()
	actual.setup(EnemySource.EnemyKind.LOBBER,0,viewport,target)
	actual.position = Vector2(80,112)
	viewport.add_child(actual)
	actual.set_physics_process(false)
	actual.ranged_is_winding_up = true
	actual.ranged_windup_remaining = 0.35
	actual.ranged_target_position = target.position
	var throw_sheet := Image.create(1280,260,false,Image.FORMAT_RGBA8)
	throw_sheet.fill(Color("304138"))
	var launch_count := 0
	for frame in 31:
		actual._update_lobber(1/60.0,target)
		actual._update_static_motion(1/60.0)
		for child in viewport.get_children():
			if child is LobbedProjectile:
				child.set_physics_process(false)
				child._physics_process(1/60.0)
				launch_count = 1
		await process_frame
		await RenderingServer.frame_post_draw
		if frame in [0,10,20,30]:
			var pixels := viewport.get_texture().get_image()
			pixels.resize(288,288,Image.INTERPOLATE_NEAREST)
			throw_sheet.blend_rect(pixels,Rect2i(0,24,288,260),Vector2i((frame/10)*320,0))
	check(launch_count==1,"actual emission absent")
	check(throw_sheet.save_png(OUT+"actual-throw.png")==OK,"actual throw write")
	actual.free()
	target.free()
	for child in viewport.get_children():
		child.free()
	var mover := BodyOnly.new()
	mover.setup(EnemySource.EnemyKind.LOBBER,0,viewport)
	mover.position = Vector2(96,112)
	viewport.add_child(mover)
	mover.set_physics_process(false)
	var previous := PackedByteArray()
	var changes := 0
	for frame in 60:
		mover.native_visual.sample_clip("walk",frame/60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image().get_data()
		changes += 1 if frame>0 and pixels!=previous else 0
		previous = pixels
	check(changes>=50,"walk sequence static")
	for path in sources:
		check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed during capture")
	var file := FileAccess.open(OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"samples":samples,"gait_frames":60,"adjacent_changes":changes,"sources":sources,"scope":"72 actual Enemy-created skin/shader poses (HUD excluded), 18 review poses, four actual Enemy throw sequence frames with HUD, 60 gait frames. Not natural Main input, chapter 4 or human acceptance."},"\t"))
	file.close()
	viewport.free()
	await process_frame
	print("FOLIO GPU %s: 72 actual shader poses, 60 gait frames/%d changes" % ["FAIL" if failed else "PASS",changes])
	quit(1 if failed else 0)
