extends "res://scripts/art/VerifyNurseryChapterFlow.gd"
## Actual Main -> Foundry -> normal inputs -> real Boss clear -> unlock 3.
## Only prerequisite chapter-1 progress is prepared in an owned isolated file.
var layout_samples: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var health_events: Array[Dictionary] = []
var health_connected := false
var embedded_view: SubViewport
var pointer_checks := 0
func _initialize() -> void:
	var args := configure_chain_arguments(OS.get_cmdline_user_args())
	if not chain_context.valid or args.size() != 1 or not ChainEvidence.safe_id(args[0]):
		quit(1)
		return
	output = "res://build/diagnostics/campaign-goal/" + args[0] + "/"
	additional_sources = [
		"scripts/art/VerifyFoundryChapterFlow.gd", "scripts/campaign/FoundryChapter.gd",
		"scenes/campaign/foundry_chapter.tscn", "scripts/systems/ChapterEncounterDirector.gd",
		"scripts/systems/FoundryEncounterDirector.gd", "scripts/campaign/RegionalEnemyFactory.gd",
		"scripts/world/FoundryMap.gd", "scripts/world/FoundryArenaLayout.gd", "scripts/world/FoundryHeatField.gd",
		"scripts/world/FoundryHeatVent.gd", "scripts/world/FoundryPropArt.gd", "scripts/world/FoundryFloor.gd",
		"scripts/actors/EmberSparkEnemy.gd", "scripts/actors/FoundryFurnaceBoss.gd",
		"scripts/components/FurnaceForemanAttackDirector.gd", "scripts/components/NativeFurnaceForemanMotion.gd",
		"scripts/systems/BossCameraFraming.gd", "scripts/effects/PlayerOcclusionOutline.gd",
		"assets/art/actors/native/furnace_foreman_motion_v2.tres", "scenes/actors/native/furnace_foreman_paper_v2.tscn",
	]
	call_deferred("_run")
func chapter_number() -> int: return 2
func proof_marker() -> String: return "VerifyFoundryChapterFlow"
func scene_host() -> Node: return embedded_view
func actual_scene() -> Node: return embedded_view.get_child(0)
func prepare_scene_host() -> void:
	embedded_view = SubViewport.new()
	embedded_view.size = Vector2i(1280,720)
	embedded_view.world_2d = World2D.new()
	embedded_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(embedded_view)
	current_scene = embedded_view
	# Show the same GPU texture, but feed the game its own viewport coordinates.
	# No OS cursor placement, Player aim/stat mutation or substituted actor.
	var display := TextureRect.new()
	display.texture = embedded_view.get_texture()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(display)
func _inject_mouse(view: Viewport, point: Vector2) -> void:
	super._inject_mouse(view, point)
	pointer_checks += 1
	check(view == embedded_view and view.get_mouse_position().distance_to(point) < 0.001, "actual engine cursor differs from injected viewport coordinates")
func prepare_progress(path: String) -> bool:
	var prerequisite := Progress.new()
	return not FileAccess.file_exists(path) and prerequisite.record_boss_defeat(1) and Store.new(path).save_progress(prerequisite)
func proof_scope() -> String:
	return "Actual Main -> Foundry in a GPU SubViewport; standard engine pointer/button/direction/fire inputs -> actual Boss clear/save/unlock 3. Actual pointer coordinates checked every injection. Chapter-1 prerequisite prepared in isolated evidence save only. No actor stats/direct damage/in-run rewards modified. NOT OS desktop mouse acceptance, human playtest, performance or six-chapter completion."
func prepare_layout_capture(chapter: Node) -> void:
	for extent in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		embedded_view.size = extent
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		var path := output + "intro_%dx%d.png" % [extent.x,extent.y]
		var image := embedded_view.get_texture().get_image()
		check(image.save_png(path) == OK, "actual resized chapter frame failed")
		var panel: Rect2 = chapter.ui.flow_panel.get_global_rect()
		var viewport := Rect2(Vector2.ZERO, embedded_view.get_visible_rect().size)
		check(viewport.encloses(panel), "intro panel overflows actual viewport")
		check(panel.encloses(chapter.ui.return_button.get_global_rect()) and panel.encloses(chapter.ui.proceed_button.get_global_rect()), "intro actions overflow panel")
		layout_samples.append({"window_size":[extent.x,extent.y],"image_size":[image.get_width(),image.get_height()],"viewport_size":[viewport.size.x,viewport.size.y],"file":path,"sha256":FileAccess.get_sha256(path)})
	embedded_view.size = Vector2i(1280,720)
	for frame in 5: await process_frame
