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
const EndlessEvidence = preload("res://scripts/art/CampaignEndlessEvidence.gd")
const LoopRules = preload("res://scripts/systems/CampaignLoopRules.gd")
const Plate = preload("res://scripts/world/ReusableStepTrap.gd")
const RuntimeProfile = preload("res://scripts/art/CampaignRuntimeProfile.gd")
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
var endless_context: Dictionary = {}
var endless_preparation: Dictionary = {}
var protected_saves: Dictionary = {}
var runtime_profile: RefCounted
var profile_audio_nodes:=false

func configure_chain_arguments(args: PackedStringArray) -> PackedStringArray:
	endless_context = EndlessEvidence.parse_arguments(args)
	chain_context = ChainEvidence.parse_arguments(endless_context.args, chapter_number())
	chain_context.valid = chain_context.valid and endless_context.valid and not (endless_context.enabled and chain_context.enabled)
	return chain_context.args

func prepare_campaign_progress(path: String) -> bool:
	if endless_context.get("enabled",false):
		chain_source_bank=EndlessEvidence.source_bank()
		protected_saves=EndlessEvidence.real_save_hashes()
		endless_preparation=EndlessEvidence.prepare(output,endless_context.parent,chapter_number(),chain_source_bank)
		return endless_preparation.get("valid",false)
	if not chain_context.get("enabled", false): return prepare_progress(path)
	if not chain_context.get("valid", false): return false
	chain_source_bank = ChainEvidence.build_source_bank()
	chain_preparation = ChainEvidence.prepare_campaign(path, chain_context.parent_report, chapter_number(), chain_source_bank)
	return chain_preparation.get("valid", false)

func launch_campaign_entry(main: Variant) -> void:
	if chain_context.get("enabled", false) or endless_context.get("enabled",false):
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
func minimum_victory_kills(chapter: Node) -> int:
	if not endless_context.get("enabled",false): return 30
	var expected:=1
	for index in (3 if chapter.director.route==&"risk" else 2):
		var base: Array[int]=chapter.director._encounter_kinds(chapter.director.encounters[index])
		expected+=LoopRules.compose(base,chapter_number(),chapter.run_loop).size()
	return expected
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
	if not pointer_center_exposed(button):
		# ScrollContainer follows genuine keyboard focus. Do not synthesize the
		# hidden button's pressed signal or write the scroll offset directly.
		for step in 24:
			if button.has_focus(): break
			await menu_key(button.get_viewport(),KEY_TAB)
		for frame in 2: await process_frame
		check(pointer_center_exposed(button),"keyboard navigation could not expose clipped input target: "+button.text)
		if not pointer_center_exposed(button): return
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

