extends SceneTree
## Real portal queues under backpressure, with no forged enemy deletions.
const Definitions=preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Player=preload("res://scripts/actors/Player.gd")
const Growth=preload("res://scripts/systems/UpgradeSystem.gd")
const Rules=preload("res://scripts/systems/CampaignLoopRules.gd")
const BINDERS=["","bind_heat_field","bind_tidal_field","bind_spore_field","bind_echo_field","bind_rift_field"]
const FIELDS=["TrapField","HeatField","TidalField","SporeField","EchoField","RiftField"]
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: CampaignLoopCapacityTest "+label)
func _initialize() -> void: call_deferred("run")
func remaining(director: Node) -> int:
	var total: int=director.spawn_queue.size()
	for queue in director.portal_spawn_queues.values(): total+=queue.size()
	return total
func run() -> void:
	for chapter in range(1,7): await chapter_case(chapter)
	if failures==0: print("TEST PASS: CampaignLoopCapacityTest %d"%checks)
	quit(1 if failures else 0)
func chapter_case(chapter: int) -> void:
	var host:=Node2D.new(); root.add_child(host)
	var definition: Dictionary=Definitions.get_definition(chapter)
	var map: Node2D=definition.map.instantiate(); map.map_seed=521; host.add_child(map)
	var player:=Player.new(); host.add_child(player); player.set_physics_process(false)
	var growth:=Growth.new(); host.add_child(growth); growth.setup(player)
	var enemies:=Node2D.new(); var shots:=Node2D.new(); var portals:=Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var director: Node=definition.director.new(); host.add_child(director); director.set_process(false)
	check(not director.configure_loop(0) and not director.configure_loop(Rules.MAX_LOOP+1) and director.run_loop==1,"invalid loop leaves default policy unchanged")
	check(director.configure_loop(1000),"extreme loop configured")
	if chapter>1: check(director.call(BINDERS[chapter-1],map.get_node(FIELDS[chapter-1])),"real regional field")
	check(director.start_run(521,player,enemies,shots,portals,growth,map.layout),"real encounter starts")
	check(director.spawn_queue.size()==Rules.MAX_ENCOUNTER_ENEMIES,"bounded full encounter, not huge allocation")
	check(director.begin_encounter(),"real portals opened")
	director._process(100.0) # One large hitch may span warning and full portal life.
	for actor in director.get_active_enemies(): actor.set_physics_process(false)
	for step in 80:
		director._process(0.2)
		for actor in director.get_active_enemies(): actor.set_physics_process(false)
	check(director.get_active_enemies().size()<=Rules.MAX_POPULATION_LOAD,"same-screen actor count bounded")
	check(remaining(director)>0 and not director.active_portals.is_empty() and director.state==director.State.COMBAT,"blocked queues stay alive, not silently closed/cleared")
	if director.has_method("population_load"): check(director.population_load()<=Rules.MAX_POPULATION_LOAD,"future split bodies reserve slots")
	var initial_total: int=remaining(director)+director.get_active_enemies().size()
	# Damage real bodies to release slots; leave movement paused only for this test.
	for generation in 18:
		for actor in director.get_active_enemies().duplicate():
			if actor.has_signal("offspring_prepared") and actor.is_fragment:
				check(actor.get_meta(&"campaign_loop_hp",0)==1000 and is_equal_approx(actor.health.max_health,14*(1+0.13*actor.difficulty_index)*Rules.health_scale(1000)),"real split offspring inherit HP exactly once")
			actor.take_damage(1e9,&"test")
		await process_frame; await process_frame; await physics_frame
		for step in 8:
			director._process(0.2)
			for actor in director.get_active_enemies(): actor.set_physics_process(false)
		check(director.state!=director.State.FAILED,"backpressure never cancels or counterfeits completion")
		if director.has_method("population_load"): check(director.population_load()<=Rules.MAX_POPULATION_LOAD,"bounded after real deaths/fragment admission")
		if remaining(director)==0 and director.get_active_enemies().is_empty() and director.pending_births.is_empty(): break
	check(initial_total==Rules.MAX_ENCOUNTER_ENEMIES,"no initial queued enemies discarded")
	check(remaining(director)==0 and director.get_active_enemies().is_empty() and director.pending_births.is_empty(),"all queued and split offspring eventually settle")
	director._process(0)
	check(director.state==director.State.COLLECT,"only true empty encounter enters collection")
	host.free(); await process_frame
