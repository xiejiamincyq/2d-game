extends "EchoEncounterRuntimeTest.gd"
## Natural R3 mixed fight; shared capture helpers, not a whole-chapter victory claim.
const RiftMap = preload("res://scenes/world/rift_observatory.tscn")
const Cutter = preload("res://scripts/actors/SpaceCutterEnemy.gd")
const Elite = preload("res://scripts/actors/RiftEliteEnemy.gd")
const Shard = preload("res://scripts/components/RiftShardProjectile.gd")
var fault_field: Node2D
var cut_pixels := 0
var shard_pixels := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftEncounterRuntimeTest "+label)
func fault_pixels(pixels: Image) -> int:
	var count := 0
	for fault in fault_field.get_children():
		if fault.state!=fault.State.ACTIVE: continue
		var center: Vector2 = fault.get_global_transform_with_canvas()*fault.to_local(fault.get_current_center())
		for sector in 8:
			var at := center+Vector2.from_angle(TAU*sector/8)*12
			if Rect2(8,80,1264,632).has_point(at) and pixels.get_pixelv(Vector2i(at)).is_equal_approx(Color("b56e64")): count += 1
	return count
func live_cut_pixels(director: Node,pixels: Image) -> int:
	var count := 0
	for actor in director.get_active_enemies():
		if not actor is Cutter: continue
		var attack = actor.basic_attack
		if attack.stage!=attack.Stage.ACTIVE or not attack.line_resolved or attack.origin.distance_to(attack.line_end)<40: continue
		for fraction in [0.25,0.4,0.6,0.75]:
			var center: Vector2 = actor.get_global_transform_with_canvas()*actor.to_local(attack.origin.lerp(attack.line_end,fraction))
			for offset in [Vector2(-1,0),Vector2.ZERO,Vector2(1,0),Vector2(0,-1),Vector2(0,1)]:
				var at: Vector2 = center+offset
				if Rect2(8,80,1264,632).has_point(at) and pixels.get_pixelv(Vector2i(at)).is_equal_approx(Color("c6b7a0")): count += 1
	return count
func live_shard_pixels(shots: Node,pixels: Image) -> int:
	var count := 0
	for shot in shots.get_children():
		if not shot is Shard or shot.is_queued_for_deletion(): continue
		var center: Vector2 = shot.get_global_transform_with_canvas().origin
		for y in range(-3,4):
			for x in range(-3,4):
				var at := center+Vector2(x,y)
				if Rect2(8,80,1264,632).has_point(at) and pixels.get_pixelv(Vector2i(at)).is_equal_approx(Color("b5acc0")): count += 1
	return count
