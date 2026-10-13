extends SceneTree
## Real Main -> actual chapter UI -> ordinary movement/fire -> saved clear.
## No actor stat writes, direct damage, injected rewards, or fake Boss death.

const MainScene = preload("res://scenes/Main.tscn")
const Policy = preload("res://scripts/art/NaturalRunPolicy.gd")
const Clearance = preload("res://scripts/art/VerifyNurseryEncounterRun.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Projectile = preload("res://scripts/components/Projectile.gd")
const FlowCatalog = preload("res://scripts/systems/ChapterCatalog.gd")
const ChainEvidence = preload("res://scripts/art/CampaignChainEvidence.gd")
const OUT := "res://build/diagnostics/campaign-goal/nursery-flow-v4/"
var output := OUT
var additional_sources: Array[String] = []
var failures := 0
var assertions := 0
var shots := 0
var moves := 0
var samples: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var sources := {}
var entered_views := {}
var chain_context: Dictionary = {}
var chain_source_bank: Dictionary = {}
var chain_preparation: Dictionary = {}
var terrain_witnesses: Array[Dictionary] = []

func configure_chain_arguments(args: PackedStringArray) -> PackedStringArray:
	chain_context = ChainEvidence.parse_arguments(args, chapter_number())
	return chain_context.args

func prepare_campaign_progress(path: String) -> bool:
	if not chain_context.get("enabled", false): return prepare_progress(path)
	if not chain_context.get("valid", false): return false
	chain_source_bank = ChainEvidence.build_source_bank()
	chain_preparation = ChainEvidence.prepare_campaign(path, chain_context.parent_report, chapter_number(), chain_source_bank)
	return chain_preparation.get("valid", false)

func launch_campaign_entry(main: Variant) -> void:
	if chain_context.get("enabled", false):
		await _click(main.ui.start_screen.start_button)
	else:
		await _click(main.ui.start_screen.regions_button)
		await _click(main.ui.start_screen.chapter_buttons[chapter_number() - 1])
		await _click(main.ui.start_screen.launch_button)

func chain_after_clear(chapter: Node, report: Dictionary) -> bool:
	# Refuse before inspecting optional fields: an unfinished run has no receipt.
	if not chapter.clear_saved: return false
	if not chain_context.get("enabled", false) or not chain_preparation.get("valid", false): return false
	if chapter.director.state != chapter.director.State.CLEARED or chapter.director.defeated_boss_instance <= 0: return false
	var path := output + "campaign.json"
	var progress := Progress.new()
	if Store.new(path).load_progress(progress) != Store.LoadResult.LOADED: return false
	var saved_state := progress.to_state()
	if ChainEvidence.normalized_state(saved_state, chapter_number()).is_empty() or not has_expected_saved_clear(progress): return false
	if not ChainEvidence.source_bank_matches(chain_source_bank): return false
	var receipt := {"schema": 1, "enabled": true, "used_preseed": false, "process_id": OS.get_process_id(), "returned_to_main": false, "defeated_boss_instance": chapter.director.defeated_boss_instance, "expected_kills": minimum_victory_kills(chapter), "saved_sha256": FileAccess.get_sha256(path), "saved_state": saved_state, "before_state": chain_preparation.before_state, "parent_report_sha256": chain_preparation.parent_report_sha256, "parent_saved_sha256": chain_preparation.parent_saved_sha256, "previous_process_id": chain_preparation.previous_process_id, "source_bank": chain_source_bank.duplicate(true)}
	# Real Return button, not a synthetic Main or direct scene switch.
	await _click(chapter.ui.return_button)
	var main: Node = null
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		var candidate := actual_scene()
		if is_instance_valid(candidate) and candidate.get_script() != null and candidate.get_script().resource_path == "res://scripts/Main.gd":
			main = candidate
			break
		await process_frame
	if main == null or not main.campaign_storage_ok or main.run_started or main.campaign_store_path != path: return false
	if main.campaign_progress.to_state() != saved_state or FileAccess.get_sha256(path) != receipt.saved_sha256: return false
	var menu: Control = main.ui.start_screen
	if not menu.is_visible_in_tree() or not ChainEvidence.source_bank_matches(chain_source_bank): return false
	var next := mini(chapter_number() + 1, FlowCatalog.CHAPTER_COUNT)
	if menu.page != menu.Page.COVER or menu._progress.to_state() != saved_state or menu.start_button.disabled: return false
	if menu.EntryPolicy.default_chapter(menu._progress, menu._ready_chapters, menu._storage_notice.is_empty()) != next: return false
	await RenderingServer.frame_post_draw
	var capture := output + "returned_main.png"
	if main.get_viewport().get_texture().get_image().save_png(capture) != OK: return false
	receipt["next_entry_chapter"] = next
	receipt["return_capture"] = {"file": capture.trim_prefix("res://"), "sha256": FileAccess.get_sha256(capture)}
	receipt.returned_to_main = true
	report["prerequisite_fixture"] = []
	report["chain"] = receipt
	return true

func chapter_number() -> int: return 1
func prepare_progress(_path: String) -> bool: return true
func prepare_scene_host() -> void: pass
func scene_host() -> Node: return root
func actual_scene() -> Node: return current_scene
func proof_marker() -> String: return "VerifyNurseryChapterFlow"
func prepare_layout_capture(_chapter: Node) -> void: pass
func minimum_victory_kills(_chapter: Node) -> int: return 30
func has_expected_saved_clear(progress: RefCounted) -> bool:
	var number := chapter_number()
	if number<1 or number>FlowCatalog.CHAPTER_COUNT or not progress.has_cleared(number): return false
	if number==FlowCatalog.CHAPTER_COUNT: return progress.is_campaign_complete() and not progress.is_unlocked(number+1)
	return progress.is_unlocked(number+1)
func proof_scope() -> String:
	return "Real Main pointer UI and ordinary movement/aim/fire; no actor stat writes/direct damage or injected in-run rewards; not human playtest or final six-chapter acceptance"

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyNurseryChapterFlow " + message)

func _initialize() -> void:
	call_deferred("_run")

func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]:
		Input.action_release(action)

