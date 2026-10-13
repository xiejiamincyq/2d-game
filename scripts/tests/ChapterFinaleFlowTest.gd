extends SceneTree
## Real Chapter/Director/reward integration with controlled enemy damage.
## NOT ordinary gameplay, human balance, Boss victory, or unlock evidence.
const Support = preload("TestSupport.gd")
const Scene = preload("res://scenes/campaign/nursery_chapter.tscn")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
var assertions := 0
var failures := 0
var serial := 0
var owned_paths: Array[String] = []

func check(ok: bool, message: String) -> bool:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: ChapterFinaleFlowTest " + message)
	return ok

func _initialize() -> void: call_deferred("_run")

func _scene_host() -> Node: return root

func _fixture() -> Node:
	serial += 1
	var path := "user://chapter_finale_flow_%d_%d.json" % [OS.get_process_id(), serial]
	for suffix in ["", ".tmp", ".bak"]:
		if not check(not FileAccess.file_exists(path + suffix) and not DirAccess.dir_exists_absolute(path + suffix), "existing fixture path refused"):
			return null
	owned_paths.append(path)
	var chapter: Node = Scene.instantiate()
	chapter.campaign_store_path = path
	chapter.audio_enabled = false
	chapter.run_seed = 521
	_scene_host().add_child(chapter)
	chapter.director.set_process(false)
	chapter.player.set_physics_process(false)
	paused = true
	return chapter

func _dispose(chapter: Node) -> void:
	paused = false
	Support.stop_audio(chapter.audio)
	chapter.free()
	await process_frame

func _clear_encounter(chapter: Node) -> Dictionary:
	var director: Node = chapter.director
	if not check(director.begin_encounter(), "real intro would not enter combat"):
		return {}
	for step in 160:
		director._process(0.25)
		if director.spawn_queue.is_empty() and director.active_portals.is_empty():
			break
	if not check(not director.get_active_enemies().is_empty(), "no actual living enemies spawned"):
		return {}
	for enemy in director.get_active_enemies().duplicate():
		enemy.take_damage(1e9, &"controlled_fixture")
	await process_frame
	await process_frame
	director._process(0)
	check(director.state == director.State.COLLECT, "real deaths must precede collection")
	director._process(3.1)
	var reward: Dictionary = chapter.growth.get_settlement_state()
	if not check(director.state == director.State.REWARD and reward.get("stage_kind") == "encounter", "normal combat must publish an encounter transaction"):
		return {}
	check(not director.begin_boss() and not director.finish_reward(), "unclaimed encounter bypassed reward")
	var offer: Dictionary = reward.families[0].offers[0].duplicate(true)
	check(director.claim_reward(offer), "normal free offer refused")
	check(director.finish_reward(), "normal reward would not finish")
	return offer

func _route(route: StringName) -> void:
	var chapter: Node = _fixture()
	if chapter == null: return
	var director: Node = chapter.director
	await _clear_encounter(chapter)
	var stale: Dictionary = await _clear_encounter(chapter)
	if not check(director.state == director.State.ROUTE, "two actual encounters must reach the route"):
		await _dispose(chapter)
		return
	var before_coins: int = chapter.growth.coins
	var before_health: float = chapter.player.health.current_health
	var signals := {"reward": 0, "boss": 0, "reentered": false, "accepted": false}
	director.reward_ready.connect(func(_reward: Dictionary) -> void: signals.reward += 1)
	director.chapter_boss_ready.connect(func(_label: String) -> void: signals.boss += 1)
	chapter.growth.settlement_changed.connect(func(reward: Dictionary) -> void:
		if reward.get("stage_kind") == "boss_prep" and not signals.reentered:
			signals.reentered = true
			signals.accepted = director.claim_reward(reward.families[0].offers[0]) or director.finish_reward() or director.begin_boss() or director.choose_route(route)
	)
	check(director.choose_route(route), "valid route rejected")
	check(not director.choose_route(route), "route replay allowed")
	if route == &"risk":
		check(director.state == director.State.INTRO and chapter.growth.coins == before_coins, "risk must require third actual combat before paying")
		stale = await _clear_encounter(chapter)
		check(chapter.growth.coins == before_coins + 35, "risk coins must pay exactly once after third reward")
	else:
		check(chapter.growth.coins == before_coins + 12, "supply coins must pay once")
		check(is_equal_approx(chapter.player.health.current_health, minf(chapter.player.health.max_health, before_health + 20)), "supply healing changed")
	var finale: Dictionary = chapter.growth.get_settlement_state()
	if not check(director.state == director.State.REWARD and finale.get("stage_kind") == "boss_prep", "route skipped the real Boss-preparation reward"):
		await _dispose(chapter)
		return
	var expected_count := 3 if route == &"risk" else 2
	check(finale.wave == expected_count and finale.transaction > stale.transaction, "finale fabricated a wave or reused old transaction")
	check(signals.reward == (2 if route == &"risk" else 1) and signals.boss == 0, "finale publication count or premature Boss signal")
	check(signals.reentered and not signals.accepted, "growth notification reentered an unpublished finale")
	check(not director.claim_reward(stale), "previous encounter offer accepted in finale")
	check(not director.finish_reward() and not director.begin_boss(), "unclaimed finale allowed Boss entry")
	var chosen: Dictionary = finale.families[0].offers[0]
	check(chosen.kind == "evolution" and chosen.id == "orbital_storm", "normal focused build did not expose actual evolution at Boss preparation")
	check(director.claim_reward(chosen), "actual finale free choice rejected")
	check(not director.claim_reward(chosen), "finale free choice duplicated")
	var paid_before: int = chapter.growth.coins
	check(director.finish_reward(), "claimed finale would not enter Boss readiness")
	check(director.state == director.State.BOSS_READY and signals.boss == 1, "Boss readiness was not exactly once after final reward")
	check(not director.finish_reward() and not director.choose_route(route) and chapter.growth.coins == paid_before and signals.boss == 1, "finale completion paid coins twice or repeated Boss readiness")
	check(chapter.player.active_build_evolutions.has("orbital_storm"), "normal reward never activated real player evolution")
	check(not chapter.clear_saved and not FileAccess.file_exists(chapter.campaign_store_path), "controlled reward flow wrote permanent clear")
	await _dispose(chapter)

func _death_during_finale() -> void:
	var chapter: Node = _fixture()
	if chapter == null: return
	await _clear_encounter(chapter)
	await _clear_encounter(chapter)
	chapter.director.choose_route(&"supply")
	chapter.player.health.damage(1e9, true)
	check(chapter.director.state == chapter.director.State.FAILED, "death during finale did not fail the run")
	var state: Dictionary = chapter.growth.get_settlement_state()
	check(not chapter.director.claim_reward(state.families[0].offers[0]) and not chapter.director.finish_reward() and not chapter.director.begin_boss(), "dead player claimed/prepared Boss")
	await _dispose(chapter)

func _run() -> void:
	var before := FileAccess.get_sha256(Store.DEFAULT_PATH) if FileAccess.file_exists(Store.DEFAULT_PATH) else ""
	await _route(&"supply")
	await _route(&"risk")
	await _death_during_finale()
	for path in owned_paths:
		for suffix in ["", ".tmp", ".bak"]:
			check(not FileAccess.file_exists(path + suffix), "fixture unexpectedly wrote progress")
	check(before == (FileAccess.get_sha256(Store.DEFAULT_PATH) if FileAccess.file_exists(Store.DEFAULT_PATH) else ""), "actual user save changed")
	paused = false
	if failures == 0: print("TEST PASS: ChapterFinaleFlowTest %d" % assertions)
	quit(1 if failures > 0 else 0)
