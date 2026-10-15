extends "RenderVineGuardAttackEffects.gd"
## Actual first-chapter map/native actors; controlled clocks, not human playtest.
const Map = preload("res://scenes/world/mist_nursery.tscn")
const PlayerActor = preload("res://scripts/actors/Player.gd")
func step_boss(boss: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); boss._physics_process(dt); remaining -= dt
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh GPU output required")
	if failed: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderNurseryRootReadability.gd","scripts/art/RenderVineGuardAttackEffects.gd","scripts/components/VineGuardAttackDirector.gd","scripts/components/NativeVineGuardMotion.gd","scripts/systems/NurseryEncounterDirector.gd","scripts/systems/EncounterCombatCore.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var map = Map.instantiate()
	map.map_seed = 521
	viewport.add_child(map)
	var player := PlayerActor.new()
	player.world_bounds = map.layout.world_bounds
	viewport.add_child(player)
	player.set_physics_process(false)
	var shots := Node2D.new()
	viewport.add_child(shots)
	var boss := Boss.new()
	boss.setup(1,shots,player)
	boss.position = Vector2(-260,0)
	boss.world_bounds = map.layout.world_bounds
	viewport.add_child(boss)
	boss.set_physics_process(false)
	await physics_frame
	await physics_frame
	viewport.canvas_transform = Transform2D(0,Vector2(640,360))
	boss._physics_process(1.41)
	var combat = boss.get_attack_director()
	combat.set_health_phase(2)
	boss._physics_process(0.65)
	combat.attack_gap = 99
	await capture("baseline")
	check(combat.start_action(&"roots"),"actual map roots refused")
	step_boss(boss,0.2)
	await capture("warning-early")
	step_boss(boss,0.59)
	check(player.health.current_health==100,"late warning deals damage")
	await capture("warning-late")
	step_boss(boss,0.02)
	check(player.health.current_health==40,"actual central root damage no longer60")
	await capture("center-active")
	step_boss(boss,0.12)
	await capture("second-active")
	step_boss(boss,0.12)
	await capture("third-active")
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed during capture")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"sources":sources,"player_health":player.health.current_health,"root_centers":combat.root_centers,"warning_seconds":0.8,"stagger_seconds":0.12,"scope":"Actual map521/native Boss and Player,6 GPU captures with controlled authoritative clocks; not ordinary victory or OS input"},"\t"))
	file.close()
	viewport.free()
	await process_frame
	print("NURSERY ROOT GPU %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