func _click(button: Button) -> void:
	check(button.is_visible_in_tree() and not button.disabled, "input target unavailable: " + button.text)
	actions.append({"button": button.text, "physics_frame": Engine.get_physics_frames()})
	var point := button.get_global_rect().get_center()
	var view := button.get_viewport()
	_inject_mouse(view, point)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		view.push_input(click, true)
	await process_frame

func _inject_mouse(view: Viewport, point: Vector2) -> void:
	if view is Window: Input.warp_mouse(point)
	if view is SubViewport and not entered_views.has(view.get_instance_id()):
		view.notify_mouse_entered()
		entered_views[view.get_instance_id()] = true
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	view.push_input(motion, true)

func _capture(chapter: Node, step: int, label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := output + "frame_%03d.png" % samples.size()
	check(chapter.get_viewport().get_texture().get_image().save_png(path) == OK, "native frame save failed")
	var boss = chapter.director.get_active_boss()
	samples.append({"step": step, "label": label, "physics_frame": Engine.get_physics_frames(), "wall_usec": Time.get_ticks_usec(), "state": chapter.director.State.keys()[chapter.director.state], "encounter": chapter.director.encounter_index, "position": [chapter.player.position.x, chapter.player.position.y], "health": chapter.player.health.current_health, "boss_health": boss.health.current_health if boss != null else null, "kills": chapter.kills, "shots": shots, "file": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path)})

func _pick_offer(chapter: Node) -> Button:
	# Explicit initialization in a non-awaiting helper avoids stale loop locals
	# across the long-running driver's coroutine/reward state changes.
	var selected: Button = null
	for button: Button in chapter.ui.settlement_screen.offer_buttons:
		if button.visible and not button.disabled:
			if selected == null or button.text.contains("无人机") or button.text.contains("弹道"):
				selected = button
	return selected

static func reward_selection_count(previous_transaction: int, transaction: int, selections: int) -> int:
	if transaction <= 0: return 3
	return 0 if transaction != previous_transaction else clampi(selections, 0, 3)

func aim_world_point(_chapter: Node, direct_point: Vector2) -> Vector2:
	return direct_point

