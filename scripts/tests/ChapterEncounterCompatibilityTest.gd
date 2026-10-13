extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ChapterEncounterCompatibilityTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scripts/systems/ChapterEncounterDirector.gd"
	check(ResourceLoader.exists(path),"shared chapter lifecycle missing")
	if failures: quit(1); return
	var common = load(path)
	check(common!=null and common.can_instantiate(),"shared lifecycle parse")
	if failures: quit(1); return
	var nursery = load("res://scripts/systems/NurseryEncounterDirector.gd")
	check(nursery.get_base_script()==common,"first chapter does not use shared lifecycle")
	for seed_value in [0,521,-1,20261011]:
		var director = nursery.new()
		director.spawn_rng.seed = seed_value
		var data: Array[Dictionary] = director._build_encounters()
		check(director._chapter_number()==1 and director._boss_available(),"first chapter identity/readiness changed")
		check(director._boss_position()==Vector2(0,-500) and director._boss_label()==director.BOSS_LABEL,"first boss position/label changed")
		check(data.size()==3 and data[0].id==&"root_outskirts" and data[1].id==&"spore_beds" and data[2].id==&"overgrown_detour","first encounter identities changed")
		check(data[0].scrapper>=14 and data[0].scrapper<=18 and data[0].spitter>=2 and data[0].spitter<=3,"first enemy counts changed")
		for encounter in data:
			var kinds: Array[int] = director._encounter_kinds(encounter)
			check(kinds.size()==encounter.scrapper+encounter.spitter,"first spawn queue count changed")
			check(kinds.count(director.EnemyScript.EnemyKind.SCRAPPER)==encounter.scrapper and kinds.count(director.EnemyScript.EnemyKind.SPITTER)==encounter.spitter,"first family mapping changed")
		director.spawn_rng.seed = seed_value
		check(director._build_encounters()==data,"first seeded catalog changed")
		director.free()
	await process_frame
	if not failures: print("TEST PASS: ChapterEncounterCompatibilityTest %d"%checks)
	quit(1 if failures else 0)
