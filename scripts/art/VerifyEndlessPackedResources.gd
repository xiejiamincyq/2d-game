extends SceneTree
## External fixture for the actual exported PCK, never a workspace-only proof.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Rules = preload("res://scripts/systems/CampaignLoopRules.gd")
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const Trap = preload("res://scripts/world/ReusableStepTrap.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyEndlessPackedResources " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for path in ["scripts/tests/fixtures/LegacyWaveMain.gd", "scripts/tests/fixtures/LegacyWaveDirector.gd", "scripts/tests/fixtures/LegacyRunSnapshotStore.gd", "scripts/tests/fixtures/LegacyCampaignStartScreen.gd", "scripts/tests/fixtures/LegacyGameUI.gd", "scripts/tests/CampaignLegacyRetirementTest.gd", "scripts/art/VerifyEndlessPackedResources.gd", "scripts/systems/WaveDirector.gd", "scripts/systems/RunSnapshotStore.gd"]:
		check(not ResourceLoader.exists("res://"+path), "excluded or retired resource present: "+path)
	for path in ["docs/campaign-endless-upgrade-spec-v1.md", "assets/audio/overdrive_bone_breaking.mp3"]:
		check(not FileAccess.file_exists("res://"+path), "non-runtime source present: "+path)
	# Refuse the workspace before instantiating any world or touching user data.
	if failures:
		quit(1)
		return
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Node2D.new()
	arena.add_child(target)
	var shots := Node2D.new()
	shots.process_mode = Node.PROCESS_MODE_DISABLED
	arena.add_child(shots)
	for chapter in range(1,7):
		var definition := Definitions.get_definition(chapter)
		check(not definition.is_empty(), "compiled chapter definition "+str(chapter))
		var map: Node = definition.map.instantiate()
		map.map_seed = 521
		arena.add_child(map)
		var expected_buildings: int = map.layout.get_obstacle_descriptors().size()
		check(expected_buildings>0, "actual compiled map geometry "+str(chapter))
		var buildings := 0
		for node in get_nodes_in_group(&"destructible_terrain"):
			if node is StaticBody2D and map.is_ancestor_of(node):
				buildings += 1
				check(node.health.current_health>0 and not node.is_in_group(&"enemies"), "compiled building HP and ownership")
		check(buildings==expected_buildings, "every compiled building has HP "+str(chapter))
		var director: Node = definition.director.new()
		check(director.has_method("setup_combat") and not director.has_method("begin_wave"), "compiled campaign-only combat core "+str(chapter))
		check(director.configure_loop(2) and director.run_loop==2, "compiled endless configuration "+str(chapter))
		director.free()
		map.free()
	for role in Rules.ROLES:
		var actor: Node = Factory.create_actor(role.chapter,role.role,0,shots,target)
		arena.add_child(actor)
		actor.set_physics_process(false)
		check(actor.native_visual!=null and actor.native_visual.skeleton.get_bone_count()>0 and actor.should_show_health_bar(), "compiled native role and bar: "+role.role)
		actor.free()
	var plate := Trap.new()
	arena.add_child(plate)
	plate.set_physics_process(false)
	check(plate.health.max_health==80 and not plate.is_in_group(&"enemies"), "compiled 80HP non-enemy pressure plate")
	check(Trap.WARNING_SECONDS==0.5 and Trap.DAMAGE==20 and Trap.COOLDOWN_SECONDS==1.5, "compiled reusable trap timing and damage")
	plate.free()
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	main.audio_enabled = false
	main.campaign_store_path = "user://endless_pack_readonly_%d_%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	var isolated_path: String = main.campaign_store_path
	for suffix in ["", ".bak", ".tmp", ".journey", ".journey.bak", ".journey.tmp"]:
		check(not FileAccess.file_exists(isolated_path+suffix), "fresh readonly tent fixture")
	arena.add_child(main)
	check(main.campaign_storage_ok and main.campaign_session.journey.get_entry()=={"loop":1,"chapter":1}, "compiled blank-save tent entry")
	check(main.get("run_state")==null and main.get("player")==null and not main.has_method("_start_run"), "compiled tent has no old world or mode")
	check(main.ui.start_screen.page==main.ui.start_screen.Page.COVER and main.ui.start_screen.Page.size()==3, "compiled campaign-only menu")
	main.audio.begin_shutdown()
	while not main.audio.is_shutdown_complete(): await process_frame
	main.free()
	for suffix in ["", ".bak", ".tmp", ".journey", ".journey.bak", ".journey.tmp"]:
		check(not FileAccess.file_exists(isolated_path+suffix), "readonly tent did not create progress")
	arena.free()
	await process_frame
	if failures==0: print("TEST PASS: VerifyEndlessPackedResources %d" % checks)
	quit(1 if failures else 0)
