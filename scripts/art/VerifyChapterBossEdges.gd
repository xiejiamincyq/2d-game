extends SceneTree
## GPU controlled Chapter 1/6 evidence, NOT ordinary combat or human acceptance.
## Real Main/Chapter/UI/reward/Boss/health/entrance/save/Return lifecycles. Explicit
## fixtures: prerequisite progress, accelerated encounter clocks/lethal damage,
## frozen actor physics and edge poses, deterministic camera-solver steps.
const MainScene = preload("res://scenes/Main.tscn")
const Snapshot = preload("res://scripts/systems/RunSnapshotStore.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Evidence = preload("res://scripts/art/CampaignChainEvidence.gd")
const Support = preload("res://scripts/tests/TestSupport.gd")
const Framing = preload("res://scripts/systems/BossCameraFraming.gd")
const SIZES := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]
const EDGES := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
var assertions := 0
var failures := 0
var output := ""
var view: SubViewport
var clear_probe: SubViewport
var sources := {}
var samples: Array[Dictionary] = []
var fixtures: Array[Dictionary] = []
var clear_pixel := Color()
var prior_time_scale := 1.0

func check(ok: bool, message: String) -> bool:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyChapterBossEdges " + message)
	return ok

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not Evidence.safe_id(args[0]):
		push_error("VerifyChapterBossEdges requires one unique safe runid")
		quit(1)
		return
	output = Evidence.EVIDENCE_ROOT + args[0] + "/"
	if DisplayServer.get_name() == "headless" or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output.trim_suffix("/")):
		push_error("VerifyChapterBossEdges requires GPU rendering and a never-used evidence directory")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("VerifyChapterBossEdges cannot create owned evidence directory")
		quit(1)
		return
	prior_time_scale = Engine.time_scale
	call_deferred("run_checks")

func run_checks() -> void:
	sources = Evidence.build_source_bank()
	check(not sources.is_empty(), "source bank unavailable")
	for number in [1, 6]:
		for size in SIZES:
			if failures > 0: break
			await run_fixture(number, size)
			await cleanup_view()
	await cleanup_view()
	check(Evidence.source_bank_matches(sources), "source changed during controlled GPU proof")
	check(samples.size() == 162, "incomplete capture matrix: expected 144 phase edges + 6 entrance + 6 clear + 6 Return")
	var file := FileAccess.open(output + "report.json", FileAccess.WRITE)
	check(file != null, "cannot write report")
	var report := {"valid": failures == 0, "assertions": assertions, "process_id": OS.get_process_id(), "engine": Engine.get_version_info(), "renderer": RenderingServer.get_video_adapter_name(), "sources": sources, "fixtures": fixtures, "samples": samples,
		"scope": "Controlled actual Main/Chapter 1 and 6, three GPU viewport sizes, eight edge/corner poses at actual health phases 1/2/3, natural Boss entrance, accepted fixture damage clear/save and actual Return button. Actors are frozen and repositioned; camera uses production BossCameraFraming with controlled solver steps. Chapter 6 prerequisites 1-5 are Progress API fixtures. Backdrop/lifecycle acceptance only: actor screen rects and both_fit are observations, not complete actor-framing acceptance. Health phases do not verify attack animation phases. Not ordinary combat/victory, six-leg campaign, human visual approval or dynamic performance proof. Modal clear and returned Main captures are lifecycle records, not off-map pixel acceptance. Entrance off-map pixel checks are conditional on actual exposure; phase-edge cases require exposure."}
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.flush()
		if file.get_error() != OK:
			failures += 1
			push_error("TEST FAIL: VerifyChapterBossEdges report write failed; on-disk report is not acceptance evidence")
		file.close()
	Engine.time_scale = prior_time_scale
	if failures == 0: print("TEST PASS: VerifyChapterBossEdges %d" % assertions)
	quit(1 if failures else 0)

