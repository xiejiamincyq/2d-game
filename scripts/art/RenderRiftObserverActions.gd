extends SceneTree
## Controlled native-resource GPU matrix; not Boss gameplay/damage proof.
const SCENE := "res://scenes/actors/native/rift_observer_paper_v2.tscn"
const ACTIONS := ["beam","probes","refract"]
var checks := 0
var failures := 0
var output := ""
var viewport: SubViewport
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RenderRiftObserverActions "+label)
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
	for path in ["scripts/art/RenderRiftObserverActions.gd","scripts/art/BakeRiftObserverActions.gd","scripts/art/NativeRigCheckpoint.gd","scripts/components/NativeActorView.gd","scripts/components/NativeRiftObserverMotion.gd","scripts/tests/RiftObserverAttackResourceTest.gd","scripts/tests/RiftObserverMotionContractTest.gd","scripts/tests/RiftObserverAttackGateTest.gd","scripts/art/NativeArtValidator.gd","scripts/actors/Player.gd","scripts/components/NativePlayerView.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres","scenes/actors/native/rift_observer_paper_v1.tscn","scenes/actors/native/rift_observer_paper_v2.tscn","assets/art/actors/native/rift_observer_motion_v1.tres","assets/art/actors/native/rift_observer_motion_v2.tres","docs/art/native-manifests/rift_observer_paper_v2.json","docs/art/native-checkpoints/rift_observer_attack_v1.json","assets/art/shaders/dasher_hit_flash.gdshader"]:
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
	var paths := [["Torso/Lens/Pupil/AimOrigin"],["Torso/ScopeArmL/ElbowL/ProbeL/SensorOrigin","Torso/ScopeArmR/ElbowR/ProbeR/SensorOrigin"],["Torso/Beacon/PhaseOrigin"]]
	for action in ACTIONS:
		var clip: String = action+"_attack"; var length: float = view.player.get_animation(clip).length
		var previous := PackedByteArray(); var adjacent := 0; var positions := {}
		for path in paths[ACTIONS.find(action)]: positions[path] = []
		for frame in 30:
			view.sample_clip(clip,length*frame/29.0); var image := await pixels(); var current := image.get_data()
			var metric := inspect_image(image,view)
			check(metric.opaque>3000 and metric.partial==0 and metric.edge==0,"continuous opacity/clipping "+clip)
			check(metric.outside==0,"continuous declared framing "+clip+" "+str(metric))
			metric.merge({"clip":clip,"phase":frame/29.0}); continuous.append(metric)
			adjacent += 1 if frame>0 and current!=previous else 0; previous = current
			for path in positions: positions[path].append(view.skeleton.get_node(path).global_position)
		changes[action] = adjacent; check(adjacent>=20,"static active clip "+action)
		socket_ranges[action] = {}
		for path in positions:
			var span := 0.0
			for first in positions[path]:
				for second in positions[path]: span = maxf(span,first.distance_to(second))
			socket_ranges[action][path] = span; check(span>8,"articulated locator static "+action+" "+path)
		for sample in 7:
			var phases: Array = [0.0,0.18,0.30,0.46,0.60,0.90,1.0] if action=="probes" else [0.0,0.18,0.32,0.48,0.62,0.78,1.0] if action=="refract" else [0.0,0.16,0.30,0.46,0.60,0.90,1.0]
			view.sample_clip(clip,length*phases[sample]); var image := await pixels()
			sequence.blend_rect(image,Rect2i(0,0,320,320),Vector2i(sample*320,ACTIONS.find(action)*320))
	check(sequence.save_png(output+"action-keyframes.png")==OK,"save continuous extrema sheet"); captures["action-keyframes"] = FileAccess.get_sha256(output+"action-keyframes.png")
	view.free(); viewport.free(); await process_frame
	var small_scale := await render_gameplay_scale(captures)
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift")
	var report := {"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"samples":samples,"continuous_samples":continuous,"adjacent_action_changes":changes,"socket_motion_span":socket_ranges,"gameplay_scale_samples":small_scale,"scope":"Original 30-bone v2 resource, controlled left/right and actual flash shader opacity/bounds matrix, 30 GPU samples per active clip and moving all four real locators; fixed 1280x720 native Player and Boss at production player scale / Boss scale1. Not actual Boss/AI/damage geometry/dodge/victory/unlock6, OS input or dense performance."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("RIFT OBSERVER GPU %s: %d checks/%d poses, changes %s"%["PASS" if failures==0 else "FAIL",checks,samples.size(),str(changes)])
	quit(1 if failures else 0)


func render_gameplay_scale(captures: Dictionary) -> Array[Dictionary]:
	# Controlled same-frame native models only; no damage, map, AI or victory.
	viewport = SubViewport.new(); viewport.size = Vector2i(1280,720)
	viewport.transparent_bg = true; viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var player_view = load("res://scenes/actors/native/player_paper_v1.tscn").instantiate()
	player_view.scale = Vector2.ONE*load("res://scripts/actors/Player.gd").PLAYER_SIZE_SCALE
	player_view.position = Vector2(300,400); viewport.add_child(player_view)
	var rows: Array[Dictionary] = []
	var sheet := Image.create(1280,2160,false,Image.FORMAT_RGBA8); sheet.fill(Color("393442"))
	for index in ACTIONS.size():
		var action: String = ACTIONS[index]
		var bosses: Array[Node2D] = []
		for stage in 3:
			var boss = load(SCENE).instantiate(); boss.position = Vector2(540+stage*260,400)
			viewport.add_child(boss); boss.set_facing_left(stage==1)
			var clip: String = action+"_"+["warning","attack","recovery"][stage]
			boss.sample_clip(clip,boss.player.get_animation(clip).length*(0.18 if action=="probes" and stage==1 else 0.45))
			bosses.append(boss)
		player_view.sample_clip("idle",0.3)
		var image := await pixels()
		var metrics := {"action":action,"player_opaque":0,"player_partial":0,"boss_opaque":0,"boss_partial":0,"edge":0}
		for y in 720:
			for x in 1280:
				var alpha := image.get_pixel(x,y).a
				if alpha<=0.01: continue
				metrics.edge += 1 if x==0 or x==1279 or y==0 or y==719 else 0
				var key: String = "player_" if x<420 else "boss_"
				metrics[key+("opaque" if alpha>=0.99 else "partial")] += 1
		check(metrics.player_opaque>100 and metrics.boss_opaque>9000 and metrics.player_partial==0 and metrics.boss_partial==0 and metrics.edge==0,"actual small-scale opacity/framing "+str(metrics))
		check(player_view.scale==Vector2.ONE*load("res://scripts/actors/Player.gd").PLAYER_SIZE_SCALE,"native player hidden enlargement")
		for boss in bosses: check(boss.scale==Vector2.ONE,"native boss hidden enlargement")
		rows.append(metrics)
		sheet.blend_rect(image,Rect2i(0,0,1280,720),Vector2i(0,index*720))
		for boss in bosses: boss.free()
	check(sheet.save_png(output+"gameplay-scale.png")==OK,"save actual gameplay-scale matrix")
	captures["gameplay-scale"] = FileAccess.get_sha256(output+"gameplay-scale.png")
	player_view.free(); viewport.free(); await process_frame
	return rows
