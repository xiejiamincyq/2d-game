extends SceneTree
## Controlled native-resource GPU matrix; not Boss gameplay/damage proof.
const SCENE := "res://scenes/actors/native/bell_priest_paper_v2.tscn"
const ACTIONS := ["bell","pendant","crown"]
var checks := 0
var failures := 0
var output := ""
var viewport: SubViewport
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RenderBellPriestActions "+label)
func _initialize() -> void: call_deferred("run")
func pixels() -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func inspect_image(image: Image,view: Node2D) -> Dictionary:
	var opaque := 0; var partial := 0; var edge := 0; var outside := 0; var extra_padding := 0.0
	var bounds: Rect2 = view.get_node("Facing").transform*view.body_rect
	for y in 320:
		for x in 320:
			var alpha := image.get_pixel(x,y).a
			opaque += 1 if alpha>=0.99 else 0
			partial += 1 if alpha>0.01 and alpha<0.99 else 0
			edge += 1 if alpha>0.01 and (x==0 or x==319 or y==0 or y==319) else 0
			outside += 1 if alpha>=0.99 and not bounds.grow(1).has_point(Vector2(x+0.5-160,y+0.5-180)) else 0
			if alpha>=0.99:
				var at := Vector2(x+0.5-160,y+0.5-180)
				extra_padding = maxf(extra_padding,maxf(maxf(bounds.position.x-at.x,at.x-bounds.end.x),maxf(bounds.position.y-at.y,at.y-bounds.end.y)))
	return {"opaque":opaque,"partial":partial,"edge":edge,"outside":outside,"extra_bounds_padding":extra_padding}
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh actual GPU folder")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}; var captures := {}; var samples: Array[Dictionary] = []
	for path in ["scripts/art/RenderBellPriestActions.gd","scripts/art/BakeBellPriestActions.gd","scripts/art/NativeRigCheckpoint.gd","scripts/components/NativeActorView.gd","scripts/components/NativeBellPriestMotion.gd","scripts/tests/BellPriestAttackResourceTest.gd","scripts/tests/BellPriestMotionContractTest.gd","scenes/actors/native/bell_priest_paper_v1.tscn","scenes/actors/native/bell_priest_paper_v2.tscn","assets/art/actors/native/bell_priest_motion_v1.tres","assets/art/actors/native/bell_priest_motion_v2.tres","docs/art/native-manifests/bell_priest_paper_v2.json","docs/art/native-checkpoints/bell_priest_attack_v1.json","assets/art/shaders/dasher_hit_flash.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"source "+path)
	viewport = SubViewport.new(); viewport.size = Vector2i(320,320); viewport.transparent_bg = true
	viewport.world_2d = World2D.new(); viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	for left in [false,true]:
		var sheet := Image.create(960,960,false,Image.FORMAT_RGBA8); sheet.fill(Color("393442"))
		var view = load(SCENE).instantiate(); view.position = Vector2(160,180); viewport.add_child(view); view.set_facing_left(left)
		var flash := ShaderMaterial.new(); flash.shader = load("res://assets/art/shaders/dasher_hit_flash.gdshader"); view.get_node("Facing/Skin").material = flash
		var clips: Array = ["idle","walk","hit","entrance"]
		for action in ACTIONS:
			for stage in ["warning","attack","recovery"]: clips.append(action+"_"+stage)
		clips.append("death")
		for clip in clips:
			for phase in [0.0,0.45,0.85]:
				check(view.sample_clip(clip,view.player.get_animation(clip).length*phase),"sample "+clip)
				for amount in [0.0,0.35]:
					flash.set_shader_parameter("flash_amount",amount); var image := await pixels(); var metric := inspect_image(image,view)
					check(metric.opaque>3000 and metric.partial==0 and metric.edge==0,"opaque/unclipped "+clip+" "+str(metric))
					check(clip=="death" or metric.outside==0,"conservative visual bounds "+clip+" "+str(metric))
					metric.merge({"clip":clip,"phase":phase,"left":left,"flash":amount}); samples.append(metric)
					if amount==0 and phase==0.45 and "_" in clip:
						sheet.blend_rect(image,Rect2i(0,0,320,320),Vector2i(ACTIONS.find(clip.get_slice("_",0))*320,["warning","attack","recovery"].find(clip.get_slice("_",1))*320))
		view.free()
		var name := "action-poses-left" if left else "action-poses"
		check(sheet.save_png(output+name+".png")==OK,"save pose sheet"); captures[name] = FileAccess.get_sha256(output+name+".png")
	var sequence := Image.create(2240,960,false,Image.FORMAT_RGBA8); sequence.fill(Color("393442"))
	var view = load(SCENE).instantiate(); view.position = Vector2(160,180); viewport.add_child(view)
	var changes := {}; var socket_ranges := {}; var continuous: Array[Dictionary] = []
	var paths := ["Torso/Bell/Clapper/BeatOrigin","Torso/ArmL/ForearmL/HandL/ChainL/PendantL/PendantOrigin","Torso/Head/Crown/RecallOrigin"]
	for action in ACTIONS:
		var clip: String = action+"_attack"; var length: float = view.player.get_animation(clip).length
		var previous := PackedByteArray(); var adjacent := 0; var positions: Array[Vector2] = []
		for frame in 30:
			view.sample_clip(clip,length*frame/29.0); var image := await pixels(); var current := image.get_data()
			var metric := inspect_image(image,view)
			check(metric.opaque>3000 and metric.partial==0 and metric.edge==0,"continuous opacity/clipping "+clip)
			check(metric.outside==0,"continuous declared framing "+clip+" "+str(metric))
			metric.merge({"clip":clip,"phase":frame/29.0}); continuous.append(metric)
			adjacent += 1 if frame>0 and current!=previous else 0; previous = current
			positions.append(view.skeleton.get_node(paths[ACTIONS.find(action)]).global_position)
		changes[action] = adjacent; check(adjacent>=20,"static active clip "+action)
		var span := 0.0
		for first in positions:
			for second in positions: span = maxf(span,first.distance_to(second))
		socket_ranges[action] = span; check(span>8,"articulated locator static "+action)
		for sample in 7:
			var phases: Array = [0.0,0.24,0.50,0.65,0.76,0.90,1.0] if action=="pendant" else [0.0,0.16,0.30,0.46,0.60,0.76,1.0]
			view.sample_clip(clip,length*phases[sample]); var image := await pixels()
			sequence.blend_rect(image,Rect2i(0,0,320,320),Vector2i(sample*320,ACTIONS.find(action)*320))
	check(sequence.save_png(output+"action-keyframes.png")==OK,"save continuous extrema sheet"); captures["action-keyframes"] = FileAccess.get_sha256(output+"action-keyframes.png")
	view.free(); viewport.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift")
	var report := {"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"samples":samples,"continuous_samples":continuous,"adjacent_action_changes":changes,"socket_motion_span":socket_ranges,"scope":"Original 26-bone v2 resource, controlled left/right and actual flash shader opacity/bounds matrix, 30 GPU samples per active clip and moving real locators. Not actual Boss/AI/damage geometry/dodge/victory/unlock6, OS input or dense performance."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("BELL PRIEST GPU %s: %d checks/%d poses, changes %s"%["PASS" if failures==0 else "FAIL",checks,samples.size(),str(changes)])
	quit(1 if failures else 0)