func run() -> void:
	check(ResourceLoader.exists("res://scripts/systems/RiftEncounterDirector.gd"),"actual sixth encounter authority missing")
	if failures: quit(1); return
	var args := OS.get_cmdline_user_args()
	if args.size()>1 or (args.size()==1 and not args[0].is_valid_identifier()): quit(1); return
	if args.size()==1:
		output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
		check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh actual GPU required")
		if failures: quit(1); return
		DirAccess.make_dir_recursive_absolute(output)
		for path in ["scripts/tests/RiftEncounterRuntimeTest.gd","scripts/tests/EchoEncounterRuntimeTest.gd","scripts/tests/EchoMovementTest.gd","scripts/tests/RiftEncounterPolicyTest.gd","scripts/tests/RiftEncounterTest.gd","scripts/systems/RiftEncounterDirector.gd","scripts/systems/ChapterEncounterDirector.gd","scripts/systems/WaveDirector.gd","scripts/campaign/RegionalEnemyFactory.gd","scripts/systems/UpgradeSystem.gd","scripts/actors/Player.gd","scripts/actors/Enemy.gd","scripts/actors/SpaceCutterEnemy.gd","scripts/actors/RiftEliteEnemy.gd","scripts/components/SpaceCutAttack.gd","scripts/components/EliteHybridAttack.gd","scripts/components/RiftShardProjectile.gd","scripts/components/NativeRiftEliteMotion.gd","scripts/components/NativeScrapperMotion.gd","scripts/effects/EnemyWorldStatus.gd","scripts/world/RiftMap.gd","scripts/world/RiftArenaLayout.gd","scripts/world/RiftFault.gd","scripts/world/RiftField.gd","scripts/world/RiftObstacle.gd","scripts/world/RiftPropArt.gd","scripts/world/RiftFloor.gd","scripts/world/TerrainSweep.gd","scenes/world/rift_observatory.tscn","scenes/actors/native/space_cutter_paper_v1.tscn","scenes/actors/native/rift_elite_paper_v1.tscn","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","themes/MintFarmTheme.tres"]:
			sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"source "+path)
	release()
	var view := SubViewport.new(); view.size = Vector2i(1280,720); view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var host := Node2D.new(); host.process_mode = Node.PROCESS_MODE_PAUSABLE; view.add_child(host)
	var map = RiftMap.instantiate(); map.map_seed = 521; host.add_child(map); fault_field = map.rift_field
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; player.position = fault_field.get_sites()[0]+Vector2(0,80); host.add_child(player)
	map.layout.occlusion_target = player; var camera := Camera2D.new(); player.add_child(camera)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new(); enemies.y_sort_enabled = true
	for layer in [enemies,shots,portals]: host.add_child(layer)
	player.projectile_parent = shots; var fired := [0]; player.fired.connect(func(shot): shots.add_child(shot); fired[0] += 1)
	if not output.is_empty():
		var ui := CanvasLayer.new(); view.add_child(ui); var title := Label.new()
		title.text = "裂隙观测站 / 真实混合遭遇 · 普通方向与射击（非通关证明）"; title.position = Vector2(24,16)
		title.add_theme_font_override("font",UI_THEME.default_font); title.add_theme_font_size_override("font_size",22); ui.add_child(title)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director = load("res://scripts/systems/RiftEncounterDirector.gd").new(); host.add_child(director)
	await physics_frame; await process_frame
	check(director.bind_rift_field(fault_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"automatic current owner run refused")
	player.set_enemy_provider(director.get_attack_targets)
	await capture(view,"intro.png"); check(director.begin_encounter(),"actual first encounter cannot start")
	var seen := {"cutter_walk":false,"elite_walk":false,"cutter_warning":false,"elite_warning":false,"cutter_cut":false,"elite_shards":false,"fault_warning":false,"fault_active":false}
	var taken := {}; var moves := 0; var pointers := 0; var maximum := 0; var shards := 0
	var rng := RandomNumberGenerator.new(); rng.seed = 7021
	var target: Vector2 = player.position; var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<16000 and player.health.current_health>0 and director.state==director.State.COMBAT:
		if player.position.distance_to(target)<14:
			for _attempt in 20:
				var candidate: Vector2 = fault_field.get_sites()[0]+Vector2(rng.randf_range(-220,220),rng.randf_range(-220,220))
				if map.layout.is_position_walkable(candidate,player.get_body_radius()): target = candidate; break
		var direction: Vector2 = map.layout.get_navigation_direction(player.position,target,player.get_body_radius()); release()
		for axis in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
			if axis[1]>0: Input.action_press(axis[0],axis[1])
		var nearest: Node2D; var distance := INF
		for actor in director.get_active_enemies():
			var d: float = player.global_position.distance_squared_to(actor.global_position)
			if d<distance: nearest = actor; distance = d
		if is_instance_valid(nearest):
			var mouse := InputEventMouseMotion.new(); mouse.position = nearest.get_global_transform_with_canvas().origin; view.push_input(mouse); pointers += 1
			check(player.get_global_mouse_position().distance_to(nearest.global_position)<1,"real engine pointer does not aim at target")
			Input.action_press("fire")
		var before := player.position; await physics_frame; await process_frame
		if player.position.distance_to(before)>0.01: moves += 1
		check(Clearance.has_clearance(player.position,map.layout.world_bounds,map.layout.get_obstacle_descriptors(),player.get_body_radius()),"ordinary full circle embeds equipment")
		maximum = maxi(maximum,director.get_active_enemies().size())
		for actor in director.get_active_enemies():
			check(actor.native_visual!=null and actor.should_show_health_bar() and (actor is Cutter or actor is Elite),"actual family/full healthbar absent")
			var family := "cutter" if actor is Cutter else "elite"
			if actor.native_visual.player.current_animation=="walk": seen[family+"_walk"] = true
			var attack = actor.basic_attack
			if attack.stage==attack.Stage.WARNING: seen[family+"_warning"] = true
			if actor is Cutter and attack.stage==attack.Stage.ACTIVE and attack.line_resolved and attack.origin.distance_to(attack.line_end)>10: seen.cutter_cut = true
			if not output.is_empty() and not taken.has(family) and Rect2(80,100,1120,540).has_point(actor.get_global_transform_with_canvas().origin): taken[family] = true; await capture(view,family+".png")
			if attack.stage==attack.Stage.WARNING and not taken.has("head"):
				if not output.is_empty(): await RenderingServer.frame_post_draw
				if is_instance_valid(actor) and status_pixels(view,actor):
					taken.head = true
					if not output.is_empty(): save_capture(view.get_texture().get_image(),"short-head-warning.png")
		for shot in shots.get_children():
			if shot is Shard and not shot.is_queued_for_deletion():
				seen.elite_shards = true; shards += 1
		for fault in fault_field.get_children():
			if fault.state==fault.State.WARNING: seen.fault_warning = true
			if fault.state==fault.State.ACTIVE:
				seen.fault_active = true
				if not taken.has("fault"):
					if output.is_empty(): taken.fault = true
					else:
						await RenderingServer.frame_post_draw
						var pixels := view.get_texture().get_image(); var count := fault_pixels(pixels)
						if count>=3: beat_pixels = count; taken.fault = true; save_capture(pixels,"encounter-fault.png")
		if not output.is_empty() and (not taken.has("cut") or not taken.has("shards")):
			await RenderingServer.frame_post_draw
			var pixels := view.get_texture().get_image()
			if not taken.has("cut"):
				var count := live_cut_pixels(director,pixels)
				if count>=4: cut_pixels = count; taken.cut = true; save_capture(pixels,"locked-line-cut.png")
			if not taken.has("shards"):
				var count := live_shard_pixels(shots,pixels)
				if count>=4: shard_pixels = count; taken.shards = true; save_capture(pixels,"native-elite-shards.png")
		var effect_captures := output.is_empty() or (taken.has("cut") and taken.has("shards") and taken.has("cutter") and taken.has("elite"))
		if seen.values().all(func(v): return v) and moves>180 and fired[0]>6 and taken.has("head") and taken.has("fault") and effect_captures: break
	release()
	check(seen.values().all(func(v): return v) and moves>180 and fired[0]>6 and pointers>100 and maximum>=8 and taken.has("head") and taken.has("fault"),"natural mixed actions/input/density missing "+str(seen))
	if not output.is_empty():
		check(beat_pixels>=3,"live fault capture has no current visible disk pixels")
		check(cut_pixels>=4 and shard_pixels>=4 and taken.has("cutter") and taken.has("elite"),"actual native attacks/family captures missing")
	check(player.health.current_health>0 and director.state==director.State.COMBAT and is_equal_approx(player.move_speed,235) and is_equal_approx(player.get_body_radius(),16.9) and not player.is_stealthed(),"witness dead or artificial movement")
	check(not director.finish_reward() and not director.begin_boss(),"living first battle bypasses or spawns unmade Boss")
	await capture(view,"mixed.png")
	var health: float = player.health.current_health+player.shield
	paused = true; await physics_frame; await physics_frame; await create_timer(0.12,true).timeout
	check(player.health.current_health+player.shield==health and fault_field.get_children().all(func(n): return n.state==n.State.INACTIVE),"actual pause leaves damage active")
	await capture(view,"paused.png"); paused = false; await physics_frame; await physics_frame
	check(fault_field.get_children().filter(func(n): return n.enabled).all(func(n): return n.state==n.State.COOLDOWN and n.remaining>4.1),"resume lacks safe staggered recovery")
	var final_health: float = player.health.current_health; host.free(); view.free(); await process_frame; await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	if not output.is_empty():
		var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"observed":seen,"actual_adjacent_moves":moves,"engine_pointer_updates":pointers,"owned_player_shots":fired[0],"maximum_live_enemies":maximum,"shard_body_samples":shards,"warning_cream_pixels":warning_pixels,"bar_coral_pixels":bar_pixels,"current_fault_coral_pixels":beat_pixels,"locked_cut_positive_pixels":cut_pixels,"native_shard_positive_pixels":shard_pixels,"final_player_health":final_health,"scope":"Actual first seeded sixth-region natural clocks/AI/movement and fire. No post-spawn position, stats, pose, velocity or attack-clock writes. Not whole encounter clear/Boss/chapter victory, OS/human playtest, dense performance or six-chapter completion."},"\t")); file.close()
	print("RIFT ENCOUNTER OBSERVED: moves=%d shots=%d pointer=%d max_live=%d health=%s"%[moves,fired[0],pointers,maximum,final_health])
	if not failures: print("TEST PASS: RiftEncounterRuntimeTest %d"%checks)
	quit(1 if failures else 0)
