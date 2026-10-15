extends SceneTree
## One natural first encounter. Optional GPU capture is explicit, never a victory claim.
const Map = preload("res://scenes/world/echo_court.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/EchoEncounterDirector.gd")
const Sentinel = preload("res://scripts/actors/EchoSentinelEnemy.gd")
const Shade = preload("res://scripts/actors/CirclingShadeEnemy.gd")
const Clearance = preload("EchoMovementTest.gd")
const UI_THEME = preload("res://themes/MintFarmTheme.tres")
const Palette = preload("res://scripts/effects/HostileEffectPalette.gd")
const Plate = preload("res://scripts/world/ReusableStepTrap.gd")
var checks := 0
var failures := 0
var output := ""
var captures: Array[Dictionary] = []
var sources := {}
var warning_pixels := 0
var bar_pixels := 0
var beat_field: Node2D
var beat_pixels := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoEncounterRuntimeTest "+label)
func _initialize() -> void: call_deferred("run")
func release() -> void:
	for action in ["move_left","move_right","move_up","move_down","fire","dash_melee"]: Input.action_release(action)
func capture(view: SubViewport,name: String) -> void:
	if output.is_empty(): return
	await process_frame; await RenderingServer.frame_post_draw
	save_capture(view.get_texture().get_image(),name)
func save_capture(pixels: Image,name: String) -> void:
	check(not pixels.is_empty() and pixels.save_png(output+name)==OK,"actual GPU capture "+name)
	captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name)})
func pulse_pixels(_view: SubViewport,pixels: Image) -> int:
	return pressure_plate_pixels(beat_field,pixels)

func pressure_plate_pixels(field: Node2D,pixels: Image) -> int:
	var count := 0
	for plate in field.get_children():
		if plate.stage!=Plate.Stage.WARNING: continue
		var center: Vector2 = plate.get_global_transform_with_canvas().origin
		for sector in 8:
			var at: Vector2 = center+Vector2.from_angle(TAU*sector/8)*plate.trigger_radius
			for y in range(-2,3):
				for x in range(-2,3):
					var sample_at:=at+Vector2(x,y)
					if not Rect2(8,80,1264,632).has_point(sample_at): continue
					var color:=pixels.get_pixelv(Vector2i(sample_at))
					if color.r>0.75 and color.g>0.25 and color.g<0.65 and color.b<0.5: count+=1
	return count

func pressure_plate_start(field: Node2D,layout: Node2D,radius: float) -> Vector2:
	var at: Vector2=field.get_sites()[0]
	for offset in [Vector2(0,80),Vector2(80,0),Vector2(0,-80),Vector2(-80,0)]:
		var clear_path:=true
		for step in range(9):
			if not layout.is_position_walkable(at+offset*step/8.0,radius): clear_path=false; break
		if clear_path: return at+offset
	return at # Legal initial spawn; no post-spawn teleport or immunity.

func pressure_plate_snapshot(field: Node2D) -> Dictionary:
	var state: Dictionary={}
	for plate in field.get_children():
		if plate.is_queued_for_deletion(): continue
		state[plate.get_instance_id()]={"stage":plate.stage,"elapsed":plate.elapsed,"hp":plate.health.current_health}
	return state

func verify_pressure_plate_pause(view: SubViewport,field: Node2D,player: Node2D) -> void:
	var health: float=player.health.current_health+player.shield
	var before:=pressure_plate_snapshot(field)
	check(not before.is_empty(),"real pressure plate ownership remains")
	paused=true; await physics_frame; await physics_frame; await create_timer(0.12,true).timeout
	check(player.health.current_health+player.shield==health and pressure_plate_snapshot(field)==before,"pause freezes existing stages, timers, HP and IDs without resetting danger")
	await capture(view,"paused.png")
	paused=false; await physics_frame; await process_frame
	var after:=pressure_plate_snapshot(field)
	var continued:=true
	var limit:=4.0/Engine.physics_ticks_per_second
	for id in after:
		if not before.has(id): continued=false; continue
		continued=continued and after[id].hp<=before[id].hp
		if before[id].stage==Plate.Stage.WARNING: continued=continued and after[id].stage in [Plate.Stage.WARNING,Plate.Stage.COOLDOWN]
		if before[id].stage==Plate.Stage.COOLDOWN and before[id].elapsed+limit<Plate.COOLDOWN_SECONDS:
			continued=continued and after[id].stage==Plate.Stage.COOLDOWN and after[id].elapsed>=before[id].elapsed and after[id].elapsed-before[id].elapsed<=limit
	check(continued,"resume continues existing pressure plates, not old periodic reset or replenishment")
