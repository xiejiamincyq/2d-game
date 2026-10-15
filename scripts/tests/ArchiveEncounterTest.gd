extends SceneTree
## Actual map/actors/build transactions; direct kills are lifecycle tests, not playtest.
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/ArchiveEncounterDirector.gd")
const Mote = preload("res://scripts/actors/SplittingMoteEnemy.gd")
const Planter = preload("res://scripts/actors/CapsulePlanterEnemy.gd")
const Archivist = preload("res://scripts/actors/ArchiveArchivistBoss.gd")
var checks := 0
var failures := 0
var clears := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveEncounterTest "+label)
func _initialize() -> void: call_deferred("run")
func fixture(seed_value: int) -> Dictionary:
	var host := Node2D.new(); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = seed_value; host.add_child(map)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; host.add_child(player); player.set_physics_process(false)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director := Director.new(); host.add_child(director); director.set_process(false)
	director.chapter_cleared.connect(func(_chapter): clears += 1)
	check(director.bind_spore_field(map.spore_field) and director.start_run(seed_value,player,enemies,shots,portals,growth,map.layout),"actual seeded policy start")
	return {"host":host,"map":map,"player":player,"director":director,"growth":growth}
func clear_encounter(f: Dictionary,count: int) -> void:
	var director = f.director; var policy: Dictionary = director.get_encounter()
	check(director.begin_encounter() and not director.begin_encounter(),"encounter start not unique")
	check(f.map.spore_field.active and f.map.spore_field.get_children().filter(func(n): return n.enabled).size()==count,"environment count does not follow encounter")
	for _step in 100:
		director._process(0.25)
		if director.spawn_queue.is_empty() and director.active_portals.is_empty(): break
	var parents: Array[Node] = director.get_active_enemies().duplicate()
	check(director.state==director.State.COMBAT and parents.size()==policy.mote+policy.planter,"actual parents differ from catalog")
	var motes := 0; var planters := 0
	for enemy in parents:
		enemy.set_physics_process(false)
		check(enemy.native_visual!=null and enemy.should_show_health_bar() and f.map.layout.is_position_walkable(enemy.global_position,enemy.body_radius),"actual native body/status/spawn unsafe")
		if enemy is Mote:
			motes += 1; check(not enemy.is_fragment and enemy.native_visual.skeleton.get_bone_count()==16,"parent Mote role/rig replaced")
		elif enemy is Planter:
			planters += 1; check(enemy.native_visual.skeleton.get_bone_count()==20 and enemy.ranged_windup_duration==0.55,"Planter role/human-reactable warning replaced")
		else: check(false,"generic enemy substituted")
		enemy.died.emit(enemy,999,&"test"); check(not enemy.get_meta(&"kill_resolved",false),"living forged kill rewarded")
	check(motes==policy.mote and planters==policy.planter and not director.finish_reward(),"living enemies permit reward")
	for enemy in parents: enemy.take_damage(1000,&"test")
	check(not director.pending_births.is_empty() and director.state==director.State.COMBAT,"parent death has no reserved descendant debt")
	await process_frame; await physics_frame; await process_frame; director._process(0)
	var fragments: Array[Node] = director.get_active_enemies().duplicate()
	check(director.state==director.State.COMBAT and not fragments.is_empty() and fragments.size()<=motes*2,"parent deaths cleared before actual fragments")
	check(director.pending_births.is_empty() and not director.finish_reward(),"living fragments permit reward")
	for child in fragments:
		child.set_physics_process(false)
		check(child is Mote and child.is_fragment and child.coin_value==0 and child.body_radius==9 and child.should_show_health_bar(),"tracked small fragment contract wrong")
		check(f.map.layout.is_position_walkable(child.global_position,9),"actual child born in shelf")
		child.take_damage(1000,&"test"); child.take_damage(1000,&"test")
	await process_frame; await process_frame; director._process(0)
	check(director.state==director.State.COLLECT and not f.map.spore_field.active and director.pending_births.is_empty(),"clear leaves descendants/environment active")
	check(get_nodes_in_group(&"capsule_plants").is_empty(),"dead Planters leave owned hazards")
	director._process(3.1)
	check(director.state==director.State.REWARD and not director.finish_reward(),"collection lacks unclaimed safe reward")
	var offer: Dictionary = f.growth.get_settlement_state().families[0].offers[0].duplicate(true)
	var forged := offer.duplicate(true); forged._settlement_transaction = -1; forged.transaction = -1
	check(not director.claim_reward(forged) and director.claim_reward(offer) and not director.claim_reward(offer),"build transaction accepts forgery/duplicate")
	check(director.finish_reward() and not director.finish_reward(),"reward finish duplicate")
func run() -> void:
	var f := fixture(521); await physics_frame; await process_frame
	var first: Dictionary = f.director.get_encounter()
	await clear_encounter(f,2); await clear_encounter(f,2)
	check(f.director.state==f.director.State.ROUTE and not f.map.spore_field.active,"two mandatory battles before cooled choice")
	var coins: int = f.growth.coins; f.player.health.damage(30,true); var health: float = f.player.health.current_health
	var nested := [false]
	f.growth.progression_state_changed.connect(func(_v): nested[0] = nested[0] or f.director.choose_route(&"supply"))
	check(f.director.choose_route(&"supply") and not nested[0] and f.growth.coins==coins+12 and f.player.health.current_health==health+20,"supply not unique/reentrant safe")
	check(f.director.state==f.director.State.BOSS_READY and f.director.begin_boss() and f.director.get_active_boss() is Archivist and clears==0,"supply route substitutes Boss or fabricates victory")
	f.host.free(); await process_frame
	f = fixture(521); await physics_frame; await process_frame
	check(f.director.get_encounter()==first,"same seed changes policy")
	await clear_encounter(f,2); await clear_encounter(f,2); coins = f.growth.coins
	check(f.director.choose_route(&"risk") and f.growth.coins==coins,"risk coins prepaid")
	await clear_encounter(f,4)
	check(f.growth.coins==coins+35 and f.director.state==f.director.State.BOSS_READY and f.director.begin_boss() and f.director.get_active_boss() is Archivist and clears==0,"risk currency duplicate or fake Boss completion")
	f.host.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveEncounterTest %d"%checks)
	quit(1 if failures else 0)
