extends SceneTree
const Map = preload("res://scenes/world/echo_court.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Shared = preload("res://scripts/systems/ChapterEncounterDirector.gd")
const Sentinel = preload("res://scripts/actors/EchoSentinelEnemy.gd")
const Shade = preload("res://scripts/actors/CirclingShadeEnemy.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoEncounterPolicyTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scripts/systems/EchoEncounterDirector.gd"
	check(ResourceLoader.exists(path),"actual fifth-region encounter owner missing")
	if failures: quit(1); return
	var Director = load(path); var original: Array = []; var policies: Array = []
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1,521]:
		var host := Node2D.new(); root.add_child(host)
		var map = Map.instantiate(); map.map_seed = seed_value; host.add_child(map)
		var player := Player.new(); player.world_bounds = map.layout.world_bounds; host.add_child(player); player.set_physics_process(false)
		var growth := Growth.new(); host.add_child(growth); growth.setup(player)
		var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
		for layer in [enemies,shots,portals]: host.add_child(layer)
		var director = Director.new(); host.add_child(director); director.set_process(false)
		check(director is Shared and director._chapter_number()==5,"shared lifecycle/chapter identity")
		check(not director.start_run(seed_value,player,enemies,shots,portals,growth,map.layout),"unbound field accepted")
		check(not director.bind_echo_field(map.floor_view) and director.bind_echo_field(map.echo_field),"wrong/actual field identity")
		check(not director.start_run(seed_value,player,enemies,shots,portals,growth,null),"foreign navigation accepted")
		check(director.start_run(seed_value,player,enemies,shots,portals,growth,map.layout),"actual seeded run refused")
		check(not director.start_run(seed_value,player,enemies,shots,portals,growth,map.layout) and not director.bind_echo_field(map.echo_field),"duplicate start/live rebind")
		check(director.state==director.State.INTRO and director.encounters.size()==3 and not map.echo_field.active,"intro not safe/two mandatory and risk absent")
		var copy: Dictionary = director.get_encounter(); copy.sentinel = 9999
		check(director.get_encounter().sentinel<9999,"mutable authoritative policy")
		for index in 3:
			var encounter: Dictionary = director.encounters[index]
			var kinds: Array = director._encounter_kinds(encounter)
			check(kinds.count(director.EnemyScript.EnemyKind.SPITTER)==encounter.sentinel and kinds.count(director.EnemyScript.EnemyKind.SCRAPPER)==encounter.shade,"real role debt differs from catalog")
			check(encounter.sentinel in range([4,7,9][index],[6,10,12][index]) and encounter.shade in range([6,8,12][index],[9,11,15][index]),"bounded increasing mixed pressure")
			check(is_equal_approx(encounter.rate,[0.26,0.24,0.22][index]),"spawn pace differs from contract")
		if seed_value==521:
			if original.is_empty(): original = director.encounters.duplicate(true)
			else: check(original==director.encounters,"same seed changes role policy")
		policies.append(director.encounters.duplicate(true))
		for kind in [director.EnemyScript.EnemyKind.SPITTER,director.EnemyScript.EnemyKind.SCRAPPER]:
			var actor = director._create_enemy_actor(kind); enemies.add_child(actor)
			check((actor is Sentinel if kind==director.EnemyScript.EnemyKind.SPITTER else actor is Shade) and actor.native_visual!=null and actor.should_show_health_bar(),"real native family/status substituted")
			check(actor.body_radius==(16 if actor is Sentinel else 15) and actor.world_bounds==map.layout.world_bounds,"regional full-body contract")
			actor.free()
		check(director._create_enemy_actor(director.EnemyScript.EnemyKind.BRUISER)==null,"foreign role silently substitutes")
		check(director._boss_available() and not director.begin_boss(),"verified priest unavailable or intro bypasses boss gate")
		check(not director.restore_stable_boundary(5,"combat") and not director.begin_prepared_wave() and not director.complete_final_wave(),"old waves bypass chapter")
		map.remove_child(map.echo_field)
		check(director.state==director.State.FAILED and not director.finish_reward(),"field departure leaves progression authority")
		map.echo_field.free(); host.free(); await process_frame
	check(policies.any(func(value): return value!=original),"seed never varies encounter counts")
	if not failures: print("TEST PASS: EchoEncounterPolicyTest %d"%checks)
	quit(1 if failures else 0)
