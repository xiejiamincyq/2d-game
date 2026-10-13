extends SceneTree
## Actual maps/actors and the production combat clock. Controlled GPU poses only.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Chain = preload("res://scripts/art/CampaignChainEvidence.gd")
const Player = preload("res://scripts/actors/Player.gd")
const ACTORS := [preload("res://scripts/actors/NurseryVineBoss.gd"),preload("res://scripts/actors/FoundryFurnaceBoss.gd"),preload("res://scripts/actors/SaltTideBoss.gd"),preload("res://scripts/actors/ArchiveArchivistBoss.gd"),preload("res://scripts/actors/EchoBellPriestBoss.gd"),preload("res://scripts/actors/RiftObserverBoss.gd")]
var checks := 0
var failed := false
var output := ""
var captures := {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failed = true; push_error("BOSS FAIRNESS GPU FAIL: "+label)
func step(boss: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); boss._physics_process(dt); remaining -= dt
func capture(viewport: SubViewport,name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	check(pixels.save_png(output+name+".png")==OK,"write "+name)
	captures[name] = FileAccess.get_sha256(output+name+".png")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh GPU output required")
	if failed: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := Chain.build_source_bank()
	check(not sources.is_empty(),"canonical source bank absent")
	for path in ["scripts/art/RenderBossFairnessWarnings.gd","scripts/components/BossEscapeGate.gd","scripts/campaign/ChapterRunDefinitions.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	for chapter in range(1,7):
		var viewport := SubViewport.new(); viewport.size = Vector2i(1280,720)
		viewport.world_2d = World2D.new(); viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var definition := Definitions.get_definition(chapter)
		var map = definition.map.instantiate(); map.map_seed = 521; viewport.add_child(map)
		var at: Vector2 = map.layout.BOSS_CENTER
		var player := Player.new(); player.position = at+Vector2(150,0)
		player.world_bounds = map.layout.world_bounds; viewport.add_child(player); player.set_physics_process(false)
		var shots := Node2D.new(); viewport.add_child(shots)
		var boss = ACTORS[chapter-1].new(); boss.position = at
		boss.setup(chapter,shots,player); boss.world_bounds = map.layout.world_bounds
		viewport.add_child(boss); boss.set_physics_process(false)
		await physics_frame; await physics_frame
		viewport.canvas_transform = Transform2D(0,Vector2(580,360)-at)
		step(boss,1.41); boss._update_entrance_reveal()
		var combat = boss.get_attack_director(); combat.attack_gap = 99
		var path: String = combat.get_script().resource_path.trim_prefix("res://")
		sources[path] = FileAccess.get_sha256("res://"+path)
		for action in combat.DURATIONS:
			if action==&"brood": continue # Finite summons, no direct-damage footprint.
			combat.cancel_action(); await process_frame
			player.health.current_health = 100; player.health.invulnerable_time = 0; player.position = at+Vector2(150,0)
			check(combat.start_action(action),"map%s cannot admit %s" % [chapter,action])
			if not combat.is_attacking(): continue
			step(boss,combat.DURATIONS[action][0]*0.65)
			check(combat.action_stage==combat.Stage.WARNING and player.health.current_health==100,"visible warning damaged or canceled %s/%s" % [chapter,action])
			await capture(viewport,"chapter%d-%s-warning" % [chapter,action])
			if action in [&"roots",&"vents",&"ripple",&"pincer",&"beam"]:
				step(boss,combat.DURATIONS[action][0]*0.35+0.025)
				await capture(viewport,"chapter%d-%s-active" % [chapter,action])
		viewport.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"checks":checks,"captures":captures,"sources":sources,"scope":"1280x720 actual six maps seed521, native Boss/Player, controlled authoritative warnings and selected active geometry. No human or ordinary-victory claim."},"\t")); file.close()
	if not failed: print("TEST PASS: RenderBossFairnessWarnings %s" % checks)
	quit(1 if failed else 0)
