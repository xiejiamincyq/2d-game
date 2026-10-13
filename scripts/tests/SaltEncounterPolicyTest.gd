extends SceneTree
## Chapter policy and actual map binding, not fabricated chapter victory.
const Map = preload("res://scenes/world/salt_waterway.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Shared = preload("res://scripts/systems/ChapterEncounterDirector.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: SaltEncounterPolicyTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scripts/systems/SaltEncounterDirector.gd"
	check(ResourceLoader.exists(path),"salt chapter encounter policy missing")
	if failures: quit(1); return
	var source = load(path)
	check(source!=null and source.can_instantiate(),"salt policy parse")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; host.add_child(player)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var director = source.new(); host.add_child(director)
	check(director is Shared and director._chapter_number()==3,"shared lifecycle and chapter identity")
	check(not director.start_run(521,player,enemies,shots,portals,growth,map.layout),"missing tide owner accepted")
	check(not director.bind_tidal_field(map.floor_view),"wrong field type accepted")
	check(director.bind_tidal_field(map.tidal_field),"actual field binding refused")
	check(director.start_run(521,player,enemies,shots,portals,growth,map.layout),"actual seeded run refused")
	check(not director.start_run(521,player,enemies,shots,portals,growth,map.layout),"duplicate run")
	check(not director.bind_tidal_field(map.tidal_field),"combat policy owner mutable after start")
	check(director.encounters.size()==3 and director.state==director.State.INTRO,"required battles and risk catalog")
	check(map.tidal_field.get_child_count()==4 and not map.tidal_field.active,"intro creates active or absent channels")
	var first: Dictionary = director.get_encounter()
	first.crab = 9999
	check(director.get_encounter().crab<9999,"catalog query leaks writable state")
	for encounter in director.encounters:
		var kinds: Array[int] = director._encounter_kinds(encounter)
		check(kinds.count(director.EnemyScript.EnemyKind.SCRAPPER)==encounter.crab and kinds.count(director.EnemyScript.EnemyKind.MARKSMAN)==encounter.needle,"salt families/counts differ from policy")
	check(director._boss_available() and not director.begin_boss(),"real Boss bypasses INTRO encounter gate")
	check(not director.restore_stable_boundary(3,"combat") and not director.begin_prepared_wave() and not director.complete_final_wave(),"legacy wave bypass")
	map.remove_child(map.tidal_field)
	check(director.state==director.State.FAILED,"owner removal does not fail run")
	map.tidal_field.free(); host.free(); await process_frame
	if not failures: print("TEST PASS: SaltEncounterPolicyTest %d"%checks)
	quit(1 if failures else 0)
