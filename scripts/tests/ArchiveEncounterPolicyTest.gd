extends SceneTree
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Shared = preload("res://scripts/systems/ChapterEncounterDirector.gd")
const StepTrap = preload("res://scripts/world/ReusableStepTrap.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveEncounterPolicyTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scripts/systems/ArchiveEncounterDirector.gd"
	check(ResourceLoader.exists(path),"real archive encounter policy missing")
	if failures: quit(1); return
	var source = load(path)
	var host := Node2D.new(); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); host.add_child(player)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var director = source.new(); host.add_child(director); director.set_process(false)
	check(director is Shared and director._chapter_number()==4,"chapter identity/shared transactions absent")
	check(not director.start_run(521,player,enemies,shots,portals,growth,map.layout),"unbound environmental owner accepted")
	check(not director.bind_spore_field(map.floor_view) and director.bind_spore_field(map.spore_field),"wrong field type or actual owner binding")
	check(director.start_run(521,player,enemies,shots,portals,growth,map.layout),"actual fourth-region run refused")
	check(not director.start_run(521,player,enemies,shots,portals,growth,map.layout) and not director.bind_spore_field(map.spore_field),"live policy mutable/duplicate start")
	check(director.encounters.size()==3 and director.state==director.State.INTRO,"two mandatory/one risk policy absent")
	check(not map.spore_field.active and map.spore_field.get_child_count()==10,"all ten reusable sites exist but INTRO is disarmed")
	check(map.spore_field.get_children().all(func(trap): return trap is StepTrap and not trap.enabled and trap.health.current_health==80 and not trap.is_in_group(&"enemies")),"actual safe destructible pressure plates, not old four periodic nests")
	var first: Dictionary = director.get_encounter(); first.mote = 9999
	check(director.get_encounter().mote<9999,"mutable catalog returned")
	for encounter in director.encounters:
		var kinds: Array[int] = director._encounter_kinds(encounter)
		check(kinds.count(director.EnemyScript.EnemyKind.SCRAPPER)==encounter.mote and kinds.count(director.EnemyScript.EnemyKind.SPITTER)==encounter.planter,"real roles/counts differ from policy")
	check(director.encounters[2].mote>director.encounters[0].mote and director.encounters[2].planter>director.encounters[0].planter,"risk does not increase actual pressure")
	check(director._boss_available() and not director.begin_boss(),"actual Boss bypasses mandatory encounters")
	check(not director.has_method("restore_stable_boundary") and not director.has_method("begin_prepared_wave") and not director.has_method("complete_final_wave"),"retired wave/snapshot bypass is absent")
	map.remove_child(map.spore_field)
	check(director.state==director.State.FAILED and not director.finish_reward(),"field departure allows progression")
	map.spore_field.free(); host.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveEncounterPolicyTest %d"%checks)
	quit(1 if failures else 0)