func additional_report() -> Dictionary:
	return {"layout_samples":layout_samples,"prerequisite_fixture":[1],"observations":observations,"health_events":health_events,"pointer_checks":pointer_checks}
func _capture(chapter: Node, step: int, label: String) -> void:
	await super._capture(chapter, step, label)
	if not health_connected:
		health_connected = true
		chapter.player.health_changed.connect(func(health: float, _maximum: float) -> void:
			var boss = chapter.director.get_active_boss()
			health_events.append({"frame":Engine.get_physics_frames(),"health":health,"boss_action":String(boss.attack_director.action) if boss != null else "","position":[chapter.player.position.x,chapter.player.position.y]})
			print("%s NORMAL HP: %.1f" % [proof_marker(),health])
		)
	var mouse: Vector2 = chapter.player.get_global_mouse_position()
	var boss = chapter.director.get_active_boss()
	observations.append({"step":step,"label":label,"facing":chapter.player.native_visual.facing,"gun_angle":chapter.player.gun_angle,"mouse_world":[mouse.x,mouse.y],"boss_position":[boss.position.x,boss.position.y] if boss != null else [],"attack":String(boss.attack_director.action) if boss != null else "","attack_stage":boss.attack_director.action_stage if boss != null else -1})
func pilot_motion(chapter: Node, policy: RefCounted, step: int, threats: Array[Vector2], _legacy: Node, danger_distance: float) -> Dictionary:
	var position: Vector2 = chapter.player.position
	var boss = chapter.director.get_active_boss()
	var attack: Node = boss.attack_director if boss != null else null
	var goal := Vector2.RIGHT.rotated(step / 180.0)
	if boss != null:
		var offset: Vector2 = position - boss.global_position
		goal = offset.normalized().orthogonal() + offset.normalized() * clampf((350 - offset.length()) / 80, -2, 2)
	# Same visible-loot policy as the native first-chapter input proof. Never
	# credit currency or health directly; normal Player collection owns both.
	var loot: Node2D = null
	var closest := INF
	for item: Node2D in chapter.pickups.get_children():
		if item.is_queued_for_deletion(): continue
		var script: String = item.get_script().resource_path
		var wanted: bool = chapter.director.state == chapter.director.State.COLLECT or (script.ends_with("HeartPickup.gd") and chapter.player.health.current_health < 80) or (script.ends_with("ShieldPickup.gd") and chapter.player.shield < chapter.player.max_shield)
		var distance := position.distance_squared_to(item.position)
		if wanted and distance < closest:
			closest = distance; loot = item
	if loot != null: goal = chapter.map.layout.get_navigation_direction(position,loot.position,chapter.player.get_body_radius())
	# Warning fields are threats, not terrain: a player at the locked vent center
	# must be allowed to move outward through its still-harmless warning.
	for vent in chapter.map.heat_field.get_children():
		if vent.state in [vent.State.WARNING,vent.State.ACTIVE]:
			threats.append(vent.global_position)
			danger_distance = minf(danger_distance, position.distance_to(vent.global_position))
	if attack != null and attack.action_stage in [attack.Stage.WARNING,attack.Stage.ACTIVE]:
		match attack.action:
			&"vents":
				for center: Vector2 in attack.vent_centers:
					threats.append(center)
					danger_distance = minf(danger_distance, position.distance_to(center))
			&"jet":
				for distance in [80.0,160.0,240.0]: threats.append(attack.locked_origin + attack.locked_direction * distance)
				var offset: Vector2 = position - attack.locked_origin
				if offset.length() < 292 and absf(attack.locked_direction.angle_to(offset)) < 0.52: danger_distance = 0
			&"ram":
				for distance in [80.0,160.0,240.0]: threats.append(boss.global_position + attack.locked_direction * distance)
				var offset: Vector2 = position - boss.global_position
				if offset.dot(attack.locked_direction) > -72 and offset.dot(attack.locked_direction) < 300 and absf(offset.dot(attack.locked_direction.orthogonal())) < 76: danger_distance = 0
	var direction: Vector2 = policy.choose_direction(position, goal, threats, func(point: Vector2) -> bool:
		return chapter.map.layout.is_position_walkable(point, chapter.player.get_body_radius())
	)
	return {"direction":direction,"dash":danger_distance < 100}
