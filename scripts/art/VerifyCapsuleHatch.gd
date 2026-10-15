extends SceneTree
## Actual Archive actors and natural capsule physics; isolated encounter fixture,
## not a normal-input playthrough or a final packaged build.
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/ArchiveEncounterDirector.gd")
const Plant = preload("res://scripts/components/CapsulePlantHazard.gd")
const PaperTheme = preload("res://scripts/ui/CampaignMenuTheme.gd")
const OUTPUT := "res://build/diagnostics/campaign-endless-v1/capsule-hatch-gpu-v1"
var checks := 0
var failures := 0
var captures: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyCapsuleHatch " + label)
func _initialize() -> void: call_deferred("run")
func elapse(seconds: float) -> void:
	for step in ceili(seconds*Engine.physics_ticks_per_second): await physics_frame
	await process_frame
func capture(view: SubViewport,caption: Label,label: String,pod: Node2D = null) -> void:
	caption.text = "第四关孢囊 · %s · 3秒孵化 / 提前打碎阻止 · 隔离场景验证" % label
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	var path := OUTPUT.path_join(label+".png")
	check(pixels!=null and pixels.get_size()==view.size and pixels.save_png(path)==OK,"GPU capture " + label)
	if is_instance_valid(pod):
		var center: Vector2 = view.get_canvas_transform()*pod.global_position
		var spore_pixels := 0
		var amber_pixels := 0
		for y in range(maxi(0,int(center.y)-35),mini(view.size.y,int(center.y)+25)):
			for x in range(maxi(0,int(center.x)-20),mini(view.size.x,int(center.x)+20)):
				var color := pixels.get_pixel(x,y)
				if color.is_equal_approx(Color("93a16d")): spore_pixels += 1
				if color.is_equal_approx(Color("c4a166")): amber_pixels += 1
		check(spore_pixels>5,"actual incubation body is visible, not hidden behind floor")
		if pod.age>2: check(amber_pixels>8,"actual countdown has visible warm progress")
	captures.append({"path":path,"sha256":FileAccess.get_sha256(path)})
func run() -> void:
	check(DisplayServer.get_name()!="headless","real renderer required")
	check(not DirAccess.dir_exists_absolute(OUTPUT),"preserve earlier evidence")
	if failures: quit(1); return
	check(DirAccess.make_dir_recursive_absolute(OUTPUT)==OK,"new capture directory")
	var source_hashes: Dictionary = {}
	for path in ["scripts/components/CapsulePlantHazard.gd","scripts/actors/CapsulePlanterEnemy.gd","scripts/actors/SplittingMoteEnemy.gd","scripts/systems/ArchiveEncounterDirector.gd","scripts/systems/ChapterEncounterDirector.gd","scripts/art/VerifyCapsuleHatch.gd"]:
		source_hashes[path] = FileAccess.get_sha256("res://"+path)
	var saves: Dictionary = {}
	for base in ["user://five_minute_overdrive_campaign_v1.json","user://five_minute_overdrive_journey_v1.json"]:
		for suffix in ["",".bak",".tmp"]:
			saves[base+suffix] = FileAccess.get_sha256(base+suffix) if FileAccess.file_exists(base+suffix) else "MISSING"
	var view := SubViewport.new(); view.size = Vector2i(1280,720)
	view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var map := Map.instantiate(); map.map_seed = 521; view.add_child(map)
	var player := Player.new(); player.position = Vector2(240,0); player.world_bounds = map.layout.world_bounds
	map.add_child(player); player.set_physics_process(false)
	var camera := Camera2D.new(); camera.position = Vector2(-120,0)
	player.add_child(camera); camera.make_current()
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: map.add_child(layer)
	var growth := Growth.new(); map.add_child(growth); growth.setup(player)
	var director := Director.new(); map.add_child(director); director.set_process(false)
	check(director.bind_spore_field(map.spore_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"real director context")
	director.spawn_queue.clear(); check(director.begin_encounter(),"controlled combat fixture")
	director._spawn_enemy_at(director.EnemyScript.EnemyKind.SPITTER,Vector2.ZERO)
	var planter = director.get_active_enemies()[0]; planter.set_physics_process(false)
	var layer := CanvasLayer.new(); view.add_child(layer)
	var caption := Label.new(); caption.theme = PaperTheme.create()
	caption.add_theme_color_override("font_color",Color("f3eddc")); caption.position = Vector2(24,24); layer.add_child(caption)
	await physics_frame; await process_frame
	planter.shoot_cooldown = 0; planter._physics_process(0.01)
	for step in 120:
		if not planter.ranged_is_winding_up: break
		planter._physics_process(1.0/120.0)
	await process_frame; await physics_frame; await process_frame
	var pods: Array = shots.get_children().filter(func(node): return node is Plant and not node.resolved)
	check(pods.size()==1,"one actual landed pod")
	if pods.size()==1:
		var pod = pods[0]
		await capture(view,caption,"incubating",pod)
		await elapse(2.5)
		check(is_instance_valid(pod) and not pod.resolved,"pod survives before deadline")
		if is_instance_valid(pod): await capture(view,caption,"nearly-hatched",pod)
		await elapse(0.6)
		var children: Array = director.get_active_enemies().filter(func(node): return node.get("is_fragment")==true)
		check(children.size()==1 and not is_instance_valid(pod),"real admitted hatch, not a drawn replacement")
		if children.size()==1:
			check(children[0].native_visual!=null and children[0].should_show_health_bar(),"native hatchling and health bar")
			await capture(view,caption,"hatched")
	view.free(); await process_frame
	for path in source_hashes: check(FileAccess.get_sha256("res://"+path)==source_hashes[path],"source frozen through capture")
	for path in saves: check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING")==saves[path],"player save unchanged")
	var report := FileAccess.open(OUTPUT.path_join("report.json"),FileAccess.WRITE)
	check(report!=null,"report writer")
	if report!=null:
		report.store_string(JSON.stringify({"valid":failures==0,"checks":checks,"renderer":RenderingServer.get_video_adapter_name(),"sources":source_hashes,"captures":captures,"limits":["Controlled placement; naturally ticking three-second incubation.","No campaign/session save or normal-input victory."]},"\t")); report.close()
	if failures==0: print("TEST PASS: VerifyCapsuleHatch %d" % checks)
	quit(1 if failures else 0)
