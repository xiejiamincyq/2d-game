extends SceneTree
## Real automatic encounter clock and ordinary movement; no victory fabrication.
const Map = preload("res://scenes/world/ember_foundry.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/FoundryEncounterDirector.gd")
const Spark = preload("res://scripts/actors/EmberSparkEnemy.gd")
const Support = preload("res://scripts/tests/TestSupport.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: FoundryEncounterRuntimeTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host := Node2D.new(); host.process_mode = Node.PROCESS_MODE_PAUSABLE; root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; host.add_child(player)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director := Director.new(); host.add_child(director)
	check(director.bind_heat_field(map.heat_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout) and director.begin_encounter(),"actual automatic encounter starts")
	var fans := {"shots":0}
	shots.child_entered_tree.connect(func(_shot): fans.shots += 1)
	var moved := 0
	var charger_warning := false
	var charger_active := false
	var spark_warning := false
	var oldest_charge := -1
	var earliest_charge := -1
	var started := Time.get_ticks_msec()
	var direction_index := -1
	var actions := ["move_up","move_right","move_down","move_left"]
	while Time.get_ticks_msec()-started<10000 and player.health.current_health>0:
		var next := int((Time.get_ticks_msec()-started)/280)%4
		if next!=direction_index:
			for action in actions: Input.action_release(action)
			Input.action_press(actions[next]); direction_index = next
		var previous := player.position
		await physics_frame; await process_frame
		moved += 1 if player.position.distance_to(previous)>0.01 else 0
		for enemy in director.get_active_enemies():
			if enemy is Spark: spark_warning = spark_warning or enemy.ranged_is_winding_up
			elif enemy.kind==enemy.EnemyKind.DASHER:
				var charge = enemy.charge_attack
				if charge.stage==charge.Stage.WARNING and oldest_charge==-1:
					oldest_charge = enemy.get_instance_id(); earliest_charge = Time.get_ticks_msec()
				charger_warning = charger_warning or charge.stage==charge.Stage.WARNING
				if charge.stage==charge.Stage.ACTIVE:
					charger_active = true
					if enemy.get_instance_id()==oldest_charge:
						check(Time.get_ticks_msec()-earliest_charge>=130,"native charge never skips short warning")
						oldest_charge = -2
		if charger_active and spark_warning and fans.shots>=3: break
	for action in actions: Input.action_release(action)
	check(moved>30,"ordinary movement stuck behind terrain")
	check(charger_warning and charger_active,"actual spawned charger never charges")
	check(spark_warning and fans.shots>=3,"actual spawned scatterer never warns/emits fan")
	check(player.health.current_health>0 and director.state==director.State.COMBAT,"runtime witness died or auto-cleared")
	check(not director.finish_reward() and not director.choose_route(&"supply"),"unfinished actual encounter grants reward")
	var positions: Array[Vector2] = []
	var actors := director.get_active_enemies().duplicate()
	for enemy in actors: positions.append(enemy.position)
	var health: float = player.health.current_health+player.shield
	paused = true
	var frozen: Array=Support.trap_field_snapshot(map.heat_field)
	await physics_frame; await physics_frame
	check(Support.trap_field_snapshot(map.heat_field)==frozen,"real pause freezes plate clock/stage/HP")
	await create_timer(0.12,true).timeout
	check(player.health.current_health+player.shield==health,"paused encounter damage")
	for index in actors.size(): check(actors[index].position==positions[index],"paused native enemy moves")
	paused = false; await physics_frame; await physics_frame
	check(map.heat_field.active and map.heat_field.get_children().any(func(plate): return plate.enabled),"resume loses encounter-owned plate authority")
	host.free(); await process_frame
	print("FoundryEncounterRuntimeTest actual_moves=%d fan_shots=%d elapsed_ms=%d"%[moved,fans.shots,Time.get_ticks_msec()-started])
	if not failures: print("TEST PASS: FoundryEncounterRuntimeTest %d"%checks)
	quit(1 if failures else 0)
