extends SceneTree
## Bone-resource review only. A production adapter fixture is not a chapter actor.
const Motion = preload("res://scripts/components/NativeBossMotion.gd")
const FLASH = preload("res://assets/art/shaders/dasher_hit_flash.gdshader")
const CLIPS := ["idle","walk","hit","entrance","death"]
class Driver extends CharacterBody2D:
	var entrance_resolved := true
	var entrance_progress := 1.0
var failed := false
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error("BOSS RESOURCE GPU FAIL: "+label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() not in [2,3] or not args[0].is_valid_identifier() or not args[1].is_valid_identifier() or (args.size()==3 and [args[0],args[2]]!=["root_overseer_paper_v1","actions"]):
		quit(1)
		return
	var scene := "res://scenes/actors/native/"+args[0]+".tscn"
	var actions := args.size()==3
	var clips: Array=CLIPS.duplicate()
	if actions:
		for kind in ["sweep","slam","aimed_fan","twin_spiral","broken_ring"]:
			for suffix in ["warning","attack","recovery"]: clips.insert(clips.size()-1,kind+"_"+suffix)
		clips.insert(clips.size()-1,"phase_transition")
	var output := "res://build/diagnostics/campaign-goal/"+args[1]+"/"
	check(DisplayServer.get_name()!="headless" and ResourceLoader.exists(scene) and not DirAccess.dir_exists_absolute(output),"GPU/native scene/new output required")
	if failed:
		quit(1)
		return
	var packed: PackedScene = load(scene)
	var sources := {}
	var probe = packed.instantiate()
	var library: String = probe.get_node("AnimationPlayer").get_animation_library("").resource_path
	probe.free()
	for path in [scene,library,"res://scripts/art/RenderNativeBossResourcePreview.gd","res://scripts/components/NativeBossMotion.gd","res://scripts/components/NativeScrapperMotion.gd","res://scripts/components/NativeActorView.gd","res://assets/art/shaders/dasher_hit_flash.gdshader"]:
		sources[path] = FileAccess.get_sha256(path)
		check(sources[path].length()==64,"missing dependency "+path)
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,320)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := Image.create(clips.size()*320,960,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("343d40"))
	var samples: Array[Dictionary] = []
	for left in [false,true]:
		var body = packed.instantiate()
		body.position = Vector2(160,164)
		viewport.add_child(body)
		body.set_facing_left(left)
		var flash := ShaderMaterial.new()
		flash.shader = FLASH
		body.get_node("Facing/Skin").material = flash
		for column in clips.size():
			var clip: String = clips[column]
			for row in 3:
				var phase: float = [0.0,0.45,0.85][row]
				check(body.sample_clip(clip,body.player.get_animation(clip).length*phase),"missing pose "+clip)
				for strength in [0.0,0.35]:
					flash.set_shader_parameter("flash_amount",strength)
					await process_frame
					await RenderingServer.frame_post_draw
					var pixels := viewport.get_texture().get_image()
					var bounds: Rect2 = body.get_node("Facing").transform*body.body_rect
					var opaque := 0
					var partial := 0
					var edge := 0
					var outside := 0
					for y in 320:
						for x in 320:
							var alpha := pixels.get_pixel(x,y).a
							opaque += 1 if alpha>=0.99 else 0
							partial += 1 if alpha>0.01 and alpha<0.99 else 0
							edge += 1 if alpha>0.01 and (x==0 or y==0 or x==319 or y==319) else 0
							outside += 1 if alpha>=0.99 and not bounds.grow(1).has_point(Vector2(x+0.5-160,y+0.5-164)) else 0
					check(opaque>5000 and partial==0 and edge==0,"translucent/clipped body "+clip)
					check(clip=="death" or outside==0,"live motion escapes mirrored visual bounds "+clip+" "+str(phase)+" "+str(outside))
					samples.append({"clip":clip,"phase":phase,"left":left,"flash":strength,"opaque":opaque,"partial":partial,"edge":edge,"outside_bounds":outside})
					if not left and strength==0:
						sheet.blend_rect(pixels,Rect2i(0,0,320,320),Vector2i(column*320,row*320))
		body.free()
	check(sheet.save_png(output+"poses.png")==OK,"pose image write")
	if actions:
		for kind in ["sweep","slam","aimed_fan","twin_spiral","broken_ring","phase_transition"]:
			var column: int=clips.find(kind if kind=="phase_transition" else kind+"_warning")
			check(sheet.get_region(Rect2i(column*320,0,320 if kind=="phase_transition" else 960,960)).save_png(output+kind+".png")==OK,"action review sheet write")
	var continuous: Array[Dictionary]=[]
	if actions:
		for clip in clips:
			if clip in CLIPS: continue
			var sample_body=packed.instantiate(); sample_body.position=Vector2(160,164); viewport.add_child(sample_body)
			var previous_pixels:=PackedByteArray(); var adjacent:=0
			for frame in 30:
				check(sample_body.sample_clip(clip,sample_body.player.get_animation(clip).length*(float(frame)+0.5)/30.0),"continuous pose refused")
				await process_frame; await RenderingServer.frame_post_draw
				var pixels:=viewport.get_texture().get_image().get_data()
				if frame>0 and pixels!=previous_pixels: adjacent+=1
				previous_pixels=pixels
			check(adjacent>=25,"original action is visually static "+clip)
			continuous.append({"clip":clip,"samples":30,"adjacent_changes":adjacent})
			sample_body.free()
	var driver := Driver.new()
	driver.position = Vector2(160,164)
	viewport.add_child(driver)
	var body = packed.instantiate()
	driver.add_child(body)
	var motion := Motion.new(body)
	driver.velocity = Vector2(60,0)
	var previous := PackedByteArray()
	var changes := 0
	for frame in 60:
		motion.update(driver,1/60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image().get_data()
		changes += 1 if frame>0 and pixels!=previous else 0
		previous = pixels
	check(changes>=50,"real adapter samples static walk")
	for path in sources:
		check(FileAccess.get_sha256(path)==sources[path],"dependency changed during capture")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"scene":scene,"clips":clips,"samples":samples,"continuous":continuous,"gait_frames":60,"adjacent_changes":changes,"sources":sources,"scope":"Baked native resource/shared hit shader poses for declared clips, optional original action continuous samples and 60 NativeBossMotion walk frames driven by an author fixture. Not an actual gameplay Boss, attack-state adapter, chapter UI or normal-input victory."},"\t"))
	file.close()
	viewport.free()
	await process_frame
	print("BOSS RESOURCE GPU %s: %d poses, %d action samples, 60 walk adapter frames/%d changes" % ["FAIL" if failed else "PASS",samples.size(),continuous.size()*30,changes])
	quit(1 if failed else 0)
