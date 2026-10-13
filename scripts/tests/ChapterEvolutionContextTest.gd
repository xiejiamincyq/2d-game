extends SceneTree
## Controlled chapter-context/transaction integration, NOT ordinary combat,
## Boss victory, player playtesting, or permanent-unlock evidence.
## Real Chapter/Player/Growth, actual offers and transaction APIs only.

const Support = preload("TestSupport.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const GrowthScript = preload("res://scripts/systems/UpgradeSystem.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const EVOLUTIONS := {
	"ballistics": "orbital_storm",
	"mobility": "rift_overdrive",
	"automation": "thunder_matrix",
}
const PREREQUISITES := {
	"ballistics": [], "mobility": ["mine"], "automation": ["drone", "arc"],
}
var assertions := 0
var failures := 0
var fixture_serial := 0
var owned_paths: Array[String] = []
var packed: PackedScene

func check(ok: bool, message: String) -> bool:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: ChapterEvolutionContextTest " + message)
	return ok

func _initialize() -> void:
	call_deferred("_run")

func _offers(growth: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var state: Dictionary = growth.get_settlement_state()
	for group: Dictionary in state.get("families", []):
		for offer: Dictionary in group.get("offers", []):
			result.append(offer.duplicate(true))
	return result

func _evolutions(growth: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offer in _offers(growth):
		if String(offer.get("kind", "")) == "evolution":
			result.append(offer)
	return result

func _fresh_chapter() -> Node:
	fixture_serial += 1
	var path := "user://chapter_evolution_context_%d_%d.json" % [OS.get_process_id(), fixture_serial]
	for suffix in ["", ".tmp", ".bak"]:
		if not check(not FileAccess.file_exists(path + suffix) and not DirAccess.dir_exists_absolute(path + suffix), "refusing an existing fixture path"):
			return null
	owned_paths.append(path)
	var chapter: Node = packed.instantiate()
	chapter.campaign_store_path = path
	chapter.audio_enabled = false
	chapter.run_seed = 521
	root.add_child(chapter)
	if not check(chapter.player != null and chapter.growth != null and chapter.director != null, "actual Nursery Chapter did not assemble its real context"):
		await _dispose(chapter)
		return null
	# No combat is simulated. Freeze intro actors while exercising reward APIs.
	chapter.player.set_physics_process(false)
	chapter.director.set_process(false)
	paused = true
	return chapter

func _dispose(chapter: Node) -> void:
	paused = false
	if chapter != null and is_instance_valid(chapter):
		Support.stop_audio(chapter.audio)
		chapter.free()
	await process_frame

func _normal_reward(growth: Node, stage: int, family: String, buy_modules: bool, excluded_id := "") -> bool:
	if not check(growth.prepare_settlement(stage), "normal encounter %d reward could not prepare" % stage):
		return false
	check(_evolutions(growth).is_empty(), "normal encounters 1/2 must not expose premature evolution")
	var normal: Dictionary = {}
	var offers := _offers(growth)
	for offer in offers:
		if String(offer.get("family", "")) != family or String(offer.get("kind", "")) == "evolution" or String(offer.get("id", "")) == excluded_id:
			continue
		if normal.is_empty():
			normal = offer
		if String(offer.get("id", "")) in PREREQUISITES[family]:
			normal = offer
			break
	if not check(not normal.is_empty(), "no real normal offer for " + family):
		return false
	var levels: Dictionary = growth.family_levels.duplicate(true)
	var coins_before: int = growth.coins
	if not check(growth.claim_free_offer(normal), "normal family reward was not claimable"):
		return false
	check(growth.coins == coins_before and int(growth.family_levels[family]) == int(levels[family]) + 1, "only the free family reward must advance its level")
	for other in EVOLUTIONS:
		if other != family:
			check(growth.family_levels[other] == levels[other], "free reward raised an unrelated family")
	var after_claim: Dictionary = growth.get_snapshot_state()
	check(not growth.claim_free_offer(normal) and growth.get_snapshot_state() == after_claim, "normal free offer was consumed twice")
	check(not growth.purchase_settlement_offer(normal) and growth.get_snapshot_state() == after_claim, "claimed normal offer was sold again")
	if buy_modules:
		for offer in offers:
			var id := String(offer.get("id", ""))
			if id not in PREREQUISITES[family] or int(growth.upgrade_counts.get(id, 0)) > 0:
				continue
			var paid_levels: Dictionary = growth.family_levels.duplicate(true)
			if not check(growth.purchase_settlement_offer(offer), "offered prerequisite module purchase was rejected"):
				return false
			check(growth.family_levels == paid_levels, "paid prerequisite incorrectly raised the family level")
			var after_paid: Dictionary = growth.get_snapshot_state()
			check(not growth.purchase_settlement_offer(offer) and growth.get_snapshot_state() == after_paid, "paid prerequisite was sold twice")
	var state: Dictionary = growth.get_settlement_state()
	return check(growth.complete_settlement({"transaction": state.transaction}), "normal encounter reward did not close")

func _reject_finale(growth: Node, completed: int, message: String) -> void:
	var before: Dictionary = growth.get_snapshot_state()
	check(not bool(growth.call("prepare_chapter_finale", completed)), message)
	check(growth.get_snapshot_state() == before, "rejected finale mutated existing transaction/build")

func _family_finale(family: String) -> void:
	var chapter: Node = null
	var ready := false
	# Mine is currently randomized, not a guaranteed starter. Deterministic,
	# independent new contexts search for naturally offered prerequisite modules;
	# NEVER reroll an open settlement, alter the catalog, or inject card ranks.
	for attempt in 32:
		chapter = await _fresh_chapter()
		if chapter == null:
			return
		var growth: Node = chapter.growth
		seed(23000 + attempt)
		check(growth.add_coins(1000), "controlled fixture funding failed")
		_reject_finale(growth, 2, "empty context accepted a finale before real reward boundaries")
		if not _normal_reward(growth, 1, family, true):
			await _dispose(chapter)
			return
		_reject_finale(growth, 2, "one completed encounter was treated as two")
		if not _normal_reward(growth, 2, family, true):
			await _dispose(chapter)
			return
		ready = true
		for required in PREREQUISITES[family]:
			ready = ready and int(growth.upgrade_counts.get(required, 0)) > 0
		if ready:
			break
		await _dispose(chapter)
		chapter = null
	if not check(ready and chapter != null, "no deterministic normal-transaction build acquired prerequisites for " + family):
		return
	var growth: Node = chapter.growth
	check(growth.family_levels[family] == 3, "two genuine free choices must leave the selected family at level 3")
	check(String(growth.acquired_evolution_id).is_empty() and chapter.player.active_build_evolutions.is_empty(), "evolution was injected before the finale")
	_reject_finale(growth, 1, "finale accepted an old completion count")
	_reject_finale(growth, 3, "finale fabricated a third completed encounter")
	var previous: Dictionary = growth.get_settlement_state()
	if check(bool(growth.call("prepare_chapter_finale", 2)), "real Nursery Chapter did not establish chapter growth context for " + family):
		var finale: Dictionary = growth.get_settlement_state()
		check(finale.wave == 2 and int(finale.transaction) > int(previous.transaction), "finale must create a separate transaction without inventing wave 4")
		var candidates := _evolutions(growth)
		if check(candidates.size() == 1, "eligible level-3 chapter family must receive one evolution"):
			var evolution: Dictionary = candidates[0]
			check(String(evolution.id) == EVOLUTIONS[family] and String(evolution.family) == family, "wrong family evolution entered the finale")
			_reject_finale(growth, 2, "open finale was rerolled/reissued")
			if check(growth.claim_free_offer(evolution), "chapter evolution offer could not be normally claimed"):
				check(growth.acquired_evolution_id == EVOLUTIONS[family] and chapter.player.active_build_evolutions.has(EVOLUTIONS[family]), "normal claim failed to activate the corresponding real player evolution")
				var accepted: Dictionary = growth.get_snapshot_state()
				check(not growth.claim_free_offer(evolution) and growth.get_snapshot_state() == accepted, "evolution free claim replay changed the build")
				check(not growth.purchase_settlement_offer(evolution) and growth.get_snapshot_state() == accepted, "claimed evolution was resold")
				check(growth.complete_settlement({"transaction": finale.transaction}), "finale reward could not close")
				_reject_finale(growth, 2, "closed finale was issued a second time")
				check(not growth.prepare_settlement(3), "normal rewards resumed after the one-time finale")
	await _dispose(chapter)

func _ineligible_chapter(distributed: bool) -> void:
	var chapter: Node = await _fresh_chapter()
	if chapter == null:
		return
	var growth: Node = chapter.growth
	seed(23100)
	var first_family := "ballistics" if distributed else "automation"
	var second_family := "mobility" if distributed else "automation"
	var excluded := "" if distributed else "drone"
	if _normal_reward(growth, 1, first_family, false, excluded) and _normal_reward(growth, 2, second_family, false, excluded):
		if not distributed:
			check(growth.family_levels.automation == 3 and int(growth.upgrade_counts.get("drone", 0)) == 0, "missing-module fixture accidentally acquired drone")
		if check(bool(growth.call("prepare_chapter_finale", 2)), "ineligible build still needs the ordinary finale reward transaction"):
			check(_evolutions(growth).is_empty(), "low/distributed family or missing required modules received evolution")
	await _dispose(chapter)

func _legacy_stays_legacy() -> void:
	var player: Node = PlayerScript.new()
	root.add_child(player)
	player.set_physics_process(false)
	var growth: Node = GrowthScript.new()
	root.add_child(growth)
	growth.setup(player)
	seed(23200)
	if _normal_reward(growth, 1, "ballistics", false) and _normal_reward(growth, 2, "ballistics", false):
		_reject_finale(growth, 2, "legacy context accepted the chapter-only finale")
		if check(growth.prepare_settlement(3), "legacy third wave no longer prepares"):
			check(_evolutions(growth).is_empty(), "chapter level-3 policy leaked into legacy wave 3")
			var normal := _offers(growth)
			if check(not normal.is_empty(), "legacy third wave has no normal offers"):
				check(growth.claim_free_offer(normal[0]), "legacy third free reward failed")
				var state: Dictionary = growth.get_settlement_state()
				check(growth.complete_settlement({"transaction": state.transaction}), "legacy third reward failed to close")
				_reject_finale(growth, 3, "legacy stage 3 was converted to chapter context")
	growth.free()
	player.free()
	await process_frame

func _run() -> void:
	var real_save_hash := FileAccess.get_sha256(Store.DEFAULT_PATH) if FileAccess.file_exists(Store.DEFAULT_PATH) else ""
	var scene_path := "res://scenes/campaign/nursery_chapter.tscn"
	if not check(ResourceLoader.exists(scene_path, "PackedScene"), "real Nursery Chapter resource is absent"):
		quit(1)
		return
	packed = load(scene_path)
	var first: Node = await _fresh_chapter()
	if first == null:
		quit(1)
		return
	# Missing API is a semantic RED, not a nonexistent-static-method parse error.
	var methods_ready := true
	for method in ["setup_chapter", "prepare_chapter_finale"]:
		methods_ready = check(first.growth.has_method(method), "missing chapter growth boundary: " + method) and methods_ready
	await _dispose(first)
	if methods_ready:
		_fresh_context_boundaries()
		for family: String in EVOLUTIONS:
			await _family_finale(family)
		await _ineligible_chapter(true)
		await _ineligible_chapter(false)
		await _legacy_stays_legacy()
	for path in owned_paths:
		for suffix in ["", ".tmp", ".bak"]:
			check(not FileAccess.file_exists(path + suffix) and not DirAccess.dir_exists_absolute(path + suffix), "controlled reward test unexpectedly wrote permanent progress")
	var after_save_hash := FileAccess.get_sha256(Store.DEFAULT_PATH) if FileAccess.file_exists(Store.DEFAULT_PATH) else ""
	check(after_save_hash == real_save_hash, "actual user campaign save changed during controlled transactions")
	paused = false
	if failures == 0:
		print("TEST PASS: ChapterEvolutionContextTest %d" % assertions)
	quit(1 if failures > 0 else 0)

func _fresh_context_boundaries() -> void:
	var player: Node = PlayerScript.new()
	root.add_child(player)
	player.set_physics_process(false)
	for number in range(1, 7):
		var growth: Node = GrowthScript.new()
		root.add_child(growth)
		var before: Dictionary = growth.get_snapshot_state()
		check(not growth.setup_chapter(null, number) and growth.get_snapshot_state() == before, "null player changed a fresh context")
		check(not growth.setup_chapter(player, 0) and not growth.setup_chapter(player, 7) and not growth.is_chapter_run(), "invalid chapter silently bound growth")
		check(growth.setup_chapter(player, number) and growth.is_chapter_run(), "valid chapter failed to bind its fresh context")
		check(not growth.setup_chapter(player, number) and growth.get_snapshot_state() == before, "chapter context rebound after setup")
		check(not growth.restore_snapshot_state(before), "wave snapshot restored inside a formal chapter")
		check(not growth.prepare_settlement(2) and growth.get_snapshot_state() == before, "chapter skipped its first real reward count")
		growth.free()
	var legacy: Node = GrowthScript.new()
	root.add_child(legacy)
	legacy.setup(player)
	check(not legacy.setup_chapter(player, 1) and not legacy.is_chapter_run(), "bound legacy growth silently switched context")
	legacy.free()
	player.free()
