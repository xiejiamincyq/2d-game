extends SceneTree
## GPU witness of automatic salt portals/AI/tides and ordinary moving Player.
const Map = preload("res://scenes/world/salt_waterway.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/SaltEncounterDirector.gd")
const Crab = preload("res://scripts/actors/FlankingCrabEnemy.gd")
const Outline = preload("res://scripts/effects/PlayerOcclusionOutline.gd")
const UI_THEME = preload("res://themes/MintFarmTheme.tres")
const Palette = preload("res://scripts/effects/HostileEffectPalette.gd")
var checks := 0
var failures := 0
var output: String
var captures: Array[Dictionary] = []
func aim_and_fire(view: SubViewport,player: Node2D,director: Node) -> void:
	var closest: Node2D
	var distance := INF
	for enemy in director.get_active_enemies():
		var candidate: float = player.global_position.distance_squared_to(enemy.global_position)
		if candidate<distance: closest = enemy; distance = candidate
	if is_instance_valid(closest):
		var mouse := InputEventMouseMotion.new(); mouse.position = closest.get_global_transform_with_canvas().origin
		view.push_input(mouse); Input.action_press("fire")
	else: Input.action_release("fire")
func observe_shot(shot: Node,observations: Dictionary) -> void:
	if is_instance_valid(shot) and shot.get("target_group")==&"player": observations.shots += 1
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("SALT ENCOUNTER GPU FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func capture(view: SubViewport,name: String) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	check(not pixels.is_empty() and pixels.save_png(output+name)==OK,"capture "+name)
	captures.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name)})
	return pixels
func needle_pixels(pixels: Image,shots: Node,enemies: Node) -> int:
	var count := 0
	for shot in shots.get_children():
		if shot.target_group!=&"player" or shot.radius!=3: continue
		var point: Vector2 = shot.get_global_transform_with_canvas().origin
		if not Rect2(8,72,1264,640).has_point(point): continue
		if enemies.get_children().any(func(enemy): return enemy.global_position.distance_to(shot.global_position)<60): continue
		for y in range(int(point.y)-4,int(point.y)+5):
			for x in range(int(point.x)-4,int(point.x)+5):
				var color := pixels.get_pixel(x,y)
				if color.a>0.99 and color.r>0.8 and color.g>0.25 and color.g<0.65 and color.b<0.4: count += 1
	return count
func tide_pixels(pixels: Image,field: Node,enemies: Node,player: Node2D) -> int:
	var count := 0
	for band in field.get_children():
		if band.state!=band.State.ACTIVE: continue
		var origin: Vector2 = band.get_global_transform_with_canvas().origin
		var bounds: Rect2 = Rect2(origin+band.footprint.position,band.footprint.size).intersection(Rect2(0,72,1280,648))
		if not bounds.has_area(): continue
		for y in range(ceili(bounds.position.y),floori(bounds.end.y)):
			for x in range(ceili(bounds.position.x),floori(bounds.end.x)):
				var point := Vector2(x,y)
				if point.distance_to(player.get_global_transform_with_canvas().origin)<70: continue
				if enemies.get_children().any(func(enemy): return point.distance_to(enemy.get_global_transform_with_canvas().origin)<75): continue
				var color := pixels.get_pixel(x,y)
				if color.a>0.99 and Vector3(color.r,color.g,color.b).distance_squared_to(Vector3(0.388,0.537,0.568))<0.002: count += 1
	return count
