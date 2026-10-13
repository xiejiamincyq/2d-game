extends "EchoEncounterPolicyTest.gd"
## Sixth chapter policy; parent supplies shared fixture imports/check counters only.
const RiftMap = preload("res://scenes/world/rift_observatory.tscn")
const Cutter = preload("res://scripts/actors/SpaceCutterEnemy.gd")
const Elite = preload("res://scripts/actors/RiftEliteEnemy.gd")
const Observer = preload("res://scripts/actors/RiftObserverBoss.gd")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftEncounterPolicyTest "+label)
func run() -> void:
	var path := "res://scripts/systems/RiftEncounterDirector.gd"
	check(ResourceLoader.exists(path),"actual sixth mixed encounter authority missing")
	if failures: quit(1); return
	var Director = load(path); var original: Array = []; var policies: Array = []
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1,521]:
		var host := Node2D.new(); root.add_child(host)
		var map = RiftMap.instantiate(); map.map_seed = seed_value; host.add_child(map)
		var player := Player.new(); player.world_bounds = map.layout.world_bounds; host.add_child(player); player.set_physics_process(false)
		var growth := Growth.new(); host.add_child(growth); growth.setup(player)
		var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
		for layer in [enemies,shots,portals]: host.add_child(layer)
		var director = Director.new(); host.add_child(director); director.set_process(false)
		check(director is Shared and director._chapter_number()==6,"copied lifecycle or wrong chapter")
		check(not director.start_run(seed_value,player,enemies,shots,portals,growth,map.layout),"unbound field starts")
		check(not director.bind_rift_field(map.floor_view) and director.bind_rift_field(map.rift_field),"foreign owner accepted or actual refused")
		check(not director.start_run(seed_value,player,enemies,shots,portals,growth,null),"foreign navigation accepted")
		check(director.start_run(seed_value,player,enemies,shots,portals,growth,map.layout),"current run refused")
		check(not director.start_run(seed_value,player,enemies,shots,portals,growth,map.layout) and not director.bind_rift_field(map.rift_field),"duplicate start/live rebind")
		check(director.state==director.State.INTRO and director.encounters.size()==3 and not map.rift_field.active,"intro not safe")
		var copy: Dictionary = director.get_encounter(); copy.cutter = 9999
		check(director.get_encounter().cutter<9999,"getter mutates authority")
		for index in 3:
			var encounter: Dictionary = director.encounters[index]
			var kinds: Array = director._encounter_kinds(encounter)
			check(kinds.count(director.EnemyScript.EnemyKind.SCRAPPER)==encounter.cutter and kinds.count(director.EnemyScript.EnemyKind.SPITTER)==encounter.elite,"mixed role debt differs from catalog")
			check(encounter.cutter in range([6,8,12][index],[9,11,15][index]) and encounter.elite in range([4,6,9][index],[6,8,12][index]),"counts not finite increasing candidate")
			check(is_equal_approx(encounter.rate,[0.28,0.26,0.24][index]),"spawn intervals differ from contract")
		if seed_value==521:
			if original.is_empty(): original = director.encounters.duplicate(true)
			else: check(original==director.encounters,"same seed changes pressure")
		policies.append(director.encounters.duplicate(true))
		for kind in [director.EnemyScript.EnemyKind.SCRAPPER,director.EnemyScript.EnemyKind.SPITTER]:
			var actor = director._create_enemy_actor(kind); enemies.add_child(actor)
			check((actor is Cutter if kind==director.EnemyScript.EnemyKind.SCRAPPER else actor is Elite) and actor.native_visual!=null and actor.should_show_health_bar(),"native family/body/full healthbar substituted")
			check(actor.body_radius==(14 if actor is Cutter else 16) and actor.speed==(112 if actor is Cutter else 125) and actor.world_bounds==map.layout.world_bounds,"current role physical body altered")
			actor.free()
		check(director._create_enemy_actor(director.EnemyScript.EnemyKind.BRUISER)==null,"foreign role substitutes")
		var boss = director._create_boss_actor()
		check(director._boss_available() and boss is Observer,"actual verified Observer factory unavailable or legacy substituted")
		check(not director.begin_boss(),"intro bypasses actual Boss-ready gate")
		if is_instance_valid(boss): boss.free()
		check(not director.restore_stable_boundary(6,"combat") and not director.begin_prepared_wave() and not director.complete_final_wave(),"old waves bypass chapter")
		map.remove_child(map.rift_field)
		check(director.state==director.State.FAILED and not director.finish_reward(),"field departure leaves advancement authority")
		map.rift_field.free(); host.free(); await process_frame
	check(policies.any(func(value): return value!=original),"seed never varies candidate pressure")
	if not failures: print("TEST PASS: RiftEncounterPolicyTest %d"%checks)
	quit(1 if failures else 0)