func run_fixture(number: int, size: Vector2i) -> void:
	var label := "chapter%d_%dx%d" % [number, size.x, size.y]
	var campaign_path := output + label + "_campaign.json"
	var snapshot_path := output + label + "_snapshot.json"
	var prerequisite := Progress.new()
	for previous in range(1, number):
		if not check(prerequisite.record_boss_defeat(previous), label + " prerequisite fixture rejected"): return
	if number > 1 and not check(Store.new(campaign_path).save_progress(prerequisite), label + " cannot save owned prerequisite fixture"): return
	view = SubViewport.new()
	view.size = size
	view.world_2d = World2D.new()
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Includes the later Return-created Main, before either Main executes _ready.
	view.child_entered_tree.connect(func(scene: Node) -> void:
		if scene.get_script() != null and scene.get_script().resource_path == "res://scripts/Main.gd":
			scene.child_entered_tree.connect(func(child: Node) -> void:
				if child is Snapshot: child.save_path = snapshot_path))
	root.add_child(view)
	var main := MainScene.instantiate()
	main.campaign_store_path = campaign_path
	main.audio_enabled = false
	# Real _ready still runs. Configure its newly attached snapshot store BEFORE
	# Main consults it; never inspect, clear or overwrite a user's wave snapshot.
	view.add_child(main)
	await process_frame
	if not check(main.snapshot_store.save_path == snapshot_path and main.campaign_storage_ok and not main.run_started, label + " actual isolated Main cover unavailable"): return
	clear_probe = SubViewport.new()
	clear_probe.size = Vector2i(2, 2)
	clear_probe.world_2d = World2D.new()
	clear_probe.disable_3d = true
	clear_probe.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(clear_probe)
	await RenderingServer.frame_post_draw
	clear_pixel = clear_probe.get_texture().get_image().get_pixel(0, 0)
	clear_probe.queue_free()
	clear_probe = null
	seed(20261012 + number)
	if not await press(main.ui.start_screen.start_button): return
	var chapter := await wait_scene(false)
	if not check(chapter != null and chapter.has_method("_chapter_number"), label + " Main did not launch actual chapter"): return
	if not check(chapter._chapter_number() == number and chapter.campaign_store_path == campaign_path, label + " wrong actual chapter/path"): return
	if not check(chapter.player != null and chapter.director != null and chapter.framing.get_script() == Framing, label + " actual player/director/camera rig absent"): return
	if not check(chapter.player.get_visual_node().scene_file_path.ends_with("player_paper_v1.tscn"), label + " player is not production native actor"): return
	if not await wait_player_entrance(chapter): return
	for encounter in 2:
		if not await controlled_encounter(chapter): return
	if not await press(chapter.ui.supply_button): return
	if not check(Support.claim_chapter_finale(chapter), label + " actual finale reward transaction failed"): return
	if not check(chapter.director.state == chapter.director.State.BOSS_READY, label + " finale did not expose real Boss gate"): return
	var bounds: Rect2 = chapter.map.layout.world_bounds
	var player_at := edge_pose(chapter, EDGES[4], chapter.player.get_body_radius())
	if not check(player_at.is_finite(), label + " no clear controlled corner position"): return
	chapter.player.global_position = player_at
	if not await press(chapter.ui.proceed_button): return
	var boss: Node = chapter.director.get_active_boss()
	if not check(is_instance_valid(boss) and chapter.director.state == chapter.director.State.BOSS and chapter.framing.boss == boss, label + " actual Boss spawn/framing binding failed"): return
	if not check(not boss.entrance_resolved, label + " entrance capture missed actual entrance"): return
	var entrance_boss_at := clear_pose(chapter, player_at + player_at.direction_to(bounds.get_center()) * 240.0, boss.body_radius)
	if not check(entrance_boss_at.is_finite(), label + " no Boss corner pose"): return
	boss.global_position = entrance_boss_at
	await capture(chapter, boss, label + "_entrance", true, false)
	var deadline := Time.get_ticks_msec() + 8000
	while not boss.entrance_resolved and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(boss.entrance_resolved, label + " actual Boss entrance did not finish"): return
	boss.set_physics_process(false)
	chapter.player.set_physics_process(false)
	chapter.director.set_process(false)
	chapter.framing.set_process(false)
	for phase in [1, 2, 3]:
		if phase > 1:
			var target_ratio := 0.60 if phase == 2 else 0.25
			boss.take_damage(boss.health.current_health - boss.health.max_health * target_ratio, &"controlled_camera_fixture")
			if not check(boss.get_phase() == phase and not boss.death_resolved, label + " real health transition failed"): return
		for edge in EDGES.size():
			var at := edge_pose(chapter, EDGES[edge], chapter.player.get_body_radius())
			var boss_at := clear_pose(chapter, at + at.direction_to(bounds.get_center()) * 240.0, boss.body_radius)
			if not check(at.is_finite() and boss_at.is_finite(), label + " controlled edge pose unavailable"): return
			chapter.player.global_position = at
			boss.global_position = boss_at
			# Production solver and viewport transform, not an invented zoom/camera.
			for step in 120: chapter.framing.step_framing(1.0 / 60.0)
			await capture(chapter, boss, label + "_phase%d_edge%d" % [phase, edge], true)
			if failures > 0: return
	var chapter_id := chapter.get_instance_id()
	var rig_id: int = chapter.framing.get_instance_id()
	if not check(boss.take_damage(1e9, &"controlled_camera_fixture"), label + " controlled actual Boss death rejected"): return
	await process_frame
	await process_frame
	if not check(chapter.clear_saved and chapter.director.state == chapter.director.State.CLEARED, label + " controlled Boss did not reach real saved clear"): return
	var saved := Progress.new()
	if not check(Store.new(campaign_path).load_progress(saved) == Store.LoadResult.LOADED and saved.has_cleared(number), label + " owned clear receipt missing"): return
	var saved_sha := FileAccess.get_sha256(campaign_path)
	await capture(chapter, null, label + "_cleared", false)
	if not await press(chapter.ui.return_button): return
	var returned := await wait_scene(true)
	if not check(returned != null, label + " actual Return did not reach Main"): return
	# Destination enters before Chapter._leave queues the old scene for deletion.
	await process_frame
	await process_frame
	check(returned.snapshot_store.save_path == snapshot_path, label + " returned Main did not retain isolated snapshot configuration")
	if not check(not is_instance_id_valid(chapter_id) and not is_instance_id_valid(rig_id), label + " departing Chapter/camera rig retained"): return
	check(returned.campaign_store_path == campaign_path and returned.campaign_progress.to_state() == saved.to_state() and FileAccess.get_sha256(campaign_path) == saved_sha, label + " actual Return changed owned permanent progress")
	await RenderingServer.frame_post_draw
	var return_path := output + label + "_returned_main.png"
	check(view.get_texture().get_image().save_png(return_path) == OK, label + " returned Main capture failed")
	samples.append({"label": label + "_returned_main", "file": return_path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(return_path), "viewport": xy(Vector2(view.size)), "pixel_check": "not applicable: returned cover, no Chapter world", "chapter_and_rig_released": not is_instance_id_valid(chapter_id) and not is_instance_id_valid(rig_id)})
	fixtures.append({"chapter": number, "viewport": xy(Vector2(size)), "prerequisite_fixture": prerequisite.to_state(), "campaign_file": campaign_path.trim_prefix("res://"), "saved_state": saved.to_state(), "saved_sha256": saved_sha, "used_controlled_damage": true, "used_controlled_poses": true, "used_button_signals_not_pointer": true})