func status_pixels(pixels: Image,actor: Node2D) -> Dictionary:
	var cream := 0; var coral := 0
	var top: Vector2 = actor.get_global_transform_with_canvas()*Vector2(0,actor.get_attack_marker_top())
	if Rect2(4,14,1272,704).has_point(top):
		for y in range(int(top.y)-13,int(top.y)-5):
			for x in range(int(top.x)-3,int(top.x)+4):
				if pixels.get_pixel(x,y).is_equal_approx(Palette.CREAM): cream += 1
	var bar: Rect2 = actor.get_health_bar_rect()
	var origin: Vector2 = actor.get_global_transform_with_canvas()*bar.position
	if Rect2(4,1,1272-bar.size.x,714).has_point(origin):
		for y in range(int(origin.y)+1,int(origin.y+bar.size.y)-1):
			for x in range(int(origin.x)+1,int(origin.x+bar.size.x)-1):
				if pixels.get_pixel(x,y).is_equal_approx(Palette.CORAL): coral += 1
	return {"head":cream,"bar":coral,"head_footprint":Rect2(top+Vector2(-3.5,-14),Vector2(7,17)),"bar_footprint":Rect2(origin,bar.size)}
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU and fresh output")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/effects/EnemyWorldStatus.gd","scripts/effects/HostileAttackDrawing.gd","scripts/effects/HostileEffectPalette.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"status source "+path)
	for path in ["scripts/art/RenderSaltEncounterPreview.gd","scripts/systems/SaltEncounterDirector.gd","scripts/systems/ChapterEncounterDirector.gd","scripts/systems/NurseryEncounterDirector.gd","scripts/systems/FoundryEncounterDirector.gd","scripts/systems/WaveDirector.gd","scripts/campaign/RegionalEnemyFactory.gd","scripts/systems/UpgradeSystem.gd","scripts/world/SaltTidalBand.gd","scripts/world/SaltTidalField.gd","scripts/world/SaltMap.gd","scripts/world/SaltArenaLayout.gd","scripts/world/ArenaLayout.gd","scripts/world/SaltFloor.gd","scripts/world/SaltObstacle.gd","scripts/world/SaltPropArt.gd","scenes/world/salt_waterway.tscn","scripts/actors/Player.gd","scripts/actors/Enemy.gd","scripts/actors/FlankingCrabEnemy.gd","scripts/components/NativeActorView.gd","scripts/components/NativeFolioMotion.gd","scripts/components/NativeNeedlerMotion.gd","scripts/components/CrabPincerAttack.gd","scripts/components/ScrapperAttack.gd","scripts/components/Projectile.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","scenes/actors/native/flanking_crab_paper_v1.tscn","scenes/actors/native/salt_needler_paper_v1.tscn","assets/art/actors/native/flanking_crab_motion_v1.tres","assets/art/actors/native/salt_needler_motion_v1.tres","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres","scripts/effects/PlayerOcclusionOutline.gd","assets/art/shaders/player_native_outline.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"source "+path)
	var view := SubViewport.new(); view.size = Vector2i(1280,720)
	view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var host := Node2D.new(); host.process_mode = Node.PROCESS_MODE_PAUSABLE; view.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; map.add_child(player)
	map.layout.occlusion_target = player
	var camera := Camera2D.new(); player.add_child(camera)
	var mouse := InputEventMouseMotion.new(); mouse.position = Vector2(840,360); view.push_input(mouse)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	enemies.y_sort_enabled = true
	for layer in [enemies,shots,portals]: map.add_child(layer)
	# Match the real ChapterRun ownership contract: fired transfers a new node to
	# its listener. Without this connection, standalone Player volleys orphan nodes.
	player.projectile_parent = shots
	var friendly := {"owned":0}
	player.fired.connect(func(shot: Node): shots.add_child(shot); friendly.owned += 1)
	shots.z_index = Outline.OUTLINE_Z_INDEX+1
	var outline := Outline.new(); player.add_child(outline); outline.setup(player,enemies,map.layout)
	var ui := CanvasLayer.new(); view.add_child(ui)
	var label := Label.new(); label.text = "盐蚀水道 / 两族真实遭遇与潮带 · 工程预览，第三关尚未开放"
	label.position = Vector2(24,16); label.add_theme_font_override("font",UI_THEME.default_font)
	label.add_theme_font_size_override("font_size",22); label.add_theme_color_override("font_color",Color("e3d4b3")); ui.add_child(label)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director := Director.new(); host.add_child(director)
	check(director.bind_tidal_field(map.tidal_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"actual salt encounter")
	await capture(view,"intro.png")
	check(not map.tidal_field.active and director.begin_encounter(),"intro safe and real portal start")
	var observations := {"shots":0}; shots.child_entered_tree.connect(func(shot): observe_shot.call_deferred(shot,observations))
	var warning := false; var claw := false; var aimed := false; var tide := false; var flight := false
	var moves := 0; var shot_pixels := 0; var visible_tide_pixels := 0
	var pincer_status := {}; var needler_status := {}
	var label_rect: Rect2 = label.get_global_rect()
	var actions := ["move_up","move_right","move_down","move_left"]
	var started := Time.get_ticks_msec(); var action_index := -1
	while Time.get_ticks_msec()-started<12000 and player.health.current_health>0:
		var next := int((Time.get_ticks_msec()-started)/280)%4
		if next!=action_index:
			for action in actions: Input.action_release(action)
			Input.action_press(actions[next]); action_index = next
		var before := player.position
		await physics_frame; await process_frame
		moves += 1 if before.distance_to(player.position)>0.01 else 0
		for enemy in director.get_active_enemies():
			if enemy is Crab:
				if enemy.basic_attack.stage==enemy.basic_attack.Stage.WARNING and not warning:
					var pixels: Image = await capture(view,"pincer-warning.png")
					pincer_status = status_pixels(pixels,enemy)
					check(pincer_status.head>=14 and pincer_status.bar>=60,"actual pincer head and hostile bar pixels")
					check(not pincer_status.head_footprint.intersects(label_rect) and not pincer_status.bar_footprint.intersects(label_rect),"pincer status overlaps preview label")
					warning = true
				if enemy.basic_attack.stage==enemy.basic_attack.Stage.ACTIVE and not claw:
					claw = true; await capture(view,"pincer-active.png")
			elif enemy.ranged_is_winding_up and not aimed:
				var pixels: Image = await capture(view,"needle-warning.png")
				needler_status = status_pixels(pixels,enemy)
				check(needler_status.head>=14 and needler_status.bar>=60,"actual needler head and hostile bar pixels")
				check(not needler_status.head_footprint.intersects(label_rect) and not needler_status.bar_footprint.intersects(label_rect),"needler status overlaps preview label")
				aimed = true
		if not flight and not shots.get_children().is_empty():
			await RenderingServer.frame_post_draw
			var pixels := view.get_texture().get_image()
			shot_pixels = needle_pixels(pixels,shots,enemies)
			if shot_pixels>2:
				flight = true
				check(pixels.save_png(output+"needle-flight.png")==OK,"visible needle capture")
				captures.append({"path":output+"needle-flight.png","sha256":FileAccess.get_sha256(output+"needle-flight.png")})
		if warning and claw and aimed and flight: break
	# Walk from the real origin, around the sluice walls, onto the safe side of
	# an enabled causeway. Never move the camera or actor by a pose/position write.
	var area: Rect2 = map.tidal_field.get_sites()[0]
	var center := area.get_center()
	var vertical := area.size.x<area.size.y
	var destination := center+(Vector2.RIGHT if vertical else Vector2.DOWN)*75
	var waypoints: Array[Vector2] = []
	if vertical: waypoints.assign([Vector2(0,signf(center.y)*180),Vector2(destination.x,signf(center.y)*180),destination])
	else: waypoints.assign([Vector2(0,destination.y),destination])
	var route_started := Time.get_ticks_msec(); var route_moves := 0
	var circle := CircleShape2D.new(); circle.radius = 12.5
	var query := PhysicsShapeQueryParameters2D.new(); query.shape = circle; query.collision_mask = 1
	query.collide_with_areas = false; query.exclude = [player.get_rid()]
	var conservative_rejections := 0
	while not waypoints.is_empty() and Time.get_ticks_msec()-route_started<14000 and player.health.current_health>0:
		var delta: Vector2 = waypoints[0]-player.position
		if delta.length()<8: waypoints.pop_front(); continue
		var direction := delta.normalized()
		for action in actions: Input.action_release(action)
		Input.action_press("move_right",maxf(direction.x,0)); Input.action_press("move_left",maxf(-direction.x,0))
		Input.action_press("move_down",maxf(direction.y,0)); Input.action_press("move_up",maxf(-direction.y,0))
		aim_and_fire(view,player,director)
		var previous := player.position
		await physics_frame; await process_frame
		route_moves += 1 if player.position.distance_to(previous)>0.01 else 0
		query.transform = Transform2D(0,player.global_position)
		var overlaps := player.get_world_2d().direct_space_state.intersect_shape(query,1)
		if not map.layout.is_position_walkable(player.position,12.5):
			conservative_rejections += 1
			print("Salt route conservative rejection position=%s actual_circle_overlaps=%d"%[player.position,overlaps.size()])
		check(map.layout.is_position_walkable(player.position,12.5),"causeway input walkability rejection at %s circle_overlaps=%s"%[player.position,overlaps.size()])
	for action in actions: Input.action_release(action)
	check(waypoints.is_empty() and route_moves>100,"normal movement did not reach visible causeway")
	moves += route_moves
	var visible_started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-visible_started<3500 and player.health.current_health>0:
		aim_and_fire(view,player,director)
		await physics_frame; await process_frame
		await RenderingServer.frame_post_draw
		var pixels := view.get_texture().get_image()
		visible_tide_pixels = tide_pixels(pixels,map.tidal_field,enemies,player)
		if visible_tide_pixels>300:
			tide = true
			check(pixels.save_png(output+"tidal-active.png")==OK,"visible live tide capture")
			captures.append({"path":output+"tidal-active.png","sha256":FileAccess.get_sha256(output+"tidal-active.png")})
			break
	Input.action_release("fire")
	check(tide and visible_tide_pixels>300,"active tide has no independent visible viewport pixels")
	check(friendly.owned>5,"ordinary firing has no owned real player projectiles")
	for action in actions: Input.action_release(action)
	check(warning and claw and aimed and tide and flight and shot_pixels>2 and moves>30,"actual attacks/tide/independent needle pixels/movement missing")
	check(player.health.current_health>0 and director.state==director.State.COMBAT,"death or false victory")
	check(not director.finish_reward() and not director.choose_route(&"supply"),"living combat bypasses reward")
	paused = true; await physics_frame; await physics_frame
	check(map.tidal_field.get_children().all(func(band): return band.state==band.State.INACTIVE),"paused live tide")
	await capture(view,"paused.png")
	paused = false; await physics_frame; await physics_frame
	check(map.tidal_field.get_children().filter(func(band): return band.enabled).all(func(band): return band.remaining>1.6),"resume safe cooldown")
	host.free(); view.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed "+path)
	var report := {"passed":failures==0,"checks":checks,"captures":captures,"sources":sources,"actual_adjacent_moves":moves,"causeway_adjacent_moves":route_moves,"owned_player_shots":friendly.owned,"conservative_walkability_rejections":conservative_rejections,"needle_shots_observed":observations.shots,"independent_needle_pixels":shot_pixels,"independent_tide_pixels":visible_tide_pixels,"pincer_status_pixels":pincer_status,"needler_status_pixels":needler_status,"scope":"Actual first Salt encounter automatic portals, native pincer/needle AI, encounter-owned tide and ordinary moving/firing Player walking from origin to a causeway. No health/pose/velocity/collision mutation after spawn. Not chapter entry/reward UI/Boss victory/OS mouse/human playtest/performance/final art or six-chapter completion."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	if not failures: print("SALT ENCOUNTER GPU PASS: %d checks/%d actual moves/%d shots/%d needle pixels"%[checks,moves,observations.shots,shot_pixels])
	quit(1 if failures else 0)
