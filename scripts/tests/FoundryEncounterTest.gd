extends SceneTree
## Actual actors/portals/build transactions, manual clearance fixture, not victory.
const Map = preload("res://scenes/world/ember_foundry.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Spark = preload("res://scripts/actors/EmberSparkEnemy.gd")
var checks := 0
var failures := 0
var clears := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: FoundryEncounterTest "+label)
func _initialize() -> void: call_deferred("run")
func fixture(source: Script,seed_value: int) -> Dictionary:
	var host := Node2D.new(); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = seed_value; host.add_child(map)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; host.add_child(player)
	player.set_physics_process(false)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director = source.new(); host.add_child(director); director.set_process(false)
	check(director.bind_heat_field(map.heat_field),"map-owned heat binding")
	director.chapter_cleared.connect(func(_chapter): clears += 1)
	check(director.start_run(seed_value,player,enemies,shots,portals,growth,map.layout),"valid foundry run")
	check(not director.start_run(seed_value,player,enemies,shots,portals,growth,map.layout),"duplicate start refused")
	check(map.heat_field.get_child_count()==16 and not map.heat_field.active,"all sixteen reserved vent sites visible before first fight")
	return {"host":host,"map":map,"player":player,"director":director,"growth":growth,"shots":shots}
func clear_encounter(f: Dictionary,expected_heat: int) -> void:
	var director = f.director
	var catalog: Dictionary = director.get_encounter()
	check(director.begin_encounter() and not director.begin_encounter(),"begin exactly once")
	check(f.map.heat_field.active and f.map.heat_field.get_children().filter(func(child): return child.enabled).size()==expected_heat,"real heat pressure follows encounter")
	for _step in 100:
		director._process(0.25)
		if director.spawn_queue.is_empty() and director.active_portals.is_empty(): break
	check(director.state==director.State.COMBAT and not director.get_active_enemies().is_empty(),"living roster cannot clear")
	var kinds := {}
	for enemy in director.get_active_enemies().duplicate():
		kinds[enemy.kind] = int(kinds.get(enemy.kind,0))+1
		check(enemy.native_visual!=null and enemy.native_visual.skeleton is Skeleton2D and enemy.native_visual.skeleton.get_bone_count()>0,"real native rig missing")
		check(f.map.layout.is_position_walkable(enemy.global_position,enemy.body_radius),"actual spawn in terrain")
		if enemy.kind==enemy.EnemyKind.SPITTER: check(enemy.get_script()==Spark,"spark replaced by generic spitter")
		else: check(enemy.kind==enemy.EnemyKind.DASHER and enemy.charge_attack!=null,"slag charger is ordinary straight pursuer")
		# Forged live signals must never grant loot or authorize clearance.
		enemy.died.emit(enemy,999,&"test")
		check(not enemy.get_meta(&"kill_resolved",false),"forged live death accepted")
	check(kinds.get(director.EnemyScript.EnemyKind.DASHER,0)==catalog.dasher and kinds.get(director.EnemyScript.EnemyKind.SPITTER,0)==catalog.spitter,"actual families/counts disagree with encounter")
	check(not director.finish_reward() and not director.choose_route(&"supply"),"living combat bypassed reward")
	for enemy in director.get_active_enemies().duplicate(): enemy.take_damage(1e9,&"test")
	await process_frame; await process_frame; director._process(0)
	check(director.state==director.State.COLLECT and not f.map.heat_field.active,"clear synchronously disables heat")
	check(f.map.heat_field.get_children().all(func(child): return not child.enabled),"collection still has live hazards")
	director._process(3.1)
	check(director.state==director.State.REWARD and not f.map.heat_field.active,"actual build reward with cooling floor")
	check(not director.finish_reward(),"unclaimed reward skipped")
	var reward: Dictionary = f.growth.get_settlement_state()
	var offer: Dictionary = reward.families[0].offers[0].duplicate(true)
	var stale := offer.duplicate(true); stale._settlement_transaction = -1; stale.transaction = -1
	check(not director.claim_reward(stale),"forged transaction accepted")
	check(director.claim_reward(offer) and not director.claim_reward(offer),"unique genuine build offer")
	check(director.finish_reward() and not director.finish_reward(),"unique reward completion")
func run() -> void:
	var path := "res://scripts/systems/FoundryEncounterDirector.gd"
	check(ResourceLoader.exists(path),"foundry encounter director missing")
	if failures: quit(1); return
	var source = load(path)
	check(source!=null and source.can_instantiate(),"director parse")
	if failures: quit(1); return
	var supply := fixture(source,521)
	var first: Dictionary = supply.director.get_encounter()
	check(first.id==&"slag_workshop" and supply.director._chapter_number()==2,"actual second chapter identity")
	await clear_encounter(supply,10); await clear_encounter(supply,10)
	check(supply.director.state==supply.director.State.ROUTE and not supply.map.heat_field.active,"two required battles lead to cool choice")
	var coins: int = supply.growth.coins
	supply.player.health.damage(30,true)
	var health: float = supply.player.health.current_health
	var nested := {"accepted":false}
	supply.growth.progression_state_changed.connect(func(_value): nested.accepted = nested.accepted or supply.director.choose_route(&"supply"))
	check(supply.director.choose_route(&"supply"),"supply route")
	check(not nested.accepted and supply.growth.coins==coins+12 and supply.player.health.current_health==health+20,"supply actual effects once, no reentrant double reward")
	check(not supply.director.choose_route(&"risk"),"cannot repeat choice")
	check(supply.director.state==supply.director.State.BOSS_READY and supply.director.begin_boss() and not supply.director.begin_boss() and clears==0,"real Boss start once without chapter clear")
	check(supply.director.get_active_boss().get_script().resource_path.ends_with("FoundryFurnaceBoss.gd"),"supply route substitutes old Boss")
	supply.host.free(); await process_frame
	var risk := fixture(source,521)
	check(risk.director.get_encounter()==first,"same seeded encounter changed")
	await clear_encounter(risk,10); await clear_encounter(risk,10)
	coins = risk.growth.coins
	check(risk.director.choose_route(&"risk") and risk.growth.coins==coins,"risk reward not prepaid")
	check(risk.director.get_encounter().dasher>first.dasher and risk.director.get_encounter().spitter>first.spitter,"risk actual enemy pressure")
	await clear_encounter(risk,16)
	check(risk.growth.coins==coins+35 and risk.director.state==risk.director.State.BOSS_READY and clears==0,"risk cleared pays exactly once, no fake chapter clear")
	risk.host.free(); await process_frame
	var cancelled := fixture(source,-1); cancelled.director.begin_encounter()
	for _step in 20:
		cancelled.director._process(0.25)
		if not cancelled.director.get_active_enemies().is_empty(): break
	check(not cancelled.director.get_active_enemies().is_empty(),"real cancellation enemy")
	if not cancelled.director.get_active_enemies().is_empty(): cancelled.director.get_active_enemies()[0].queue_free()
	await process_frame; await process_frame
	check(cancelled.director.state==cancelled.director.State.FAILED and not cancelled.map.heat_field.active and clears==0,"removed living enemy fails and cancels heat")
	cancelled.host.free(); await process_frame
	var removed_portal := fixture(source,13); removed_portal.director.begin_encounter()
	check(not removed_portal.director.active_portals.is_empty(),"real portal cancellation fixture")
	if not removed_portal.director.active_portals.is_empty(): removed_portal.director.active_portals[0].queue_free()
	await process_frame; await process_frame
	check(removed_portal.director.state==removed_portal.director.State.FAILED and not removed_portal.map.heat_field.active,"pending portal removed must not erase enemy debt")
	removed_portal.host.free(); await process_frame
	var forged_portal := fixture(source,29); forged_portal.director.begin_encounter()
	if not forged_portal.director.active_portals.is_empty():
		var portal: Node = forged_portal.director.active_portals[0]
		portal.closed.emit(portal)
	check(forged_portal.director.state==forged_portal.director.State.FAILED and not forged_portal.map.heat_field.active,"forged early closure must not bypass pending enemy debt")
	forged_portal.host.free(); await process_frame
	var death := fixture(source,7); death.director.begin_encounter()
	death.player.health.damage(1e9,true)
	check(death.director.state==death.director.State.FAILED and not death.map.heat_field.active,"death cancels encounter heat synchronously")
	check(not death.director.finish_reward() and not death.director.choose_route(&"supply") and clears==0,"dead player receives no reward/clear")
	death.host.free(); await process_frame
	var exit_case := fixture(source,97); exit_case.director.begin_encounter()
	exit_case.host.remove_child(exit_case.director)
	check(not exit_case.map.heat_field.active,"director departure cancels owned heat")
	exit_case.director.free(); exit_case.host.free(); await process_frame
	var lost_floor := fixture(source,123); lost_floor.director.begin_encounter()
	var detached_floor: Node = lost_floor.map.heat_field
	lost_floor.map.remove_child(detached_floor)
	check(lost_floor.director.state==lost_floor.director.State.FAILED and not detached_floor.active,"lost map hazard ownership aborts encounter synchronously")
	detached_floor.free(); lost_floor.host.free(); await process_frame
	if not failures: print("TEST PASS: FoundryEncounterTest %d"%checks)
	quit(1 if failures else 0)
