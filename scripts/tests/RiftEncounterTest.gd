extends "EchoEncounterTest.gd"
## R3 controlled damage/clock transactions, not normal-input victory evidence.
const RiftMap = preload("res://scenes/world/rift_observatory.tscn")
const Cutter = preload("res://scripts/actors/SpaceCutterEnemy.gd")
const Elite = preload("res://scripts/actors/RiftEliteEnemy.gd")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftEncounterTest "+label)
func fixture() -> Dictionary:
	var host := Host.new(); root.add_child(host)
	var map = RiftMap.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; host.add_child(player); player.set_physics_process(false)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player); host.player = player; host.growth = growth
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var director = load("res://scripts/systems/RiftEncounterDirector.gd").new(); host.add_child(director); director.set_process(false)
	director.chapter_cleared.connect(func(_chapter): clears += 1)
	check(director.bind_rift_field(map.rift_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"current map/field authority refused")
	return {"host":host,"map":map,"player":player,"growth":growth,"director":director,"enemies":enemies}
func clear_encounter(f: Dictionary,count: int) -> void:
	var d = f.director; var policy: Dictionary = d.get_encounter(); var coins: int = f.growth.coins
	var previous_drops: int = f.host.drops.size()
	check(d.begin_encounter() and not d.begin_encounter(),"duplicate combat start")
	check(f.map.rift_field.active and f.map.rift_field.get_children().filter(func(n): return n.enabled).size()==count,"combat has wrong real fault count")
	for _step in 100:
		d._process(0.25)
		if d.spawn_queue.is_empty() and d.active_portals.is_empty(): break
	var actors: Array = d.get_active_enemies().duplicate(); var expected_coins := 0
	check(actors.size()==policy.cutter+policy.elite and d.state==d.State.COMBAT,"mixed debt differs from policy")
	check(d.get_attack_targets().size()==actors.size(),"driver becomes enemy/weapon/reward target")
	var cutters := 0; var elites := 0
	for actor in actors:
		actor.set_physics_process(false); expected_coins += actor.coin_value
		check(actor.native_visual!=null and actor.should_show_health_bar() and f.map.layout.is_position_walkable(actor.global_position,actor.body_radius),"real native family/full-body legal birth")
		if actor is Cutter: cutters += 1; check(actor.body_radius==14 and actor.speed==112,"cutter body/motion altered")
		elif actor is Elite: elites += 1; check(actor.body_radius==16 and actor.speed==125,"elite body/motion altered")
		else: check(false,"generic role substituted")
		actor.died.emit(actor,999,&"test"); check(not actor.get_meta(&"kill_resolved",false),"forged living death rewarded")
	check(cutters==policy.cutter and elites==policy.elite and not d.finish_reward(),"unfinished debt bypasses reward")
	var first = actors[0]; first.take_damage(1000,&"test"); first.take_damage(1000,&"test")
	await process_frame; await process_frame; d._process(0)
	check(d.state==d.State.COMBAT and f.host.drops.size()==previous_drops+1,"one or duplicate death clears full combat")
	for index in range(1,actors.size()): actors[index].take_damage(1000,&"test")
	await process_frame; await process_frame; d._process(0)
	check(d.state==d.State.COLLECT and not f.map.rift_field.active and f.map.rift_field.get_children().all(func(n): return not n.enabled),"true clear retains moving danger")
	for _frame in 180:
		if f.host.pickups.get_child_count()==0: break
		await tick()
	check(f.host.pickups.get_child_count()==0 and f.growth.coins==coins+expected_coins,"real homing coins not uniquely collected")
	d._process(3.1)
	check(d.state==d.State.REWARD and not d.finish_reward(),"unclaimed reward bypass")
	var offer: Dictionary = f.growth.get_settlement_state().families[0].offers[0].duplicate(true)
	var forged := offer.duplicate(true); forged._settlement_transaction = -1; forged.transaction = -1
	check(not d.claim_reward(forged) and d.claim_reward(offer) and not d.claim_reward(offer),"forged/duplicate build transaction")
	check(not f.growth.upgrade_counts.is_empty() and d.finish_reward() and not d.finish_reward(),"real build choice absent or repeated")
func run() -> void:
	check(ResourceLoader.exists("res://scripts/systems/RiftEncounterDirector.gd"),"actual sixth encounter director missing")
	if failures: quit(1); return
	for route in [&"supply",&"risk"]:
		var f := fixture(); await tick(); await tick()
		await clear_encounter(f,2); await clear_encounter(f,2)
		check(f.director.state==f.director.State.ROUTE and not f.map.rift_field.active,"two mandatory battles absent or unsafe route")
		var coins: int = f.growth.coins; f.player.health.damage(30,true); var health: float = f.player.health.current_health
		var nested := [false]
		f.growth.progression_state_changed.connect(func(_v): nested[0] = nested[0] or f.director.choose_route(route))
		check(f.director.choose_route(route) and not f.director.choose_route(route) and not nested[0],"route reentrancy repeats rewards")
		if route==&"supply": check(f.growth.coins==coins+12 and f.player.health.current_health==health+20,"actual supply incorrect")
		else:
			check(f.growth.coins==coins,"risk bonus prepaid")
			await clear_encounter(f,4)
			check(f.growth.coins>coins+35,"risk debt/kill coins/bonus not real")
		check(f.director.state==f.director.State.BOSS_READY and f.director._boss_available() and clears==0 and not f.map.rift_field.active,"actual Boss-ready gate clears early or keeps faults")
		check(f.director.begin_boss() and not f.director.begin_boss(),"actual Observer cannot start or duplicates")
		var boss = f.director.get_active_boss()
		check(boss.get_script()==load("res://scripts/actors/RiftObserverBoss.gd") and boss.get_visual_node().skeleton.get_bone_count()==30 and boss.scale==Vector2.ONE and boss.health.max_health==10800,"actual Observer replaced or native body/statistics altered")
		check(boss.body_radius==56 and f.map.layout.is_position_walkable(boss.global_position,boss.body_radius) and not f.map.rift_field.active,"actual whole Boss birth embeds terrain or activates field")
		boss.died.emit(boss,999,&"test")
		check(clears==0 and f.director.state==f.director.State.BOSS and not f.director.boss_defeat_pending,"living forged Observer death advances chapter")
		boss.queue_free(); await process_frame; await process_frame
		check(clears==0 and f.director.state==f.director.State.FAILED,"unbeaten Observer exit fabricates clear")
		f.host.free(); await process_frame
	for departure in ["player","enemies","field","director","live_enemy"]:
		var f := fixture(); await tick(); await tick(); f.director.begin_encounter(); f.director._process(1.5)
		var field = f.map.rift_field
		match departure:
			"player": f.player.health.damage(f.player.health.current_health,true)
			"enemies": f.host.remove_child(f.enemies)
			"field": f.map.remove_child(field)
			"director": f.host.remove_child(f.director)
			"live_enemy": f.director.get_active_enemies()[0].queue_free(); await process_frame; await process_frame
		check(not field.active and field.get_children().all(func(n): return not n.enabled),"departure retains fault authority "+departure)
		if departure!="director": check(f.director.state==f.director.State.FAILED and not f.director.finish_reward(),"departure forges clear "+departure)
		if departure=="enemies": f.enemies.free()
		if departure=="field": field.free()
		if departure=="director": f.director.free()
		f.host.free(); await process_frame
	if not failures: print("TEST PASS: RiftEncounterTest %d"%checks)
	quit(1 if failures else 0)