func status_pixels(view: SubViewport,actor: Node2D) -> bool:
	if output.is_empty(): return true
	var top: Vector2 = actor.get_global_transform_with_canvas()*Vector2(0,actor.get_attack_marker_top())
	var area: Rect2 = actor.get_health_bar_rect(); var at: Vector2 = actor.get_global_transform_with_canvas()*area.position
	if not Rect2(8,80,1264,620).has_point(top) or not Rect2(4,72,1272-area.size.x,640-area.size.y).has_point(at): return false
	var pixels := view.get_texture().get_image(); var cream := 0; var coral := 0
	for y in range(int(top.y)-13,int(top.y)-5):
		for x in range(int(top.x)-3,int(top.x)+4):
			if pixels.get_pixel(x,y).is_equal_approx(Palette.CREAM): cream += 1
	for y in range(int(at.y)+1,int(at.y+area.size.y)-1):
		for x in range(int(at.x)+1,int(at.x+area.size.x)-1):
			if pixels.get_pixel(x,y).is_equal_approx(Palette.CORAL): coral += 1
	if cream<12 or coral<20: return false
	warning_pixels = cream; bar_pixels = coral; return true
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()>1 or (args.size()==1 and not args[0].is_valid_identifier()): quit(1); return
	if args.size()==1:
		output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
		check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh real GPU directory")
		if failures: quit(1); return
		DirAccess.make_dir_recursive_absolute(output)
		for path in ["scripts/world/TerrainSweep.gd","scripts/tests/EchoBeatEntitySeparationTest.gd"]:
			sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"source "+path)
		for path in ["scripts/tests/EchoEncounterRuntimeTest.gd","scripts/tests/EchoMovementTest.gd","scripts/tests/EchoEncounterPolicyTest.gd","scripts/tests/EchoEncounterTest.gd","scripts/systems/EchoEncounterDirector.gd","scripts/systems/ChapterEncounterDirector.gd","scripts/systems/EncounterCombatCore.gd","scripts/campaign/RegionalEnemyFactory.gd","scripts/systems/UpgradeSystem.gd","scripts/actors/Player.gd","scripts/actors/Enemy.gd","scripts/actors/EchoSentinelEnemy.gd","scripts/actors/CirclingShadeEnemy.gd","scripts/components/EchoRingAttack.gd","scripts/components/ShadeAmbushAttack.gd","scripts/effects/EnemyWorldStatus.gd","scripts/components/NativeActorView.gd","scripts/components/NativeScrapperMotion.gd","scripts/world/EchoMap.gd","scripts/world/EchoArenaLayout.gd","scripts/world/ReusableStepTrap.gd","scripts/world/ReusableTrapField.gd","scenes/world/echo_court.tscn","scenes/actors/native/echo_sentinel_paper_v1.tscn","scenes/actors/native/circling_shade_paper_v1.tscn"]:
			sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"source "+path)
	release()
	var view := SubViewport.new(); view.size = Vector2i(1280,720); view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var host := Node2D.new(); host.process_mode = Node.PROCESS_MODE_PAUSABLE; view.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	beat_field = map.echo_field
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; player.position = pressure_plate_start(map.echo_field,map.layout,player.get_body_radius()); host.add_child(player)
	var plate_escape: Vector2=player.position
	map.layout.occlusion_target = player; var camera := Camera2D.new(); player.add_child(camera)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new(); enemies.y_sort_enabled = true
	for layer in [enemies,shots,portals]: host.add_child(layer)
	player.projectile_parent = shots; var fired := [0]; player.fired.connect(func(shot): shots.add_child(shot); fired[0] += 1)
	if not output.is_empty():
		var ui := CanvasLayer.new(); view.add_child(ui); var title := Label.new()
		title.text = "回声墓庭 / 真实首场混合遭遇 · 普通方向与射击输入（非通关证明）"; title.position = Vector2(24,16)
		title.add_theme_font_override("font",UI_THEME.default_font); title.add_theme_font_size_override("font_size",22); ui.add_child(title)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director := Director.new(); host.add_child(director)
	await physics_frame; await process_frame
	check(director.bind_echo_field(map.echo_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"automatic actual owner run")
	player.set_enemy_provider(director.get_attack_targets)
	await capture(view,"intro.png"); check(director.begin_encounter(),"actual encounter start")
	var seen := {"sentinel_walk":false,"shade_walk":false,"sentinel_warning":false,"sentinel_ring":false,"shade_warning":false,"shade_strike":false,"plate_warning":false,"plate_cooldown":false}
	var taken := {}; var moves := 0; var pointers := 0; var maximum := 0
	var rng := RandomNumberGenerator.new(); rng.seed = 7021
	var target: Vector2 = player.position; var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<12000 and player.health.current_health>0 and director.state==director.State.COMBAT:
		if player.position.distance_to(target)<14:
			for _attempt in 20:
				var candidate: Vector2 = map.echo_field.get_sites()[0]+Vector2(rng.randf_range(-220,220),rng.randf_range(-220,220))
				if map.layout.is_position_walkable(candidate,player.get_body_radius()): target = candidate; break
		var direction: Vector2 = map.layout.get_navigation_direction(player.position,target,player.get_body_radius())
		if not seen.plate_warning: direction=map.layout.get_navigation_direction(player.position,beat_field.get_sites()[0],player.get_body_radius())
		elif not seen.plate_cooldown: direction=map.layout.get_navigation_direction(player.position,plate_escape,player.get_body_radius())
		release()
		for axis in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
			if axis[1]>0: Input.action_press(axis[0],axis[1])
		var nearest: Node2D; var distance := INF
		for actor in director.get_active_enemies():
			var d: float = player.global_position.distance_squared_to(actor.global_position)
			if d<distance: nearest = actor; distance = d
		if is_instance_valid(nearest):
			var mouse := InputEventMouseMotion.new(); mouse.position = nearest.get_global_transform_with_canvas().origin; view.push_input(mouse); pointers += 1
			check(player.get_global_mouse_position().distance_to(nearest.global_position)<1,"engine cursor fails real aim")
			if seen.plate_cooldown: Input.action_press("fire") # Observe actual stepping before shooting the plate.
		var before := player.position; await physics_frame; await process_frame
		if player.position.distance_to(before)>0.01: moves += 1
		check(Clearance.has_clearance(player.position,map.layout.world_bounds,map.layout.get_obstacle_descriptors(),player.get_body_radius()),"actual full body embeds in pillar")
		maximum = maxi(maximum,director.get_active_enemies().size())
		for actor in director.get_active_enemies():
			check(actor.native_visual!=null and actor.should_show_health_bar(),"actual family/status absent")
			var family := "sentinel" if actor is Sentinel else "shade"
			if actor.native_visual.player.current_animation=="walk": seen[family+"_walk"] = true
			var attack = actor.basic_attack
			if attack.stage==attack.Stage.WARNING: seen[family+"_warning"] = true
			if actor is Sentinel and attack.is_ring_visible(): seen.sentinel_ring = true
			if actor is Shade and attack.stage==attack.Stage.ACTIVE: seen.shade_strike = true
			if not output.is_empty() and not taken.has(family) and Rect2(80,100,1120,540).has_point(actor.get_global_transform_with_canvas().origin): taken[family] = true; await capture(view,family+".png")
			if attack.stage==attack.Stage.WARNING and not taken.has("head"):
				if not output.is_empty(): await RenderingServer.frame_post_draw
				if is_instance_valid(actor) and status_pixels(view,actor):
					taken.head = true
					if not output.is_empty(): save_capture(view.get_texture().get_image(),"short-head-warning.png")
		for beat in map.echo_field.get_children():
			if beat.stage==Plate.Stage.COOLDOWN: seen.plate_cooldown=true
			if beat.stage==Plate.Stage.WARNING:
				seen.plate_warning = true
				if not taken.has("beat"):
					if output.is_empty(): taken.beat = true
					else:
						await RenderingServer.frame_post_draw
						var pixels := view.get_texture().get_image(); var count := pulse_pixels(view,pixels)
						if count>=3: beat_pixels = count; taken.beat = true; save_capture(pixels,"encounter-pressure-plate-warning.png")
		if seen.values().all(func(v): return v) and moves>180 and fired[0]>6 and taken.has("head") and taken.has("beat"): break
	release()
	check(seen.values().all(func(v): return v) and moves>180 and fired[0]>6 and pointers>100 and maximum>=8 and taken.has("beat"),"natural mixed actions/input/density missing "+str(seen))
	if not output.is_empty(): check(beat_pixels>=3,"claimed live pressure plate warning capture has no current coral rim")
	check(player.health.current_health>0 and director.state==director.State.COMBAT and is_equal_approx(player.move_speed,235) and not player.is_stealthed(),"witness dead or artificial actor motion")
	check(not director.finish_reward() and not director.begin_boss(),"living first fight bypass")
	await capture(view,"mixed.png")
	await verify_pressure_plate_pause(view,map.echo_field,player)
	var final_health: float = player.health.current_health; host.free(); view.free(); await process_frame; await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed "+path)
	if not output.is_empty():
		var report := {"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"observed":seen,"actual_adjacent_moves":moves,"engine_pointer_updates":pointers,"owned_player_shots":fired[0],"maximum_live_enemies":maximum,"warning_cream_pixels":warning_pixels,"bar_coral_pixels":bar_pixels,"pressure_plate_warning_coral_pixels":beat_pixels,"final_player_health":final_health,"scope":"First actual seeded fifth-region encounter and actual AI/ordinary movement/fire, no post-spawn position/stat/pose/velocity/clock writes. Not Boss/chapter victory, OS input, human playtest, dense performance or six-chapter completion."}
		var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("ECHO ENCOUNTER OBSERVED: moves=%d shots=%d pointer=%d max_live=%d health=%s"%[moves,fired[0],pointers,maximum,final_health])
	if not failures: print("TEST PASS: EchoEncounterRuntimeTest %d"%checks)
	quit(1 if failures else 0)
