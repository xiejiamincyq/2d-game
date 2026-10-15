extends SceneTree
## Product entry and dependency boundaries, not deletion of player save files.
const Main=preload("res://scripts/Main.gd")
const Definitions=preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Support=preload("TestSupport.gd")
const CORE="res://scripts/systems/EncounterCombatCore.gd"
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: CampaignLegacyRetirementTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var protected: Dictionary={}
	for base in ["user://five_minute_overdrive_run_v1.json","user://five_minute_overdrive_campaign_v1.json","user://five_minute_overdrive_journey_v1.json"]:
		for suffix in ["",".bak",".tmp"]: protected[base+suffix]=hash_of(base+suffix)
	var scene:=Main.new(); scene.audio_enabled=false
	scene.campaign_store_path="user://retirement_missing_%d_%d.json"%[OS.get_process_id(),Time.get_ticks_usec()]
	root.add_child(scene)
	check(scene.get_node_or_null("World")==null,"tent must not instantiate unused legacy arena")
	check(scene.get("snapshot_store")==null,"tent must not create or read old wave snapshot manager")
	for method in [&"_start_run",&"_continue_run",&"_begin_run",&"_save_stable_snapshot",&"_on_victory"]:
		check(not scene.has_method(method),"retired Main callable remains "+String(method))
	var menu: Node=scene.ui.start_screen
	check(not menu.has_signal("legacy_start_requested") and menu.get("legacy_button")==null,"compatibility menu removed, not merely hidden")
	check(not menu.has_method("_legacy_start") and menu.get("_legacy_panel")==null,"compatibility page implementation removed")
	check(not scene.ui.has_signal("legacy_start_requested") and not scene.ui.has_signal("continue_requested"),"old wave request routes removed")
	var common: Script=load("res://scripts/systems/ChapterEncounterDirector.gd")
	check(ResourceLoader.exists(CORE),"shared combat core missing")
	check(common.get_base_script().resource_path==CORE,"chapters still inherit old wave implementation")
	if ResourceLoader.exists(CORE):
		var core: Node=load(CORE).new()
		check(core.has_method("setup_combat") and core.has_method("_spawn_enemy_at") and core.has_method("_register_enemy"),"shared spawn/ownership machinery preserved")
		for method in [&"prepare_next_wave",&"restore_stable_boundary",&"complete_final_wave"]: check(not core.has_method(method),"wave progression leaked into core")
		core.free()
	for chapter in range(1,7):
		var director: Node=Definitions.get_definition(chapter).director.new()
		check(director.has_method("configure_loop") and director.has_method("start_run"),"actual six chapter entry retained")
		director.free()
	Support.stop_audio(scene.audio); scene.free(); paused=false; await process_frame
	for path in protected: check(hash_of(path)==protected[path],"default save changed "+path)
	if failures==0: print("TEST PASS: CampaignLegacyRetirementTest %d"%checks)
	quit(1 if failures else 0)
func hash_of(path: String) -> String: return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"
