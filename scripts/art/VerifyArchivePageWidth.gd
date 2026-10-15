extends SceneTree
## Actual map, native Boss, locked warning and born projectile. Controlled clock;
## not a complete chapter, normal autonomous attack cycle, or human playtest.
const Boss = preload("res://scripts/actors/ArchiveArchivistBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Map = preload("res://scenes/world/luminous_archive.tscn")
const PaperTheme = preload("res://scripts/ui/CampaignMenuTheme.gd")
const OUTPUT := "res://build/diagnostics/campaign-endless-v1/archive-page-width-gpu-v2"
var assertions := 0
var failures := 0
var captures: Array[Dictionary] = []
var sources: Dictionary = {}
func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyArchivePageWidth "+message)
func _initialize() -> void: call_deferred("run")
func capture(view: SubViewport,caption: Label,state: String) -> void:
	caption.text = "第四关页刃 · %s · 半径10 / 弹速420 · 隔离攻击验证"%state
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	var file := OUTPUT.path_join(state+".png")
	check(pixels!=null and pixels.get_size()==view.size and pixels.save_png(file)==OK,"actual GPU frame "+state)
	captures.append({"path":file,"sha256":FileAccess.get_sha256(file),"state":state})
func run() -> void:
	check(DisplayServer.get_name()!="headless","real renderer required")
	check(not DirAccess.dir_exists_absolute(OUTPUT),"preserve earlier evidence")
	if failures: quit(1); return
	check(DirAccess.make_dir_recursive_absolute(OUTPUT)==OK,"new capture folder")
	for path in ["scripts/actors/ArchiveArchivistBoss.gd","scripts/components/ArchivePageProjectile.gd","scripts/components/SporeArchivistAttackDirector.gd","scripts/art/VerifyArchivePageWidth.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	var saved_before: Dictionary = {}
	for base in ["user://five_minute_overdrive_campaign_v1.json","user://five_minute_overdrive_journey_v1.json"]:
		for suffix in ["",".bak",".tmp"]:
			saved_before[base+suffix] = FileAccess.get_sha256(base+suffix) if FileAccess.file_exists(base+suffix) else "MISSING"
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var map := Map.instantiate()
	map.map_seed = 521
	view.add_child(map)
	var shots := Node2D.new()
	map.add_child(shots)
	var player := Player.new()
	player.world_bounds = map.layout.world_bounds
	player.position = map.layout.BOSS_CENTER+Vector2(250,0)
	map.add_child(player)
	player.set_physics_process(false)
	var camera := Camera2D.new()
	camera.position = Vector2(-125,0)
	player.add_child(camera)
	camera.make_current()
	var boss := Boss.new()
	boss.world_bounds = map.layout.world_bounds
	boss.position = map.layout.BOSS_CENTER
	boss.setup(4,shots,player)
	map.add_child(boss)
	boss.set_physics_process(false)
	var combat = boss.get_attack_director()
	combat.advance(1.4)
	boss._update_entrance_reveal()
	var layer := CanvasLayer.new()
	view.add_child(layer)
	var caption := Label.new()
	caption.theme = PaperTheme.create()
	caption.add_theme_color_override("font_color",Color("f3eddc"))
	caption.position = Vector2(24,24)
	layer.add_child(caption)
	await physics_frame
	await process_frame
	check(combat.start_action(&"page"),"actual warning armed")
	await capture(view,caption,"warning")
	for step in 30:
		if combat.action_stage==combat.Stage.ACTIVE: break
		combat.advance(1.0/60.0)
	check(combat.owned_projectiles.size()==1,"actual page birth")
	if combat.owned_projectiles.size()==1:
		var page: Node2D = combat.owned_projectiles[0]
		page.set_physics_process(false)
		check(page.radius==10 and page.sweep_shape.radius==10,"actual visual/sweep radius")
		await capture(view,caption,"release")
		page._physics_process(0.3)
		check(not page.is_queued_for_deletion(),"safe flight remains visible")
		check(page.global_position.distance_to(boss.global_position)>boss.body_radius+page.radius+10,"flight separates visibly from Boss body")
		await capture(view,caption,"flight")
	view.free()
	await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"capture source drift")
	for path in saved_before:
		check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING")==saved_before[path],"player save changed")
	var file := FileAccess.open(OUTPUT.path_join("report.json"),FileAccess.WRITE)
	check(file!=null,"report writer")
	if file!=null:
		file.store_string(JSON.stringify({"valid":failures==0,"assertions":assertions,"renderer":RenderingServer.get_video_adapter_name(),"sources":sources,"captures":captures,"limits":["Controlled real attack clock, not autonomous cycle or victory.","No campaign session/save executed."]},"\t"))
		file.close()
	if not failures: print("TEST PASS: VerifyArchivePageWidth %d"%assertions)
	quit(1 if failures else 0)