func controlled_encounter(chapter: Node) -> bool:
	if not await press(chapter.ui.proceed_button): return false
	if not check(chapter.director.state == chapter.director.State.COMBAT, "actual encounter UI did not start combat"): return false
	chapter.director.set_process(false)
	chapter.player.set_physics_process(false)
	for step in 160:
		chapter.director._process(0.25) # Explicit accelerated fixture clock.
		if chapter.director.spawn_queue.is_empty() and chapter.director.active_portals.is_empty(): break
	var enemies: Array = chapter.director.get_active_enemies().duplicate()
	if not check(not enemies.is_empty() and chapter.director.spawn_queue.is_empty() and chapter.director.active_portals.is_empty(), "controlled real encounter did not finish spawning"): return false
	for enemy in enemies:
		enemy.set_physics_process(false)
		enemy.take_damage(1e9, &"controlled_camera_fixture")
	await process_frame
	await process_frame
	chapter.director._process(0.0)
	chapter.director._process(3.1)
	if not check(chapter.director.state == chapter.director.State.REWARD and chapter.ui.settlement_screen.visible, "real cleared actors did not create reward gate"): return false
	var selected: Button = null
	for button: Button in chapter.ui.settlement_screen.offer_buttons:
		if button.is_visible_in_tree() and not button.disabled:
			selected = button
			break
	if not check(selected != null, "real reward has no available offer"): return false
	if not await press(selected): return false
	if not check(chapter.growth.get_settlement_state().reward_claimed, "real reward transaction did not commit"): return false
	return await press(chapter.ui.settlement_screen.close_button)

func wait_player_entrance(chapter: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while chapter.player.is_entrance_active() and Time.get_ticks_msec() < deadline:
		await process_frame
	return check(not chapter.player.is_entrance_active(), "actual player entrance timeout")

func press(button: Button) -> bool:
	if not check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "actual UI button unavailable"): return false
	button.pressed.emit()
	await process_frame
	return true

func wait_scene(want_main: bool) -> Node:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		for node in view.get_children():
			if node.is_queued_for_deletion() or node.get_script() == null: continue
			if want_main and node.get_script().resource_path == "res://scripts/Main.gd": return node
			if not want_main and node.has_method("_chapter_number"): return node
		await process_frame
	return null

func edge_pose(chapter: Node, direction: Vector2, radius: float) -> Vector2:
	var rect: Rect2 = chapter.map.layout.world_bounds.grow(-radius - 12.0)
	return clear_pose(chapter, rect.get_center() + direction * rect.size * 0.5, radius)

