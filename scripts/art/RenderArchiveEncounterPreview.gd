extends SceneTree
## Actual first encounter, ordinary input only after initial player placement.
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/ArchiveEncounterDirector.gd")
const Mote = preload("res://scripts/actors/SplittingMoteEnemy.gd")
const Planter = preload("res://scripts/actors/CapsulePlanterEnemy.gd")
const UI_THEME = preload("res://themes/MintFarmTheme.tres")
const Palette = preload("res://scripts/effects/HostileEffectPalette.gd")
var failures := 0
var checks := 0
var output: String
var captures: Array[Dictionary] = []
var warning_pixels := 0
var bar_pixels := 0
func visible_status(pixels: Image,actor: Node2D) -> bool:
	var top: Vector2 = actor.get_global_transform_with_canvas()*Vector2(0,actor.get_attack_marker_top())
	if not Rect2(8,86,1264,610).has_point(top): return false
	var cream := 0; var coral := 0
	for y in range(int(top.y)-13,int(top.y)-5):
		for x in range(int(top.x)-3,int(top.x)+4):
			if pixels.get_pixel(x,y).is_equal_approx(Palette.CREAM): cream += 1
	var bar: Rect2 = actor.get_health_bar_rect()
	var at: Vector2 = actor.get_global_transform_with_canvas()*bar.position
	if not Rect2(4,72,1272-bar.size.x,640-bar.size.y).has_point(at): return false
	for y in range(int(at.y)+1,int(at.y+bar.size.y)-1):
		for x in range(int(at.x)+1,int(at.x+bar.size.x)-1):
			if pixels.get_pixel(x,y).is_equal_approx(Palette.CORAL): coral += 1
	if cream<12 or coral<20: return false
	warning_pixels = cream; bar_pixels = coral; return true
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("ARCHIVE ENCOUNTER GPU FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func capture(view: SubViewport,name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	check(not pixels.is_empty() and pixels.save_png(output+name)==OK,"capture "+name)
	captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name)})
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh GPU output")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderArchiveEncounterPreview.gd","scripts/systems/ArchiveEncounterDirector.gd","scripts/systems/ChapterEncounterDirector.gd","scripts/systems/EncounterCombatCore.gd","scripts/actors/Player.gd","scripts/actors/Enemy.gd","scripts/actors/SplittingMoteEnemy.gd","scripts/actors/CapsulePlanterEnemy.gd","scripts/components/CapsulePlantHazard.gd","scripts/components/NativeFolioMotion.gd","scripts/components/NativeCapsulePlanterMotion.gd","scripts/world/ArchiveMap.gd","scripts/world/ArchiveSporeField.gd","scripts/world/ArchiveSporeNest.gd","scripts/world/ArchiveArenaLayout.gd","scripts/effects/EnemyWorldStatus.gd","scenes/world/luminous_archive.tscn","scenes/actors/native/splitting_mote_paper_v1.tscn","scenes/actors/native/capsule_planter_paper_v1.tscn"]:
		sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"source "+path)
	for path in ["scripts/campaign/ChapterRun.gd","scripts/components/NativeActorView.gd","scripts/components/NativeScrapperMotion.gd","scripts/components/NativeSporelingMotion.gd","assets/art/actors/native/splitting_mote_motion_v1.tres","assets/art/actors/native/capsule_planter_motion_v1.tres"]:
		sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"source "+path)
	var view := SubViewport.new(); view.size = Vector2i(1280,720); view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var host := Node2D.new(); host.process_mode = Node.PROCESS_MODE_PAUSABLE; view.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; map.add_child(player)
	map.layout.occlusion_target = player
	var camera := Camera2D.new(); player.add_child(camera)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new(); enemies.y_sort_enabled = true
	for layer in [enemies,shots,portals]: map.add_child(layer)
	player.projectile_parent = shots
	var friendly := {"shots":0}; player.fired.connect(func(shot: Node): shots.add_child(shot); friendly.shots += 1)
	var ui := CanvasLayer.new(); view.add_child(ui)
	var label := Label.new(); label.text = "菌光档案馆 / 分裂孢团与胶囊种植 · 第四关工程预览"
	label.position = Vector2(24,16); label.add_theme_font_override("font",UI_THEME.default_font); label.add_theme_font_size_override("font_size",22); ui.add_child(label)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director := Director.new(); host.add_child(director)
	check(director.bind_spore_field(map.spore_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"actual seeded encounter start")
	player.set_enemy_provider(director.get_attack_targets)
	# Initial spawn inside a genuine twin-exit chamber, before combat; never teleport mid-run.
	player.position = map.spore_field.get_sites()[0]+Vector2(0,120)
	check(map.layout.is_position_walkable(player.position,player.player_collision.shape.radius),"initial actual body clearance")
	await capture(view,"intro.png"); check(director.begin_encounter(),"begin")
	var seen := {"mote":false,"planter":false,"capsule":false,"fragment":false,"warning":false,"environment":false,"mote_walk":false,"planter_walk":false}
	var moves := 0; var pointers := 0; var max_pending := 0; var max_plants := 0
	var started := Time.get_ticks_msec(); var actions := ["move_up","move_right","move_down","move_left"]
	while Time.get_ticks_msec()-started<20000 and player.health.current_health>0 and director.state==director.State.COMBAT:
		# Small randomized-looking square in the clear central arena; no position/velocity writes.
		for action in actions: Input.action_release(action)
		Input.action_press(actions[int((Time.get_ticks_msec()-started)/560)%4])
		var closest: Node2D; var distance := INF
		for actor in director.get_active_enemies():
			var d: float = player.global_position.distance_squared_to(actor.global_position)
			if d<distance: closest = actor; distance = d
		if is_instance_valid(closest):
			var mouse := InputEventMouseMotion.new(); mouse.position = closest.get_global_transform_with_canvas().origin
			view.push_input(mouse); pointers += 1; Input.action_press("fire")
			check(player.get_global_mouse_position().distance_to(closest.global_position)<1,"engine pointer does not aim at real actor")
		else: Input.action_release("fire")
		var before := player.global_position
		await physics_frame; await process_frame
		moves += 1 if before.distance_to(player.global_position)>0.01 else 0
		max_pending = maxi(max_pending,director.pending_births.size())
		var plants := get_nodes_in_group(&"capsule_plants"); max_plants = maxi(max_plants,plants.size())
		for actor in director.get_active_enemies():
			check(actor.is_inside_tree() and actor.should_show_health_bar() and actor.native_visual!=null,"live native body and bar")
			if actor is Mote and not actor.is_fragment and not seen.mote: seen.mote = true; await capture(view,"mote.png")
			if actor is Mote and actor.native_visual.player.current_animation=="walk": seen.mote_walk = true
			if actor is Planter:
				check(actor.get_owned_plant_count()<=2,"owned capsule cap")
				if actor.native_visual.player.current_animation=="walk": seen.planter_walk = true
				if not seen.planter: seen.planter = true; await capture(view,"planter.png")
				if actor.ranged_is_winding_up and not seen.warning:
					await RenderingServer.frame_post_draw
					if visible_status(view.get_texture().get_image(),actor): seen.warning = true; await capture(view,"short-head-warning.png")
			if actor is Mote and actor.is_fragment and not seen.fragment: seen.fragment = true; await capture(view,"real-fragments.png")
		if not plants.is_empty() and not seen.capsule: seen.capsule = true; await capture(view,"live-capsule.png")
		for nest in map.spore_field.get_children():
			if nest.state==nest.State.ACTIVE and not seen.environment: seen.environment = true; await capture(view,"encounter-spore-active.png")
		if seen.values().all(func(v): return v) and moves>160 and friendly.shots>20: break
	for action in actions: Input.action_release(action)
	Input.action_release("fire")
	check(seen.values().all(func(v): return v) and moves>160 and friendly.shots>20 and pointers>100,"actual mixed actors/short cue/capsule/fragments/input missing "+str(seen))
	check(player.health.current_health>0 and director.state==director.State.COMBAT,"death or false clear")
	check(not director.finish_reward() and not director.begin_boss(),"living battle bypass")
	await capture(view,"mixed.png")
	paused = true; await physics_frame; await physics_frame
	check(map.spore_field.get_children().all(func(n): return n.state==n.State.INACTIVE),"pause environmental state")
	await capture(view,"paused.png"); paused = false
	var final_health: float = player.health.current_health
	host.free(); view.free(); await process_frame; await process_frame
	check(get_nodes_in_group(&"capsule_plants").is_empty(),"teardown retains hazard")
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed "+path)
	var report := {"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"observed":seen,"actual_adjacent_moves":moves,"owned_player_shots":friendly.shots,"engine_pointer_updates":pointers,"warning_cream_pixels":warning_pixels,"warning_actor_bar_coral_pixels":bar_pixels,"maximum_pending_births_observed":max_pending,"maximum_live_capsules_observed":max_plants,"final_player_health":final_health,"scope":"First actual archive encounter, initial spawn inside a real twin-exit chamber, seeded automatic portals/real AI/real shots/real descendant births. Only ordinary movement/fire input after initial spawn. No stats/health/pose/velocity edits. Not Boss/chapter completion/OS mouse/human playtest/performance/final art or six-chapter completion."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	if not failures: print("ARCHIVE ENCOUNTER GPU PASS: %d checks/%d actual moves/%d owned shots"%[checks,moves,friendly.shots])
	quit(1 if failures else 0)
