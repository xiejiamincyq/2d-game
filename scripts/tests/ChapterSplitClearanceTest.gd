extends SceneTree
## Real fourth-region Mote through shared spawning; direct damage is a lifecycle fixture.
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
class ProbeDirector extends "res://scripts/systems/ChapterEncounterDirector.gd":
	const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
	func _build_encounters() -> Array[Dictionary]: return [{"rate":0.2},{"rate":0.2},{"rate":0.2}]
	func _encounter_kinds(_data: Dictionary) -> Array[int]: return [EnemyScript.EnemyKind.SCRAPPER]
	func _create_enemy_actor(_kind: int) -> Node:
		var actor := Factory.create_actor(4,"splitting_mote",0,projectile_parent,player)
		actor.world_bounds = world_bounds; actor.set_physics_process(false); return actor
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ChapterSplitClearanceTest "+label)
func _initialize() -> void: call_deferred("run")
func fixture() -> Dictionary:
	var host := Node2D.new(); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); host.add_child(player); player.set_physics_process(false)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director := ProbeDirector.new(); host.add_child(director); director.set_process(false)
	check(director.start_run(521,player,enemies,shots,portals,growth,map.layout) and director.begin_encounter(),"real shared start")
	for _step in 100:
		director._process(0.25)
		if director.spawn_queue.is_empty() and director.active_portals.is_empty(): break
	check(director.get_active_enemies().size()==1 and director.spawn_queue.is_empty() and director.active_portals.is_empty(),"fixture not a last actual Mote")
	return {"host":host,"map":map,"player":player,"enemies":enemies,"director":director,"growth":growth}
func run() -> void:
	var f := fixture(); await physics_frame; await process_frame
	var director = f.director; var mother = director.get_active_enemies()[0]
	var children: Array[CharacterBody2D] = []
	mother.offspring_prepared.connect(func(values): children.assign(values))
	var kills := [0]; var coins := [0]
	director.enemy_killed.connect(func(_enemy,_source,value): kills[0]+=1; coins[0]+=value)
	mother.take_damage(1000,&"test")
	check(children.size()==2 and children.all(func(n): return not n.is_inside_tree()),"real two deferred children absent")
	check(kills[0]==1 and coins[0]==3,"parent reward missing/duplicated")
	await process_frame; await physics_frame; await process_frame; director._process(0)
	check(director.state==director.State.COMBAT,"last parent clears before offspring defeated")
	check(director.get_active_enemies().size()==2 and children.all(func(n): return director.get_active_enemies().has(n)),"actual children absent from shared clearance ledger")
	check(not director.finish_reward() and not director.choose_route(&"supply"),"living offspring permit settlement")
	for child in children:
		child.set_physics_process(false)
		check(child.is_inside_tree() and child.is_fragment and child.native_visual.skeleton.get_bone_count()==16 and child.should_show_health_bar(),"real fragment resource/status absent")
		check(director._get_enemy_neighbors(child).size()==1,"fragment social neighbors absent")
	for child in children:
		child.take_damage(1000,&"test"); child.take_damage(1000,&"test")
	await process_frame; await process_frame; director._process(0)
	check(director.state==director.State.COLLECT and kills[0]==3 and coins[0]==3,"fragment deaths fail clear or duplicate parent currency")
	f.host.free(); await process_frame
	for mode in ["duplicate","pause","death","reentrant_death","destination_detach","destination_queue","player_detach","player_queue","director_detach"]:
		f = fixture(); await physics_frame; await process_frame
		director = f.director; mother = director.get_active_enemies()[0]
		var prepared: Array[CharacterBody2D] = []
		mother.offspring_prepared.connect(func(values): prepared.assign(values))
		if mode=="reentrant_death": director.enemy_killed.connect(func(_n,_s,_v): f.player.health.damage(f.player.health.current_health,true))
		mother.take_damage(1000,&"test")
		check(prepared.size()==2,"cancellation fixture lacks prepared births: "+mode)
		match mode:
			"duplicate":
				mother.offspring_prepared.emit(prepared); mother.offspring_prepared.emit(prepared)
				check(director.pending_births.size()==2 and prepared.all(func(n): return not n.is_queued_for_deletion()),"duplicate callbacks cancel/double pending debt")
			"pause": paused = true
			"death": f.player.health.damage(f.player.health.current_health,true)
			"destination_detach":
				f.host.remove_child(f.enemies)
				check(director.state==director.State.FAILED and director.pending_births.is_empty(),"destination departure is not immediate cancellation")
			"destination_queue": f.enemies.queue_free()
			"player_detach":
				f.host.remove_child(f.player)
				check(director.state==director.State.FAILED and director.pending_births.is_empty(),"player departure is not immediate cancellation")
			"player_queue": f.player.queue_free()
			"director_detach": f.host.remove_child(director)
		await process_frame; await physics_frame; await process_frame
		if mode in ["duplicate","pause"]:
			check(director.state==director.State.COMBAT and director.pending_births.is_empty() and director.get_active_enemies().size()==2,"legitimate paused/duplicate births lost or clear early")
			check(prepared.all(func(n): return is_instance_valid(n) and n.is_inside_tree() and director.get_active_enemies().has(n)),"actual live descendants unregistered")
			paused = false
		else:
			check(prepared.all(func(n): return not is_instance_valid(n)),"cancelled birth remains alive/outside tree: "+mode)
			check(director.pending_births.is_empty() and not director.finish_reward(),"cancelled birth debt produces reward: "+mode)
			if mode!="director_detach": check(director.state==director.State.FAILED,"cancelled battle not failed: "+mode)
		if mode=="destination_detach": f.enemies.free()
		if mode=="player_detach": f.player.free()
		if mode=="director_detach": director.free()
		f.host.free(); await process_frame
	if not failures: print("TEST PASS: ChapterSplitClearanceTest %d"%checks)
	quit(1 if failures else 0)