func clear_pose(chapter: Node, desired: Vector2, radius: float) -> Vector2:
	for distance in [0.0, 64.0, 128.0, 192.0]:
		for direction in EDGES:
			var point: Vector2 = desired + direction.normalized() * distance
			if chapter.map.layout.is_position_walkable(point, radius): return point
	return Vector2.INF

func capture(chapter: Node, boss: Node, label: String, pixel_gate: bool, require_exposure := true) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var camera: Camera2D = view.get_camera_2d()
	if not check(camera != null, label + " real viewport has no camera"): return
	var bitmap := view.get_texture().get_image()
	var bounds: Rect2 = chapter.map.layout.world_bounds
	var inverse: Transform2D = view.get_canvas_transform().affine_inverse()
	var player_screen: Rect2 = chapter.player.get_visual_node().get_global_transform_with_canvas() * chapter.player.get_visual_rect()
	var boss_screen := Rect2()
	if is_instance_valid(boss): boss_screen = boss.get_visual_node().get_global_transform_with_canvas() * boss.get_visual_rect()
	var blocked: Array[Rect2] = chapter.ui.get_combat_occluder_rects()
	blocked.append(player_screen.grow(8.0))
	if is_instance_valid(boss): blocked.append(boss_screen.grow(8.0))
	var outside := 0
	var clear_hits := 0
	var examples: Array[Dictionary] = []
	if pixel_gate:
		for y in range(8, bitmap.get_height(), 16):
			for x in range(8, bitmap.get_width(), 16):
				var screen := Vector2(x, y)
				if bounds.grow(32.0).has_point(inverse * screen): continue
				var obscured := false
				for rect in blocked: obscured = obscured or rect.has_point(screen)
				if obscured: continue
				outside += 1
				var pixel := bitmap.get_pixel(x, y)
				if maxf(absf(pixel.r-clear_pixel.r), maxf(absf(pixel.g-clear_pixel.g), absf(pixel.b-clear_pixel.b))) <= 2.0/255.0:
					clear_hits += 1
					if examples.size() < 8: examples.append({"screen": xy(screen), "world": xy(inverse * screen), "pixel": rgba(pixel)})
		if require_exposure: check(outside >= 8, label + " has insufficient unoccluded off-map pixels; cannot assert backdrop coverage")
		check(clear_hits == 0, label + " off-map pixels remain actual Main runtime-clear-color")
	var path := output + label + ".png"
	check(bitmap.save_png(path) == OK, label + " GPU image write failed")
	samples.append({"label": label, "file": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path), "viewport": xy(Vector2(view.size)), "world_bounds": rect_array(bounds), "runtime_clear_pixel": rgba(clear_pixel), "camera_center": xy(camera.get_screen_center_position()), "camera_global": xy(camera.global_position), "zoom": xy(camera.zoom), "camera_limits": [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom], "canvas_transform": [xy(view.canvas_transform.x), xy(view.canvas_transform.y), xy(view.canvas_transform.origin)], "player_screen_rect": rect_array(player_screen), "boss_screen_rect": rect_array(boss_screen), "player_world": xy(chapter.player.global_position), "boss_world": xy(boss.global_position) if is_instance_valid(boss) else [], "boss_phase": boss.get_phase() if is_instance_valid(boss) else 0, "boss_entrance_resolved": boss.entrance_resolved if is_instance_valid(boss) else null, "framing_active": chapter.framing.active, "both_fit": chapter.framing.both_fit, "safe_screen_rect": rect_array(chapter.framing.safe_screen_rect), "physics_frame": Engine.get_physics_frames(), "pixel_gate": pixel_gate, "outside_samples": outside, "clear_color_hits": clear_hits, "first_clear_examples": examples})

func cleanup_view() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]: Input.action_release(action)
	paused = false
	if is_instance_valid(clear_probe):
		clear_probe.queue_free()
		clear_probe = null
	if is_instance_valid(view):
		for scene in view.get_children():
			var audio: Node = scene.get("audio")
			if not is_instance_valid(audio): continue
			audio.begin_shutdown()
			var deadline := Time.get_ticks_msec() + 2500
			while not audio.is_shutdown_complete() and Time.get_ticks_msec() < deadline: await process_frame
			check(audio.is_shutdown_complete(), "owned fixture audio did not drain")
			Support.stop_audio(audio)
		view.queue_free()
		view = null
	await process_frame
	await process_frame

func xy(value: Vector2) -> Array: return [value.x, value.y]
func rgba(value: Color) -> Array: return [value.r, value.g, value.b, value.a]
func rect_array(value: Rect2) -> Array: return [value.position.x, value.position.y, value.size.x, value.size.y]