func pointer_center_exposed(button: Control) -> bool:
	var center:=button.get_global_rect().get_center()
	if not button.get_viewport().get_visible_rect().has_point(center): return false
	var ancestor:=button.get_parent()
	while ancestor!=null:
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().has_point(center): return false
		ancestor=ancestor.get_parent()
	return true

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
	if runtime_profile!=null:
		samples.append({"step":step,"label":label,"physics_frame":Engine.get_physics_frames(),"state":chapter.director.State.keys()[chapter.director.state],"kills":chapter.kills,"shots":shots,"coins":chapter.growth.coins,"image_readback":false})
		return
	await RenderingServer.frame_post_draw
	var path := output + "frame_%03d.png" % samples.size()
	check(chapter.get_viewport().get_texture().get_image().save_png(path) == OK, "native frame save failed")
	var boss = chapter.director.get_active_boss()
	samples.append({"step": step, "label": label, "physics_frame": Engine.get_physics_frames(), "wall_usec": Time.get_ticks_usec(), "state": chapter.director.State.keys()[chapter.director.state], "encounter": chapter.director.encounter_index, "position": [chapter.player.position.x, chapter.player.position.y], "health": chapter.player.health.current_health, "boss_health": boss.health.current_health if boss != null else null, "kills": chapter.kills, "shots": shots, "file": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path)})
	samples[-1]["coins"]=chapter.growth.coins

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
	main.audio_enabled = endless_context.get("profile",false)
	scene_host().add_child(main)
	if main.get_parent() == root: current_scene = main
	if endless_context.get("profile",false):
		runtime_profile=RuntimeProfile.new()
		check(runtime_profile.attach(actual_scene),"real frame-post-draw recorder did not attach")
	await process_frame
	await launch_campaign_entry(main)
	await process_frame
	var chapter = actual_scene()
	check(chapter._chapter_number() == chapter_number(), "Main click did not enter requested actual chapter")
	if endless_context.get("enabled",false):
		check(chapter.run_loop==int(endless_preparation.loop),"actual Main restores correct journey round")
		check(chapter.growth.coins==int(endless_preparation.before_state.coins) and chapter.growth.upgrade_counts==endless_preparation.before_state.inherited_counts,"actual chapter restores exact coins and inherited abilities")
		var inherited: Dictionary=endless_preparation.before_state.inherited_counts
		var expected_health: float=(90+chapter_number()*10)*pow(1.2,int(inherited.get("health",0)))
		var expected_shield: float=20+20*int(inherited.get("shield_capacity",0))
		check(is_equal_approx(chapter.player.health.max_health,expected_health) and chapter.player.shield==expected_shield,"actual entry applies fixed chapter base and each inherited support rank once, not stacked by round")
	if failures > 0:
		quit(1)
		return
	chapter.player.fired.connect(func(_shot: Node) -> void: shots += 1)
	if runtime_profile!=null:
		profile_audio_nodes=chapter.audio_enabled and not chapter.audio.silent_mode
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
			await _click(chapter.ui.risk_button if endless_context.get("enabled",false) and endless_context.route=="risk" else chapter.ui.supply_button)
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
				danger_distance=plate_threats(chapter,threats,danger_distance)
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
		if failures>0: break
		if step % 1800 == 0:
			await _capture(chapter, step, "periodic")
	_release()
	if endless_context.get("enabled",false):
		check(await finalize_endless_clear(chapter),"natural Boss defeat and normal inheritance input did not produce exact journey save")
	else:
		var restored := Progress.new()
		check(chapter.clear_saved and chapter.director.state == chapter.director.State.CLEARED, "ordinary run did not reach saved Boss clear")
		check(Store.new(output + "campaign.json").load_progress(restored) == Store.LoadResult.LOADED and has_expected_saved_clear(restored), "ordinary Boss clear not persisted at its actual chapter boundary")
	check(moves > 500 and shots > 50 and chapter.kills >= minimum_victory_kills(chapter), "insufficient actual movement/fire/kills")
	for path in sources:
		check(FileAccess.get_sha256("res://" + path) == sources[path], "source changed during proof")
	var report := {"valid": failures == 0, "scope": proof_scope(), "chapter": chapter_number(), "run_seed": chapter.run_seed, "assertions": assertions, "moves": moves, "shots": shots, "actions": actions, "sources": sources, "samples": samples,"terrain_witnesses":terrain_witnesses}
	report.merge(additional_report())
	if runtime_profile!=null:
		var performance: Dictionary=runtime_profile.finish()
		performance["audio_nodes_enabled"]=profile_audio_nodes
		performance["viewport"]=[chapter.get_viewport().get_visible_rect().size.x,chapter.get_viewport().get_visible_rect().size.y]
		report["performance"]=performance
		if report.has("native_scope"):
			report.native_scope="Actual native pose and health-model observations during real play; combat pixel captures disabled for frame measurement. Not an isolated alpha or human-visual acceptance."
		check(performance.complete and not performance.fixed_fps_argument and profile_audio_nodes,"real-clock performance sample is incomplete, fixed-step or audio-disabled")
	if endless_context.get("enabled",false) and failures==0:
		check(await endless_after_clear(chapter,report),"saved natural clear did not restore exact journey in real tent")
	elif chain_context.get("enabled", false) and failures == 0:
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
		if chain_context.get("enabled", false) or endless_context.get("enabled",false): actual_scene()._request_close()
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

func plate_threats(chapter: Node,threats: Array[Vector2],distance: float) -> float:
	for property in ["trap_field","heat_field","tidal_field","spore_field","echo_field","rift_field"]:
		var field: Node=chapter.map.get(property)
		if not is_instance_valid(field): continue
		for plate in field.get_children():
			if not plate is Plate or not plate.enabled or plate.stage in [Plate.Stage.COOLDOWN,Plate.Stage.DESTROYED]: continue
			threats.append(plate.global_position)
			distance=minf(distance,chapter.player.global_position.distance_to(plate.global_position))
	return distance

func menu_key(view: Viewport,key: Key) -> void:
	actions.append({"key":OS.get_keycode_string(key),"physics_frame":Engine.get_physics_frames()})
	for down in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=key; event.physical_keycode=key; event.pressed=down
		if view is Window:
			event.window_id=view.get_window_id()
			Input.parse_input_event(event)
		else: view.push_input(event,true)
	await process_frame

