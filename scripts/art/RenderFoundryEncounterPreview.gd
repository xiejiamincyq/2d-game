extends SceneTree
## Actual automatic portal/AI clocks, ordinary moving Player, not full victory.
const Map = preload("res://scenes/world/ember_foundry.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/FoundryEncounterDirector.gd")
const Spark = preload("res://scripts/actors/EmberSparkEnemy.gd")
const Outline = preload("res://scripts/effects/PlayerOcclusionOutline.gd")
var failures := 0
var checks := 0
var output: String
var captures: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FOUNDRY ENCOUNTER GPU FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func capture(view: SubViewport,name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	check(not pixels.is_empty() and pixels.save_png(output+name)==OK,"actual capture "+name)
	captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name)})
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU/new folder")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderFoundryEncounterPreview.gd","scripts/systems/FoundryEncounterDirector.gd","scripts/systems/ChapterEncounterDirector.gd","scripts/systems/NurseryEncounterDirector.gd","scripts/systems/EncounterCombatCore.gd","scripts/campaign/RegionalEnemyFactory.gd","scripts/systems/UpgradeSystem.gd","scripts/world/FoundryHeatVent.gd","scripts/world/FoundryHeatField.gd","scripts/world/FoundryMap.gd","scripts/world/FoundryArenaLayout.gd","scripts/world/ArenaLayout.gd","scripts/world/FoundryFloor.gd","scripts/world/FoundryObstacle.gd","scripts/world/FoundryPropArt.gd","scenes/world/ember_foundry.tscn","scripts/actors/Player.gd","scripts/actors/Enemy.gd","scripts/actors/EmberSparkEnemy.gd","scripts/components/NativeActorView.gd","scripts/components/NativeCinderRunnerMotion.gd","scripts/components/NativeEmberSparkMotion.gd","scripts/components/CinderChargeAttack.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","scenes/actors/native/ember_spark_paper_v1.tscn","scenes/actors/native/cinder_runner_paper_v2.tscn","assets/art/actors/native/ember_spark_motion_v1.tres","assets/art/actors/native/cinder_runner_motion_v2.tres","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"source "+path)
	for path in ["scripts/effects/PlayerOcclusionOutline.gd","assets/art/shaders/player_native_outline.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"source "+path)
	var view := SubViewport.new(); view.size = Vector2i(1280,720)
	view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var host := Node2D.new(); host.process_mode = Node.PROCESS_MODE_PAUSABLE; view.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; map.add_child(player)
	map.layout.occlusion_target = player
	var camera := Camera2D.new(); player.add_child(camera)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	enemies.y_sort_enabled = true
	for layer in [enemies,shots,portals]: map.add_child(layer)
	shots.z_index = Outline.OUTLINE_Z_INDEX+1
	var outline := Outline.new(); player.add_child(outline); outline.setup(player,enemies,map.layout)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director := Director.new(); host.add_child(director)
	check(director.bind_heat_field(map.heat_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"actual second encounter")
	await capture(view,"intro.png")
	check(not map.heat_field.active and director.begin_encounter(),"intro safe, begin real portals")
	var observations := {"shots":0}
	shots.child_entered_tree.connect(func(_shot): observations.shots += 1)
	var warning := false; var charge := false; var fan := false
	var moves := 0
	var actions := ["move_up","move_right","move_down","move_left"]
	var started := Time.get_ticks_msec(); var action_index := -1
	while Time.get_ticks_msec()-started<10000 and player.health.current_health>0:
		var next := int((Time.get_ticks_msec()-started)/280)%4
		if next!=action_index:
			for action in actions: Input.action_release(action)
			Input.action_press(actions[next]); action_index = next
		var before := player.position
		await physics_frame; await process_frame
		moves += 1 if before.distance_to(player.position)>0.01 else 0
		for enemy in director.get_active_enemies():
			if enemy.kind==enemy.EnemyKind.DASHER:
				if enemy.charge_attack.stage==enemy.charge_attack.Stage.WARNING and not warning:
					warning = true; await capture(view,"charge-warning.png")
				if enemy.charge_attack.stage==enemy.charge_attack.Stage.ACTIVE and not charge:
					charge = true; await capture(view,"charge-active.png")
		if observations.shots>=3 and not fan:
			# Let the real three shots separate visibly; never reposition projectiles.
			for _frame in 9:
				var previous := player.position
				await physics_frame; await process_frame
				moves += 1 if previous.distance_to(player.position)>0.01 else 0
			fan = true; await capture(view,"spark-fan.png")
		if warning and charge and fan: break
	for action in actions: Input.action_release(action)
	check(warning and charge and fan and moves>30,"actual warnings/charge/fan/movement missing")
	check(player.health.current_health>0 and director.state==director.State.COMBAT,"fixture death/fake clearance")
	paused = true; await physics_frame; await physics_frame
	check(map.heat_field.get_children().all(func(vent): return vent.state==vent.State.INACTIVE),"pause cancels visible heat")
	await capture(view,"paused.png")
	paused = false; await physics_frame; await physics_frame
	check(map.heat_field.get_children().filter(func(vent): return vent.enabled).all(func(vent): return vent.remaining>1.3),"resume safety")
	host.free(); view.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed "+path)
	var report := {"passed":failures==0,"checks":checks,"captures":captures,"sources":sources,"actual_adjacent_moves":moves,"fan_shots_observed":observations.shots,"scope":"Actual first Foundry encounter automatic portals, two native families and heat, ordinary moving Player. No health/pose/velocity/collision mutation after spawn; not full chapter, rewards UI, Boss victory, performance, human playtest or final art."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	if not failures: print("FOUNDRY ENCOUNTER GPU PASS: %d checks/%d actual moves/%d shots"%[checks,moves,observations.shots])
	quit(1 if failures else 0)
