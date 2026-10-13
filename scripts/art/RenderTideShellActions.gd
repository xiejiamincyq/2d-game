extends SceneTree
## GPU resource review only. No claim about a playable Boss or combat timing.
const SCENE := "res://scenes/actors/native/tide_shell_paper_v2.tscn"
const CLIPS := ["idle","walk","hit","entrance","ripple_warning","ripple_attack","ripple_recovery","pincer_warning","pincer_attack","pincer_recovery","salt_warning","salt_attack","salt_recovery","death"]
var checks := 0
var failures := 0
var output := ""
var viewport: SubViewport
var captures := {}
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TIDE SHELL GPU FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func pixels() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh GPU evidence required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderTideShellActions.gd","scripts/art/BakeTideShellActions.gd","scripts/art/NativeRigCheckpoint.gd","scripts/components/NativeActorView.gd","scenes/actors/native/tide_shell_paper_v1.tscn","scenes/actors/native/tide_shell_paper_v2.tscn","assets/art/actors/native/tide_shell_motion_v1.tres","assets/art/actors/native/tide_shell_motion_v2.tres","docs/art/native-manifests/tide_shell_paper_v2.json","docs/art/native-checkpoints/tide_shell_attack_v1.json","assets/art/shaders/dasher_hit_flash.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"missing source "+path)
	viewport = SubViewport.new()
	viewport.size = Vector2i(320,320)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := Image.create(960,960,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("263b3e"))
	var mirrored := Image.create(960,960,false,Image.FORMAT_RGBA8)
	mirrored.fill(Color("263b3e"))
	var samples: Array[Dictionary] = []
	for left in [false,true]:
		var view = load(SCENE).instantiate()
		view.position = Vector2(160,180)
		viewport.add_child(view)
		view.set_facing_left(left)
		var flash := ShaderMaterial.new()
		flash.shader = load("res://assets/art/shaders/dasher_hit_flash.gdshader")
		view.get_node("Facing/Skin").material = flash
		for clip in CLIPS:
			for phase in [0.0,0.45,0.85]:
				check(view.sample_clip(clip,view.player.get_animation(clip).length*phase),"sample "+clip)
				for amount in [0.0,0.35]:
					flash.set_shader_parameter("flash_amount",amount)
					var image := await pixels()
					var opaque := 0
					var partial := 0
					var edge := 0
					var outside := 0
					var bounds: Rect2 = view.get_node("Facing").transform*view.body_rect
					for y in 320:
						for x in 320:
							var alpha := image.get_pixel(x,y).a
							opaque += 1 if alpha>=0.99 else 0
							partial += 1 if alpha>0.01 and alpha<0.99 else 0
							edge += 1 if alpha>0.01 and (x==0 or x==319 or y==0 or y==319) else 0
							outside += 1 if alpha>=0.99 and not bounds.grow(1).has_point(Vector2(x+0.5-160,y+0.5-180)) else 0
					check(opaque>3000 and partial==0 and edge==0,"opacity/frame clipping "+clip)
					check(clip=="death" or outside==0,"camera body bounds "+clip)
					samples.append({"clip":clip,"phase":phase,"left":left,"flash":amount,"opaque":opaque,"partial":partial,"edge":edge,"outside":outside})
					if amount==0 and phase==0.45 and "_" in clip:
						var column: int = ["ripple","pincer","salt"].find(clip.get_slice("_",0))
						var row: int = ["warning","attack","recovery"].find(clip.get_slice("_",1))
						var destination: Image = mirrored if left else sheet
						destination.blend_rect(image,Rect2i(0,0,320,320),Vector2i(column*320,row*320))
		view.free()
	for pair in [["action-poses",sheet],["action-poses-left",mirrored]]:
		check(pair[1].save_png(output+pair[0]+".png")==OK,"save contact sheet")
		captures[pair[0]] = FileAccess.get_sha256(output+pair[0]+".png")
	var changes := {}
	var view = load(SCENE).instantiate()
	view.position = Vector2(160,180)
	viewport.add_child(view)
	for action in ["ripple","pincer","salt"]:
		var previous := PackedByteArray()
		var adjacent := 0
		var clip: String = action+"_attack"
		var length: float = view.player.get_animation(clip).length
		for frame in 30:
			view.sample_clip(clip,length*frame/29.0)
			var image := await pixels()
			var current := image.get_data()
			adjacent += 1 if frame>0 and current!=previous else 0
			previous = current
		changes[action] = adjacent
		# Ripple/salt hold an impact pose; pincer must perform two distinct strokes.
		check(adjacent>=7 and (action!="pincer" or adjacent>=25),"static action frames "+action)
	view.free()
	viewport.free()
	await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift")
	var report := {"passed":failures==0,"checks":checks,"samples":samples,"adjacent_action_changes":changes,"sources":sources,"captures":captures,"scope":"Native resource + actual flash shader GPU opacity/bounds matrix and two mirrored pose sheets; 30 controlled samples per active clip. Not an Actor, gameplay, hit timing, safe projectile origin, dodge test, Boss victory, chapter unlock or performance proof."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("TIDE SHELL GPU %s: %d checks/%d poses, changes %s" % ["PASS" if failures==0 else "FAIL",checks,samples.size(),str(changes)])
	quit(0 if failures==0 else 1)
