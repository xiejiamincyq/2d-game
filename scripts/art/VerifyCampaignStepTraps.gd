extends SceneTree
## Real GPU, six actual maps and actual pressure plates at 1:1 gameplay scale.
## Controlled clocks; does not prove full chapter play or weapon coverage.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Player = preload("res://scripts/actors/Player.gd")
const OUTPUT := "res://build/diagnostics/campaign-goal/step-traps-gpu-v2"
const FIELD_NAMES := ["TrapField","HeatField","TidalField","SporeField","EchoField","RiftField"]
var checks := 0
var failures := 0
var samples: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var sources: Dictionary = {}
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("TEST FAIL: VerifyCampaignStepTraps "+label)
func _initialize() -> void: call_deferred("run")
func capture(state: String) -> void:
	for sample in samples: sample.label.text="第%d关 · %s · 压板80HP / 踩踏0.5秒 / 单次20"%[sample.chapter,state]
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var montage := Image.create(1280,1080,false,Image.FORMAT_RGBA8)
	for sample in samples:
		var pixels: Image=sample.view.get_texture().get_image()
		check(pixels!=null and pixels.get_size()==Vector2i(640,360),"actual GPU pixels chapter%d"%sample.chapter)
		if pixels!=null: montage.blit_rect(pixels,Rect2i(0,0,640,360),Vector2i(((sample.chapter-1)%2)*640,((sample.chapter-1)/2)*360))
	var path:=OUTPUT.path_join(state+".png")
	check(montage.save_png(path)==OK,"save original-size montage "+state)
	captures.append({"path":path,"sha256":FileAccess.get_sha256(path)})
func run() -> void:
	check(DisplayServer.get_name()!="headless","real renderer required")
	check(not DirAccess.dir_exists_absolute(OUTPUT),"preserve prior captures")
	if failures: quit(1); return
	check(DirAccess.make_dir_recursive_absolute(OUTPUT)==OK,"new output folder")
	for path in ["scripts/world/ReusableStepTrap.gd","scripts/world/ReusableTrapField.gd","scripts/art/VerifyCampaignStepTraps.gd"]:
		sources[path]=FileAccess.get_sha256("res://"+path)
	var saved: Dictionary={}
	for base in ["user://five_minute_overdrive_campaign_v1.json","user://five_minute_overdrive_journey_v1.json"]:
		for suffix in ["",".bak",".tmp"]:
			saved[base+suffix]=FileAccess.get_sha256(base+suffix) if FileAccess.file_exists(base+suffix) else "MISSING"
	for chapter in range(1,7):
		var definition: Dictionary=Definitions.get_definition(chapter)
		var view:=SubViewport.new(); view.size=Vector2i(640,360)
		view.world_2d=World2D.new(); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var map: Node2D=definition.map.instantiate(); map.map_seed=521; view.add_child(map)
		for path in [definition.map.resource_path,map.get_script().resource_path,map.layout.get_script().resource_path,map.floor_view.get_script().resource_path]:
			sources[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
		var field: Node2D=map.get_node(FIELD_NAMES[chapter-1])
		var player:=Player.new(); map.add_child(player); player.set_physics_process(false); player.shield=0
		field.bind_player(player); field.set_active(true,1)
		var trap: Node2D=field.get_child(0)
		player.global_position=trap.global_position+Vector2(90,0)
		for child in field.get_children(): child.set_physics_process(false)
		var camera:=Camera2D.new(); camera.position=trap.global_position; view.add_child(camera); camera.make_current()
		var canvas:=CanvasLayer.new(); view.add_child(canvas)
		var label:=Label.new(); label.position=Vector2(16,14); label.add_theme_font_size_override("font_size",17)
		label.add_theme_color_override("font_color",Color("f3eddc")); label.add_theme_color_override("font_outline_color",Color("123b3b"))
		label.add_theme_constant_override("outline_size",5); canvas.add_child(label)
		check(trap.enabled and trap.health.current_health==80,"actual armed plate chapter%d"%chapter)
		samples.append({"chapter":chapter,"view":view,"player":player,"trap":trap,"label":label})
	await physics_frame; await process_frame
	await capture("待机")
	for sample in samples:
		sample.player.global_position=sample.trap.global_position+Vector2(36,0)
		sample.trap._physics_process(0.01); sample.trap._physics_process(0.25)
		sample.trap.take_damage(20)
		check(sample.trap.stage==sample.trap.Stage.WARNING and sample.player.health.current_health==100,"actual warning and no premature damage")
	await capture("预警")
	for sample in samples:
		sample.trap._physics_process(0.26)
		check(sample.trap.stage==sample.trap.Stage.COOLDOWN and sample.player.health.current_health==80,"real hit then cooldown")
	await capture("冷却")
	for sample in samples: sample.view.free()
	await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source unchanged "+path)
	for path in saved: check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING")==saved[path],"default save unchanged")
	var report:=FileAccess.open(OUTPUT.path_join("report.json"),FileAccess.WRITE)
	check(report!=null,"report writer")
	if report!=null:
		report.store_string(JSON.stringify({"valid":failures==0,"checks":checks,"renderer":RenderingServer.get_video_adapter_name(),"sources":sources,"captures":captures,"limits":["Six actual maps, cropped 640x360 views at unscaled actor size.","Controlled state clocks, no chapter victory or weapon acceptance."]},"\t")); report.close()
	if failures==0: print("TEST PASS: VerifyCampaignStepTraps %d"%checks)
	quit(1 if failures else 0)
