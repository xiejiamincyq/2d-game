extends SceneTree
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const Roster = preload("res://scripts/campaign/RegionalEnemyRoster.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: SplittingMoteOwnerExitTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena := Node2D.new(); root.add_child(arena)
	var roster := Roster.new()
	var mother := Factory.create_actor(4,"splitting_mote",0,arena)
	mother.world_bounds = Rect2(-650,-450,1300,900); arena.add_child(mother); mother.set_physics_process(false)
	check(roster.register_actor(mother),"actual parent not registered")
	var children: Array[CharacterBody2D] = []
	mother.offspring_prepared.connect(func(values): children.assign(values))
	mother.take_damage(1000,&"test")
	check(children.size()==2 and roster.get_active_count()==2,"real birth debt absent")
	root.remove_child(arena) # Still a valid owner, but no longer part of this world.
	await process_frame; await process_frame
	check(roster.failed and roster.get_active_count()==0,"detached valid owner accepts deferred births")
	check(children.all(func(n): return not is_instance_valid(n)),"rejected descendants leak outside tree")
	arena.free(); await process_frame
	if not failures: print("TEST PASS: SplittingMoteOwnerExitTest %d"%checks)
	quit(1 if failures else 0)
