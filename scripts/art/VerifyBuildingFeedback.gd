extends SceneTree
## Actual maps, native player, and original building code at 1:1 scale.
const Definitions=preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Player=preload("res://scripts/actors/Player.gd")
const OUTPUT="res://build/diagnostics/campaign-goal/building-feedback-gpu-v5"
var checks:=0
var failures:=0
var sources: Dictionary={}
var samples: Array[Dictionary]=[]
var captures: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: VerifyBuildingFeedback "+label)
func _initialize() -> void: call_deferred("run")
func capture(state: String) -> void:
	for sample in samples: sample.label.text="第%d关 · %s · 建筑可破坏"%[sample.chapter,state]
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var montage:=Image.create(1280,1080,false,Image.FORMAT_RGBA8)
	for sample in samples:
		var pixels: Image=sample.view.get_texture().get_image()
		check(pixels!=null and pixels.get_size()==Vector2i(640,360),"actual GPU pixels chapter%d"%sample.chapter)
		if pixels!=null:
			pixels.convert(Image.FORMAT_RGBA8)
			montage.blit_rect(pixels,Rect2i(0,0,640,360),Vector2i(((sample.chapter-1)%2)*640,((sample.chapter-1)/2)*360))
	var path:=OUTPUT.path_join(state+".png")
	check(montage.save_png(path)==OK,"new original-size montage "+state)
	captures.append({"state":state,"path":path,"sha256":FileAccess.get_sha256(path)})
func run() -> void:
	check(DisplayServer.get_name()!="headless","actual GPU renderer required")
	check(not DirAccess.dir_exists_absolute(OUTPUT),"preserve prior evidence")
	if failures: quit(1); return
	check(DirAccess.make_dir_recursive_absolute(OUTPUT)==OK,"fresh evidence directory")
	for path in ["scripts/world/BuildingDamageView.gd","scripts/world/DestructibleObstacle.gd","scripts/world/ArenaLayout.gd","scripts/effects/CombatVfx.gd","scripts/art/VerifyBuildingFeedback.gd","scripts/actors/Player.gd"]: sources[path]=FileAccess.get_sha256("res://"+path)
	var saved: Dictionary={}
	for base in ["user://five_minute_overdrive_campaign_v1.json","user://five_minute_overdrive_journey_v1.json"]:
		for suffix in ["",".bak",".tmp"]: saved[base+suffix]=FileAccess.get_sha256(base+suffix) if FileAccess.file_exists(base+suffix) else "MISSING"
	for chapter in range(1,7):
		var definition: Dictionary=Definitions.get_definition(chapter)
		var view:=SubViewport.new(); view.size=Vector2i(640,360); view.world_2d=World2D.new()
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
		var map: Node2D=definition.map.instantiate(); map.map_seed=521; view.add_child(map)
		var wall: Node2D
		for candidate in map.layout.get_children():
			var size: Vector2=candidate.get_damage_rect().size
			if size.x<=480 and size.y<=220: wall=candidate; break
		check(wall!=null,"chapter%d real building fits1:1 viewport"%chapter)
		if wall==null: quit(1); return
		var rect: Rect2=wall.get_damage_rect()
		var camera:=Camera2D.new(); camera.position=wall.to_global(Vector2(0,wall.occlusion_rect.position.y-12))+Vector2(0,124)
		view.add_child(camera); camera.make_current()
		var player:=Player.new()
		player.position=map.layout.resolve_spawn_position(Vector2(rect.position.x-64,rect.get_center().y+16),Player.BODY_RADIUS)
		check(map.layout.is_position_walkable(player.position,Player.BODY_RADIUS),"preview player stands in real walkable space")
		view.add_child(player); player.set_physics_process(false)
		var layer:=CanvasLayer.new(); view.add_child(layer)
		var label:=Label.new(); label.position=Vector2(16,12); label.add_theme_font_size_override("font_size",17)
		label.add_theme_color_override("font_color",Color("f3eddc")); label.add_theme_color_override("font_outline_color",Color("123b3b"))
		label.add_theme_constant_override("outline_size",5); layer.add_child(label)
		var art:=wall.get_node_or_null("Art")
		if art==null: art=wall.get_node("PropArt")
		for path in [definition.map.resource_path,map.get_script().resource_path,map.layout.get_script().resource_path,map.floor_view.get_script().resource_path,wall.get_script().resource_path,art.get_script().resource_path]: sources[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
		samples.append({"chapter":chapter,"view":view,"wall":wall,"map":map,"rect":rect,"label":label})
	await physics_frame; await process_frame
	await capture("完好")
	for sample in samples:
		sample.wall.take_damage(sample.wall.health.max_health*0.35)
		var feedback: Node2D=sample.wall.get_node("DamageFeedback")
		feedback.set_process(false); feedback._process(0.03)
		check(is_equal_approx(feedback.health_ratio,0.65) and feedback.damage_level==1,"actual damaged state chapter%d"%sample.chapter)
		var bar: Rect2=feedback.bar_rect
		var canvas: Transform2D=feedback.get_global_transform_with_canvas()
		check((canvas*bar.position).y>=40 and (canvas*bar.end).y<340,"bar not cropped or hidden by diagnostic title")
	await capture("受击")
	for sample in samples:
		sample.wall.take_damage(sample.wall.health.max_health*0.41)
		var feedback: Node2D=sample.wall.get_node("DamageFeedback")
		feedback.set_process(false); feedback._process(0.20)
		check(is_equal_approx(feedback.health_ratio,0.24) and feedback.damage_level==3,"actual heavy damage chapter%d"%sample.chapter)
	await capture("重损")
	for sample in samples: sample.wall.take_damage(sample.wall.health.max_health)
	await physics_frame; await process_frame; await physics_frame
	for sample in samples:
		check(not is_instance_valid(sample.wall) and sample.map.layout.is_position_walkable(sample.rect.get_center(),1),"destroyed native building and nav released")
	await capture("拆除")
	for sample in samples: sample.view.free()
	await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source unchanged "+path)
	for path in saved: check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING")==saved[path],"default save unchanged")
	var report:=FileAccess.open(OUTPUT.path_join("report.json"),FileAccess.WRITE)
	check(report!=null,"report writer")
	if report!=null:
		report.store_string(JSON.stringify({"valid":failures==0,"checks":checks,"renderer":RenderingServer.get_video_adapter_name(),"rendering_arguments":OS.get_cmdline_args(),"sources":sources,"captures":captures,"limits":["Six real maps and native player, unscaled640x360 crops.","Controlled health states, not natural combat or final EXE/performance acceptance."]},"\t")); report.close()
	if failures==0: print("TEST PASS: VerifyBuildingFeedback %d"%checks)
	quit(1 if failures else 0)
