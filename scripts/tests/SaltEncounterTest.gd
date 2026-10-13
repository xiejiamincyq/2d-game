extends SceneTree
## Actual roster and reward transactions; forced clearance is a lifecycle fixture.
const Map = preload("res://scenes/world/salt_waterway.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Crab = preload("res://scripts/actors/FlankingCrabEnemy.gd")
var checks := 0
var failures := 0
var clears := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: SaltEncounterTest "+label)
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
	director.chapter_cleared.connect(func(_chapter): clears += 1)
	check(director.bind_tidal_field(map.tidal_field) and director.start_run(seed_value,player,enemies,shots,portals,growth,map.layout),"actual map/families/transactions start")
	return {"host":host,"map":map,"player":player,"director":director,"growth":growth}
func clear_encounter(f: Dictionary,enabled_count: int) -> void:
	var director = f.director
	var policy: Dictionary = director.get_encounter()
	var sites: Array[Rect2] = f.map.tidal_field.get_sites()
	check(director.begin_encounter() and not director.begin_encounter(),"unique encounter start")
	check(f.map.tidal_field.active and f.map.tidal_field.get_children().filter(func(band): return band.enabled).size()==enabled_count,"real tide count does not follow encounter")
	for _step in 100:
		director._process(0.25)
		if director.spawn_queue.is_empty() and director.active_portals.is_empty(): break
	check(director.state==director.State.COMBAT and not director.get_active_enemies().is_empty(),"live enemy debt cleared automatically")
	var counts := {"crab":0,"needle":0}
	for enemy in director.get_active_enemies().duplicate():
		check(enemy.native_visual!=null and enemy.native_visual.skeleton is Skeleton2D,"spawned native skeleton absent")
		check(f.map.layout.is_position_walkable(enemy.global_position,enemy.body_radius),"spawned body inside water/wall")
		check(enemy.should_show_health_bar() and enemy.health.current_health>0,"ordinary enemy health bar absent")
		if enemy is Crab:
			counts.crab += 1
			check(enemy.kind==enemy.EnemyKind.SCRAPPER and enemy.body_radius==16 and enemy.speed==140 and enemy.contact_damage==21,"regional crab setup overwritten")
		else:
			counts.needle += 1
			check(enemy.kind==enemy.EnemyKind.MARKSMAN and enemy.body_radius==14 and enemy.native_visual.skeleton.get_bone_count()==16,"generic pursuer replaces salt needle")
		enemy.died.emit(enemy,999,&"test")
		check(not enemy.get_meta(&"kill_resolved",false),"living forged death granted kill")
	check(counts.crab==policy.crab and counts.needle==policy.needle,"actual two-family count mismatch")
	check(not director.finish_reward() and not director.choose_route(&"supply"),"living enemies permit reward/route")
	# Explicitly force actual death only to exercise collection/reward transactions.
	for enemy in director.get_active_enemies().duplicate(): enemy.take_damage(1e9,&"test")
	await process_frame; await process_frame; director._process(0)
	check(director.state==director.State.COLLECT and not f.map.tidal_field.active,"clear leaves live tide during collection")
	check(f.map.tidal_field.get_sites()==sites,"clear changes ground sites")
	director._process(3.1)
	check(director.state==director.State.REWARD and not f.map.tidal_field.active,"reward not safe")
	check(not director.finish_reward(),"unclaimed build skipped")
	var offer: Dictionary = f.growth.get_settlement_state().families[0].offers[0].duplicate(true)
	var forged := offer.duplicate(true); forged._settlement_transaction = -1; forged.transaction = -1
	check(not director.claim_reward(forged),"forged build transaction")
	check(director.claim_reward(offer) and not director.claim_reward(offer),"build claim must be unique")
	check(director.finish_reward() and not director.finish_reward(),"reward finish must be unique")
func run() -> void:
	var path := "res://scripts/systems/SaltEncounterDirector.gd"
	check(ResourceLoader.exists(path),"salt encounter missing")
	if failures: quit(1); return
	var source = load(path)
	var supply := fixture(source,521)
	await physics_frame; await process_frame
	var first: Dictionary = supply.director.get_encounter()
	await clear_encounter(supply,2); await clear_encounter(supply,2)
	check(supply.director.state==supply.director.State.ROUTE and not supply.map.tidal_field.active,"two battles before cooled choice")
	var coins: int = supply.growth.coins
	supply.player.health.damage(30,true)
	var health: float = supply.player.health.current_health
	var nested := {"accepted":false}
	supply.growth.progression_state_changed.connect(func(_value): nested.accepted = nested.accepted or supply.director.choose_route(&"supply"))
	check(supply.director.choose_route(&"supply"),"supply refused")
	check(not nested.accepted and supply.growth.coins==coins+12 and supply.player.health.current_health==health+20,"supply duplicate/reentrant effects")
	check(not supply.director.choose_route(&"risk") and supply.director.state==supply.director.State.BOSS_READY,"route choice can repeat")
	check(supply.director.begin_boss() and supply.director.get_active_boss()!=null and clears==0,"real Boss absent or start fabricated victory")
	supply.host.free(); await process_frame
	var risk := fixture(source,521); await physics_frame; await process_frame
	check(risk.director.get_encounter()==first,"seeded catalog not deterministic")
	await clear_encounter(risk,2); await clear_encounter(risk,2)
	coins = risk.growth.coins
	check(risk.director.choose_route(&"risk") and risk.growth.coins==coins,"risk reward prepaid")
	check(risk.director.get_encounter().crab>first.crab and risk.director.get_encounter().needle>first.needle,"risk enemy pressure unchanged")
	await clear_encounter(risk,4)
	check(risk.growth.coins==coins+35 and risk.director.state==risk.director.State.BOSS_READY and not risk.map.tidal_field.active and clears==0,"risk clear lacks unique coins or fabricates victory")
	risk.host.free(); await process_frame
	for mode in ["live_enemy","portal","forged_portal","death","director","field"]:
		var f := fixture(source,97); await physics_frame; await process_frame; f.director.begin_encounter()
		match mode:
			"live_enemy":
				for _step in 20:
					f.director._process(0.25)
					if not f.director.get_active_enemies().is_empty(): break
				check(not f.director.get_active_enemies().is_empty(),"missing live cancellation actor")
				if not f.director.get_active_enemies().is_empty(): f.director.get_active_enemies()[0].queue_free()
			"portal": f.director.active_portals[0].queue_free()
			"forged_portal":
				var portal: Node = f.director.active_portals[0]; portal.closed.emit(portal)
			"death": f.player.health.damage(f.player.health.current_health,true)
			"director": f.host.remove_child(f.director)
			"field": f.map.remove_child(f.map.tidal_field)
		await process_frame; await process_frame
		check(not f.map.tidal_field.active and f.map.tidal_field.get_children().all(func(band): return not band.enabled),"cancel mode leaves dangerous tide: "+mode)
		if mode!="director": check(f.director.state==f.director.State.FAILED and not f.director.finish_reward(),"cancel mode can progress: "+mode)
		if mode=="director": f.director.free()
		if mode=="field": f.map.tidal_field.free()
		f.host.free(); await process_frame
	check(clears==0,"S3 emits chapter completion without real Boss")
	if not failures: print("TEST PASS: SaltEncounterTest %d"%checks)
	quit(1 if failures else 0)