func _run() -> void:
	check(DisplayServer.get_name() != "headless", "native rendering required")
	check(not DirAccess.dir_exists_absolute(output), "must not overwrite previous proof")
	if failures > 0:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	for path in ["scripts/Main.gd", "scripts/campaign/NurseryChapter.gd", "scripts/ui/NurseryChapterUI.gd", "scripts/systems/NurseryEncounterDirector.gd", "scripts/systems/CampaignProgress.gd", "scripts/systems/CampaignProgressStore.gd", "scripts/actors/Player.gd", "scripts/actors/Enemy.gd", "scripts/actors/OverseerBoss.gd", "scripts/systems/UpgradeSystem.gd", "scripts/art/NaturalRunPolicy.gd", "scripts/art/VerifyNurseryChapterFlow.gd", "scripts/world/NurseryArenaLayout.gd"] + additional_sources:
		sources[path] = FileAccess.get_sha256("res://" + path)
	for path in ["scripts/campaign/ChapterRun.gd", "scripts/campaign/ChapterRunDefinitions.gd", "scripts/campaign/ChapterSceneRegistry.gd", "scripts/ui/ChapterRunUI.gd"]:
		sources[path] = FileAccess.get_sha256("res://" + path)
	check(prepare_campaign_progress(output + "campaign.json"), "isolated prerequisite save preparation failed")
	if failures > 0:
		quit(1)
		return
	_release()
	await prepare_scene_host()
	var main = MainScene.instantiate()
	main.campaign_store_path = output + "campaign.json"
	main.audio_enabled = false
	scene_host().add_child(main)
	if main.get_parent() == root: current_scene = main
	await process_frame
	await launch_campaign_entry(main)
	await process_frame
	var chapter = actual_scene()
	check(chapter._chapter_number() == chapter_number(), "Main click did not enter requested actual chapter")
	if failures > 0:
		quit(1)
		return
	chapter.player.fired.connect(func(_shot: Node) -> void: shots += 1)
	await prepare_layout_capture(chapter)
	var policy := Policy.new(20261009)
	var prior_state := -1
	var settle_purchases := 0
	var prior_reward_transaction := 0
	var resumed := false
	for step in 30000:
		_release()
		var state: int = chapter.director.state
		if state != prior_state:
			print("FLOW STATE: %s step=%d HP=%.1f kills=%d" % [chapter.director.State.keys()[state], step, chapter.player.health.current_health, chapter.kills])
			await _capture(chapter, step, chapter.director.State.keys()[state])
			prior_state = state
			settle_purchases = 0
			resumed = false
		if state in [chapter.director.State.CLEARED, chapter.director.State.FAILED]:
			break
		if state in [chapter.director.State.INTRO, chapter.director.State.BOSS_READY] and not chapter.ui.proceed_button.disabled:
			await _click(chapter.ui.proceed_button)
		elif state == chapter.director.State.REWARD:
			var reward: Dictionary = chapter.growth.get_settlement_state()
			var transaction := int(reward.get("transaction", 0))
			settle_purchases = reward_selection_count(prior_reward_transaction, transaction, settle_purchases)
			prior_reward_transaction = transaction
			var selected: Button = _pick_offer(chapter)
			if transaction > 0 and selected != null and (not reward.reward_claimed or settle_purchases < 3):
				await _click(selected)
				settle_purchases += 1
			else:
				await _click(chapter.ui.settlement_screen.close_button)
		elif state == chapter.director.State.ROUTE:
			await _click(chapter.ui.supply_button)
		elif state in [chapter.director.State.COMBAT, chapter.director.State.COLLECT, chapter.director.State.BOSS]:
			if resumed:
				var threats: Array[Vector2] = []
				var danger_distance := INF
				var aim: Vector2 = chapter.player.position + Vector2(500, 0)
				var nearest := INF
				for enemy in chapter.director.get_active_enemies():
					if not is_instance_valid(enemy) or enemy.health.current_health <= 0:
						continue
					threats.append(enemy.global_position)
					var distance: float = chapter.player.position.distance_squared_to(enemy.global_position)
					if distance < nearest:
						nearest = distance
						aim = enemy.global_position
				for projectile in chapter.projectiles.get_children():
					if projectile is Projectile and projectile.target_group == &"player" and projectile.global_position.distance_to(chapter.player.position) < 400:
						var future: Vector2 = projectile.global_position + projectile.velocity * 0.18
						threats.append(projectile.global_position)
						threats.append(future)
						danger_distance = minf(danger_distance, future.distance_to(chapter.player.position))
				var boss = chapter.director.get_active_boss()
				var telegraph: Node = boss.get_tentacle_attack() if boss != null else null
				if telegraph != null and telegraph.has_method("get_slam_targets") and telegraph.is_attacking():
					threats.append_array(telegraph.get_slam_targets())
				var steering := pilot_motion(chapter, policy, step, threats, telegraph, danger_distance)
				var direction: Vector2 = steering.direction
				for axis in [["move_left", -direction.x], ["move_right", direction.x], ["move_up", -direction.y], ["move_down", direction.y]]:
					if axis[1] > 0:
						Input.action_press(axis[0], axis[1])
				var view := chapter.get_viewport()
				aim = aim_world_point(chapter, aim)
				var at := (view.get_canvas_transform() * aim).clamp(Vector2.ONE, view.get_visible_rect().size - Vector2.ONE)
				_inject_mouse(view, at)
				Input.action_press("fire")
				if steering.dash and direction != Vector2.ZERO:
					Input.action_press("dash_melee")
			resumed = true
		var before: Vector2 = chapter.player.position
		await physics_frame
		await process_frame
		moves += 1 if chapter.player.position.distance_to(before) > 0.01 else 0
		var clear := Clearance.has_body_clearance(chapter.player.position, chapter.map.layout.world_bounds, chapter.map.layout.get_obstacle_descriptors(), chapter.player.get_body_radius())
		if not clear and terrain_witnesses.size()<16:
			var witness := Clearance.body_clearance_witness(chapter.player.position,chapter.map.layout.world_bounds,chapter.map.layout.get_obstacle_descriptors(),chapter.player.get_body_radius())
			witness.merge({"step":step,"physics_frame":Engine.get_physics_frames(),"before":[before.x,before.y],"velocity":[chapter.player.velocity.x,chapter.player.velocity.y],"dash_active":chapter.player.dash_active,"dash_recovery_pending":chapter.player.dash_recovery_pending,"stealth_recovery_pending":chapter.player.stealth_recovery_pending,"body_recovery_trace":chapter.player.stealth_recovery_trace,"stealthed":chapter.player.is_stealthed(),"state":chapter.director.State.keys()[chapter.director.state],"slide_collisions":chapter.player.get_slide_collision_count()})
			terrain_witnesses.append(witness)
			print("TERRAIN WITNESS: "+JSON.stringify(witness))
		check(clear, "actual player penetrated terrain")
		if step % 1800 == 0:
			await _capture(chapter, step, "periodic")
	_release()
	var restored := Progress.new()
	check(chapter.clear_saved and chapter.director.state == chapter.director.State.CLEARED, "ordinary run did not reach saved Boss clear")
	check(Store.new(output + "campaign.json").load_progress(restored) == Store.LoadResult.LOADED and has_expected_saved_clear(restored), "ordinary Boss clear not persisted at its actual chapter boundary")
	check(moves > 500 and shots > 50 and chapter.kills >= minimum_victory_kills(chapter), "insufficient actual movement/fire/kills")
	for path in sources:
		check(FileAccess.get_sha256("res://" + path) == sources[path], "source changed during proof")
	var report := {"valid": failures == 0, "scope": proof_scope(), "chapter": chapter_number(), "run_seed": chapter.run_seed, "assertions": assertions, "moves": moves, "shots": shots, "actions": actions, "sources": sources, "samples": samples,"terrain_witnesses":terrain_witnesses}
	report.merge(additional_report())
	if chain_context.get("enabled", false) and failures == 0:
		check(await chain_after_clear(chapter, report), "true clear did not return to restored formal Main")
		report.scope = "One sequential campaign leg: inherited only the previous actual ordinary clear, formal Main primary pointer input, normal gameplay, true Boss save, ordinary Return and restored next entry. No preseed, actor stats/direct damage or reward injection. Not human playtest, multi-seed balance or whole-project acceptance."
	elif failures == 0:
		check(await after_ordinary_clear(chapter, report), "post-clear ordinary input verification failed")
	report.valid = failures == 0
	report.assertions = assertions
	var file := FileAccess.open(output + "report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if failures == 0:
		print("TEST PASS: %s %d" % [proof_marker(), assertions])
		if chain_context.get("enabled", false): actual_scene()._request_close()
		else: actual_scene()._leave(false, true)
	else:
		shutdown_failed_scene(actual_scene())
		quit(1)

func shutdown_failed_scene(live: Node) -> void:
	if not is_instance_valid(live): return
	var audio: Node = live.get("audio")
	if is_instance_valid(audio): audio.begin_shutdown()
	var feedback: Node = live.get("feedback") if live.has_method("_chapter_number") else live.get("combat_feedback")
	if is_instance_valid(feedback): feedback.reset_all()

func additional_report() -> Dictionary:
	return {}

# Optional diagnostic continuation: only after a true saved victory, before
# the final verdict/write/shutdown. Chain legs retain their own Return receipt.
func after_ordinary_clear(_chapter: Node, _report: Dictionary) -> bool:
	return true

func pilot_motion(chapter: Node, policy: RefCounted, step: int, threats: Array[Vector2], telegraph: Node, danger_distance: float) -> Dictionary:
	var goal := Vector2.RIGHT.rotated(step / 180.0) * 350
	var direction: Vector2 = policy.choose_direction(chapter.player.position, goal, threats, func(point: Vector2) -> bool:
		if not chapter.map.layout.is_position_walkable(point, chapter.player.get_body_radius()):
			return false
		if telegraph != null and telegraph.is_attacking():
			if telegraph.is_point_in_sweep(point):
				return false
			for target: Vector2 in telegraph.get_slam_targets():
				if point.distance_to(target) < 72:
					return false
		return true
	)
	return {"direction": direction, "dash": danger_distance < 80}
