extends SceneTree
## HEAD geometry versus current geometry using the same native art and seed.
## Baseline scripts live only in ignored diagnostics, never a runtime fallback.
const Definitions=preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Player=preload("res://scripts/actors/Player.gd")
const OUTPUT="res://build/diagnostics/campaign-goal/density-gpu-v2"
const BASELINE="res://build/diagnostics/campaign-goal/density-baseline-layouts-v1"
const NAMES=["NurseryArenaLayout","FoundryArenaLayout","SaltArenaLayout","ArchiveArenaLayout"]
const OLD_COUNTS=[17,17,10,24]
const OLD_AREAS=[352873.170898438,425225.137695313,863838.0,337064.0]
var checks:=0
var failures:=0
var sources: Dictionary={}
var captures: Array[Dictionary]=[]
var metrics: Array[Dictionary]=[]
var samples: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: VerifyCampaignDensity "+label)
func _initialize() -> void: call_deferred("run")
func sample(chapter: int,before: bool,overview: bool) -> Dictionary:
	var view:=SubViewport.new(); view.size=Vector2i(640,360) if overview else Vector2i(1280,720)
	view.world_2d=World2D.new(); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var definition: Dictionary=Definitions.get_definition(chapter)
	var map: Node2D=definition.map.instantiate(); map.map_seed=521
	if before: map.get_node("Layout").set_script(load(BASELINE.path_join(NAMES[chapter-1]+".gd")))
	view.add_child(map)
	var area:=0.0; var entries: Array=map.layout.get_obstacle_descriptors()
	for entry in entries: area+=Rect2(entry.rect).get_area()
	if before: check(entries.size()==OLD_COUNTS[chapter-1] and is_equal_approx(area,OLD_AREAS[chapter-1]),"HEAD baseline matches pre-change measured geometry")
	var camera:=Camera2D.new(); view.add_child(camera)
	if overview:
		var bounds: Rect2=map.layout.world_bounds
		var zoom:=minf(600/bounds.size.x,300/bounds.size.y)
		camera.zoom=Vector2.ONE*zoom; camera.position=bounds.get_center()-Vector2(0,20/zoom)
	else:
		var at:=Vector2.ZERO if chapter<4 else Vector2(map.layout.get_chambers()[0].get_center())
		var player:=Player.new(); player.position=map.layout.resolve_spawn_position(at,Player.BODY_RADIUS)
		view.add_child(player); player.set_physics_process(false); camera.position=player.position
		check(map.layout.is_position_walkable(player.position,Player.BODY_RADIUS),"native-scale player occupies real walkable space")
	camera.make_current()
	var layer:=CanvasLayer.new(); view.add_child(layer)
	var label:=Label.new(); label.position=Vector2(16,12); label.add_theme_font_size_override("font_size",17 if overview else 22)
	label.add_theme_color_override("font_color",Color("f3eddc")); label.add_theme_color_override("font_outline_color",Color("123b3b")); label.add_theme_constant_override("outline_size",5)
	label.text="第%d关 · %s · %d个实体"%[chapter,"调整前几何" if before else "加密后",entries.size()]; layer.add_child(label)
	for path in [definition.map.resource_path,map.get_script().resource_path,map.layout.get_script().resource_path,map.floor_view.get_script().resource_path]: sources[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
	if overview: metrics.append({"chapter":chapter,"baseline":before,"seed":521,"count":entries.size(),"area":area})
	return {"view":view,"chapter":chapter,"baseline":before}
func ready_pixels() -> void:
	await physics_frame; await process_frame; await process_frame; await RenderingServer.frame_post_draw
func run() -> void:
	check(DisplayServer.get_name()!="headless","real renderer required")
	check(not DirAccess.dir_exists_absolute(OUTPUT),"preserve all earlier captures")
	if failures: quit(1); return
	check(DirAccess.make_dir_recursive_absolute(OUTPUT)==OK,"fresh output folder")
	var saved: Dictionary={}
	for base in ["user://five_minute_overdrive_campaign_v1.json","user://five_minute_overdrive_journey_v1.json"]:
		for suffix in ["",".bak",".tmp"]: saved[base+suffix]=FileAccess.get_sha256(base+suffix) if FileAccess.file_exists(base+suffix) else "MISSING"
	for path in ["scripts/art/VerifyCampaignDensity.gd","scripts/world/ArenaLayout.gd","scripts/world/DestructibleObstacle.gd","scripts/world/ReusableTrapField.gd","scripts/actors/Player.gd"]: sources[path]=FileAccess.get_sha256("res://"+path)
	for chapter in range(1,5):
		for before in [true,false]: samples.append(sample(chapter,before,true))
	await ready_pixels()
	var montage:=Image.create(1280,1440,false,Image.FORMAT_RGBA8)
	for entry in samples:
		var pixels: Image=entry.view.get_texture().get_image(); pixels.convert(Image.FORMAT_RGBA8)
		check(pixels.get_size()==Vector2i(640,360),"real overview pixels")
		montage.blit_rect(pixels,Rect2i(0,0,640,360),Vector2i(0 if entry.baseline else 640,(entry.chapter-1)*360))
	var path:=OUTPUT.path_join("before-after.png"); check(montage.save_png(path)==OK,"save paired actual geometry")
	captures.append({"path":path,"sha256":FileAccess.get_sha256(path)})
	for entry in samples: entry.view.free()
	samples.clear(); await process_frame
	for chapter in range(1,5):
		var entry:=sample(chapter,false,false); await ready_pixels()
		var pixels: Image=entry.view.get_texture().get_image()
		path=OUTPUT.path_join("chapter%d-native.png"%chapter)
		check(pixels.get_size()==Vector2i(1280,720) and pixels.save_png(path)==OK,"current native-scale play-space crop")
		captures.append({"path":path,"sha256":FileAccess.get_sha256(path)})
		entry.view.free(); await process_frame
	for file in sources: check(FileAccess.get_sha256("res://"+file)==sources[file],"source unchanged "+file)
	for file in saved: check((FileAccess.get_sha256(file) if FileAccess.file_exists(file) else "MISSING")==saved[file],"default saves unchanged")
	var report:=FileAccess.open(OUTPUT.path_join("report.json"),FileAccess.WRITE); check(report!=null,"report writer")
	if report!=null:
		report.store_string(JSON.stringify({"valid":failures==0,"checks":checks,"baseline_revision":"125a67cd0ef1d71eb5812b04bc24cea42867d8ae","renderer":RenderingServer.get_video_adapter_name(),"rendering_arguments":OS.get_cmdline_args(),"sources":sources,"metrics":metrics,"captures":captures,"limits":["Overview is deliberately zoomed out; separate1280x720 crops use native scale.","Controlled map views, not movement, natural combat, or final EXE/FPS acceptance.","Baseline geometry from ignored HEAD script copies; common native art remains current."]},"\t")); report.close()
	if failures==0: print("TEST PASS: VerifyCampaignDensity %d"%checks)
	quit(1 if failures else 0)
