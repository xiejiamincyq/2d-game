extends SceneTree

const Map = preload("res://scenes/world/mist_nursery.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
var assertions := 0
var failures := 0
var clears := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NurseryEncounterTest " + message)

func _initialize() -> void:
	call_deferred("_run")

func _fixture(script: Script, seed_value: int) -> Dictionary:
	var host := Node2D.new()
	root.add_child(host)
	var map = Map.instantiate()
	map.map_seed = seed_value
	host.add_child(map)
	var player := Player.new()
	player.world_bounds = map.layout.world_bounds
	host.add_child(player)
	# This is a combat/state integration fixture, not ordinary-input play evidence.
	player.set_physics_process(false)
	var enemies := Node2D.new()
	var projectiles := Node2D.new()
	var portals := Node2D.new()
	for layer in [enemies, projectiles, portals]:
		host.add_child(layer)
	var growth := Growth.new()
	host.add_child(growth)
	growth.setup(player)
	var director = script.new()
	host.add_child(director)
	director.set_process(false)
	director.chapter_cleared.connect(func(_chapter: int) -> void: clears += 1)
	check(director.start_run(seed_value, player, enemies, projectiles, portals, growth, map.layout), "valid nursery run refused")
	return {"host": host, "player": player, "growth": growth, "director": director}

func _clear_combat(fixture: Dictionary) -> void:
	var director = fixture.director
	check(director.begin_encounter(), "prepared encounter did not begin")
	check(not director.begin_encounter(), "duplicate begin accepted")
	for step in 100:
		director._process(0.25)
		if director.spawn_queue.is_empty() and director.active_portals.is_empty():
			break
	check(not director.get_active_enemies().is_empty(), "encounter never created real enemies")
	check(director.state == director.State.COMBAT, "queued/spawned living enemies counted as clear")
	check(not director.finish_reward(), "combat skipped into reward")
	for enemy in director.get_active_enemies().duplicate():
		var shapes := 0
		for child in enemy.get_children():
			if child is CollisionShape2D and child.shape is CircleShape2D and is_equal_approx(child.shape.radius, enemy.body_radius):
				shapes += 1
		check(enemy is CharacterBody2D and shapes == 1, "fake enemy substituted for real collider/actor")
		check(enemy.kind in [enemy.EnemyKind.SCRAPPER, enemy.EnemyKind.SPITTER], "unplanned enemy family spawned")
		enemy.take_damage(1e9, &"test")
	await process_frame
	await process_frame
	director._process(0)
	check(director.state == director.State.COLLECT, "actual enemy deaths did not enter collection")
	director._process(3.1)
	check(director.state == director.State.REWARD, "cleared encounter did not prepare actual reward")
	var reward: Dictionary = fixture.growth.get_settlement_state()
	check(not reward.closed and not reward.reward_claimed, "reward is not an active build transaction")
	check(not director.finish_reward(), "unclaimed reward allowed advancing")
	var offer: Dictionary = reward.families[0].offers[0].duplicate(true)
	var stale := offer.duplicate(true)
	stale.transaction = -1
	stale._settlement_transaction = -1
	check(not director.claim_reward(stale), "stale offer accepted")
	check(director.claim_reward(offer), "real free build offer refused")
	check(not director.claim_reward(offer), "reward duplicated")
	check(director.finish_reward(), "claimed build reward did not advance")
	check(not director.finish_reward(), "reward completion replay advanced twice")

func _run() -> void:
	var path := "res://scripts/systems/NurseryEncounterDirector.gd"
	check(FileAccess.file_exists(path), "first chapter encounter director absent")
	if failures > 0:
		quit(1)
		return
	var script = load(path)
	var supply := _fixture(script, 521)
	var director = supply.director
	var original: Dictionary = director.get_encounter()
	var exported: Dictionary = director.get_encounter()
	exported.scrapper = 9999
	check(director.get_encounter() == original, "caller mutated live encounter")
	check(not director.restore_stable_boundary(6, "boss_settlement"), "old wave snapshot bypassed chapter flow")
	check(not director.choose_route(&"supply") and not director.begin_boss(), "route/Boss entered before combat")
	await _clear_combat(supply)
	check(director.get_encounter().id != original.id, "two mandatory encounters have same identity")
	await _clear_combat(supply)
	check(director.state == director.State.ROUTE, "mandatory combats did not reach choice")
	check(not director.choose_route(&"invalid"), "unknown route accepted")
	supply.player.health.damage(30, true)
	var health_before: float = supply.player.health.current_health
	var coins_before: int = supply.growth.coins
	var nested := {"attempted": false, "accepted": false}
	supply.growth.progression_state_changed.connect(func(_build: Dictionary) -> void:
		if not nested.attempted:
			nested.attempted = true
			nested.accepted = director.choose_route(&"supply")
	)
	check(director.choose_route(&"supply"), "supply route refused")
	check(nested.attempted and not nested.accepted, "build notification reentered route transaction")
	check(supply.growth.coins == coins_before + 12 and is_equal_approx(supply.player.health.current_health, health_before + 20), "supply did not affect actual currency/health")
	check(not director.choose_route(&"risk") and supply.growth.coins == coins_before + 12, "choice repeated grants or changed route")
	check(director.begin_boss(), "ready transition Boss did not spawn")
	var boss: Node = director.get_active_boss()
	check(boss != null and boss.health.current_health > 0, "Boss is not actual live actor")
	var unrelated := Node2D.new()
	director._on_boss_tree_exiting(unrelated)
	check(director.state == director.State.BOSS and director.get_active_boss() == boss, "unrelated exit changed active Boss flow")
	unrelated.free()
	boss.died.emit(boss, 60, &"test")
	check(director.state == director.State.BOSS and clears == 0, "forged live-Boss death signal cleared chapter")
	# Wait the real entrance clock; never flip entrance_resolved/invulnerability.
	for frame in 360:
		if boss.entrance_resolved:
			break
		await process_frame
	check(boss.entrance_resolved, "Boss natural entrance failed to complete")
	check(boss.take_damage(1e9, &"test"), "actual post-entrance Boss damage refused")
	await process_frame
	await process_frame
	check(director.state == director.State.CLEARED and clears == 1, "actual Boss death did not clear exactly once")
	check(not director.complete_final_wave(), "legacy final wave path can emit alternate victory")
	supply.host.free()
	await process_frame
	var risk := _fixture(script, 521)
	check(risk.director.get_encounter() == original, "same seed changed first encounter")
	await _clear_combat(risk)
	await _clear_combat(risk)
	coins_before = risk.growth.coins
	check(risk.director.choose_route(&"risk"), "risk route refused")
	check(risk.director.state == risk.director.State.INTRO and risk.growth.coins == coins_before, "risk reward paid before extra battle")
	check(risk.director.get_encounter().scrapper > original.scrapper, "risk encounter does not increase real enemy pressure")
	await _clear_combat(risk)
	check(risk.growth.coins == coins_before + 35, "risk clear failed to grant actual currency")
	check(risk.director.state == risk.director.State.BOSS_READY and risk.director.begin_boss(), "risk did not lead to Boss")
	risk.director.get_active_boss().queue_free()
	await process_frame
	await process_frame
	check(risk.director.state == risk.director.State.FAILED and clears == 1, "removed living Boss counted as defeat")
	risk.host.free()
	await process_frame
	var cancelled := _fixture(script, -1)
	check(cancelled.director.begin_encounter(), "negative seed failed to begin")
	for step in 20:
		cancelled.director._process(0.25)
		if not cancelled.director.get_active_enemies().is_empty():
			break
	check(not cancelled.director.get_active_enemies().is_empty(), "cancellation fixture spawned no real enemy")
	cancelled.director.get_active_enemies()[0].queue_free()
	await process_frame
	await process_frame
	check(cancelled.director.state == cancelled.director.State.FAILED and clears == 1, "removed living normal enemy grants reward/progress")
	cancelled.host.free()
	await process_frame
	var death := _fixture(script, 7)
	death.player.health.damage(1e9, true)
	check(death.director.state == death.director.State.FAILED, "actual player death did not fail run")
	check(not death.director.begin_encounter() and not death.director.choose_route(&"supply") and not death.director.begin_boss(), "dead player progressed or received supply")
	death.host.free()
	await process_frame
	if failures == 0:
		print("TEST PASS: NurseryEncounterTest %d" % assertions)
	quit(1 if failures > 0 else 0)