func select_first_carry(ui: Node) -> bool:
	var selector: OptionButton=ui.carry_selector
	if not selector.is_visible_in_tree() or selector.item_count<2: return false
	var view:=selector.get_viewport()
	var at:=selector.get_global_rect().get_center()
	_inject_mouse(view,at)
	for down in [true,false]:
		var click:=InputEventMouseButton.new()
		click.position=at; click.button_index=MOUSE_BUTTON_LEFT; click.pressed=down
		view.push_input(click,true)
	await process_frame
	var popup:=selector.get_popup()
	if not popup.visible: return false
	for step in 3:
		if popup.get_focused_item()==1: break
		await menu_key(popup,KEY_DOWN)
	if popup.get_focused_item()!=1: return false
	await menu_key(popup,KEY_ENTER)
	return not popup.visible

func finalize_endless_clear(chapter: Node) -> bool:
	if chapter.director.state!=chapter.director.State.CLEARED or chapter.director.defeated_boss_instance<=0: return false
	var choice:=""
	var earned: Dictionary=chapter.growth.upgrade_counts.duplicate(true)
	if chapter.ui.carry_selector.visible:
		choice=String(chapter.ui.carry_selector.get_item_metadata(1).get("id",""))
		if choice.is_empty() or not await select_first_carry(chapter.ui): return false
	for frame in 3: await process_frame
	if not chapter.clear_saved or chapter.session.has_pending_clear(): return false
	var restored:=EndlessEvidence.Journey.new()
	if EndlessEvidence.Journal.new(output+"campaign.json.journey").load_journey(restored)!=EndlessEvidence.Journal.LoadResult.LOADED: return false
	if not EndlessEvidence.validate_transition(endless_preparation.before_state,restored.to_state(),chapter.run_loop,chapter_number(),earned,choice,chapter.growth.coins): return false
	endless_preparation["choice"]=choice
	endless_preparation["earned"]=earned
	endless_preparation["saved_state"]=restored.to_state()
	endless_preparation["balance"]=chapter.growth.coins
	return true

func endless_after_clear(chapter: Node,report: Dictionary) -> bool:
	var journal_path:=output+"campaign.json.journey"
	var saved: Dictionary=endless_preparation.saved_state
	var entry: Dictionary=chapter.session.journey.get_entry()
	var boss_id: int=chapter.director.defeated_boss_instance
	var expected_kills:=minimum_victory_kills(chapter)
	var actual_route:=String(chapter.director.route)
	if chapter.ui.next_button.visible!=(chapter_number()<6) or not chapter.ui.return_button.visible or not chapter.ui.replay_button.visible: return false
	await _capture(chapter,30001,"claimed_inheritance")
	await _click(chapter.ui.return_button)
	var deadline:=Time.get_ticks_msec()+4000
	var main: Node=null
	while Time.get_ticks_msec()<deadline:
		var candidate:=actual_scene()
		if is_instance_valid(candidate) and candidate.get_script()!=null and candidate.get_script().resource_path=="res://scripts/Main.gd": main=candidate; break
		await process_frame
	if main==null or not main.campaign_storage_ok or main.campaign_session.journey.to_state()!=saved or main.campaign_session.journey.get_entry()!=entry: return false
	if main.campaign_store_path!=output+"campaign.json" or not main.ui.start_screen.is_visible_in_tree() or main.ui.start_screen.start_button.disabled: return false
	for frame in 16: await process_frame
	await RenderingServer.frame_post_draw
	var capture:=output+"returned_main.png"
	if main.get_viewport().get_texture().get_image().save_png(capture)!=OK: return false
	if EndlessEvidence.real_save_hashes()!=protected_saves or not EndlessEvidence.source_bank_matches(chain_source_bank): return false
	report.scope="One real endless journey leg: normal movement/aim/fire and UI, real Boss defeat, inheritance input, exact saved coins/ordinary ability and real tent restore. No prerequisite preseed, actor stat/direct damage/reward or attack-clock writes. Not OS/human playtest, two full rounds by itself, or performance acceptance."
	report.prerequisite_fixture=[]
	report["route"]=actual_route
	report["endless"]={"schema":1,"loop":int(endless_preparation.loop),"process_id":OS.get_process_id(),"used_preseed":false,"returned_to_main":true,"defeated_boss_instance":boss_id,"expected_kills":expected_kills,"before_state":endless_preparation.before_state,"saved_state":saved,"saved_sha256":FileAccess.get_sha256(journal_path),"parent_report_sha256":endless_preparation.parent_report_sha256,"parent_saved_sha256":endless_preparation.parent_saved_sha256,"previous_process_id":endless_preparation.previous_process_id,"choice":endless_preparation.choice,"earned_counts":endless_preparation.earned,"source_bank":chain_source_bank,"return_capture":{"file":capture.trim_prefix("res://"),"sha256":FileAccess.get_sha256(capture)},"next_entry":entry,"protected_saves":protected_saves}
	return true

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
