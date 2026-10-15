extends SceneTree
## Provider/actual weapon geometry fixture; not normal-input balance evidence.
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/ArchiveEncounterDirector.gd")
const Plant = preload("res://scripts/components/CapsulePlantHazard.gd")
const Grenade = preload("res://scripts/components/GrenadeProjectile.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveDamageTargetsTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var director = Director.new()
	check(director.has_method("get_attack_targets"),"chapter lacks independent weapon target provider")
	if failures: director.free(); quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); player.position = Vector2(240,0); player.world_bounds = map.layout.world_bounds; host.add_child(player); player.set_physics_process(false)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	host.add_child(director); director.set_process(false)
	var kills := [0]; director.enemy_killed.connect(func(_a,_b,_c): kills[0] += 1)
	check(director.bind_spore_field(map.spore_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"actual context start")
	player.set_enemy_provider(director.get_attack_targets)
	check(player._get_enemies().is_empty(),"intro exposes dormant environment")
	check(director.begin_encounter(),"start actual combat")
	await physics_frame; await process_frame
	var nests: Array = map.spore_field.get_children().filter(func(n): return n.enabled)
	check(nests.size()==2 and player._get_enemies().is_empty() and nests.all(func(n): return not n.is_in_group(&"enemies")),"active pressure plates must not pollute automatic enemy targeting")
	check(director.get_active_enemies().is_empty(),"environment becomes clearance debt")
	var plant := Plant.new(); plant.target_player = player; plant.position = Vector2(56,0); shots.add_child(plant); plant.set_physics_process(false)
	var outsider := Plant.new(); outsider.target_player = player; outsider.position = Vector2(70,0); host.add_child(outsider); outsider.set_physics_process(false)
	check(player._get_enemies().has(plant) and not player._get_enemies().has(outsider),"weapon candidates leak from another ownership domain")
	var copy: Array = director.get_attack_targets(); copy.clear()
	check(player._get_enemies().size()==1,"caller mutates canonical target state")
	director._spawn_enemy_at(director.EnemyScript.EnemyKind.SPITTER,Vector2(-160,-80))
	var actor = director.get_active_enemies()[0]; actor.set_physics_process(false)
	check(player._get_enemies().size()==2 and player._get_enemies().has(actor) and director.get_active_enemies().size()==1,"real Actor disappears from independent weapon roster")
	var ray: Dictionary = player._resolve_drone_ray(Vector2.ZERO,Vector2.RIGHT,3,player._get_enemies())
	check(ray.targets.has(plant) and not ray.targets.has(outsider),"actual drone geometry cannot target owned Area")
	player._damage_enemies_on_laser(Vector2.ZERO,Vector2.RIGHT,150,1,3,[plant])
	check(plant.health.current_health==15 and outsider.health.current_health==16,"real laser damage misses owned capsule or hits outsider")
	var grenade := Grenade.new(); grenade.position = Vector2(56,0); grenade.damage = 20
	grenade.enemy_provider = player._get_enemies; shots.add_child(grenade); grenade.set_physics_process(false); grenade._explode()
	check(plant.resolved and not player._get_enemies().has(plant) and not outsider.resolved,"actual grenade target resolution misses owned capsule or hits outsider")
	var nest = nests[0]
	var from: Vector2 = nest.global_position+Vector2(50,0)
	ray = player._resolve_drone_ray(from,Vector2.LEFT,3,[nest])
	check(ray.targets.has(nest),"actual drone geometry misses destructible nest")
	from += Vector2(0,11)
	ray = player._resolve_drone_ray(from,Vector2.LEFT,3,[nest])
	check(ray.targets.has(nest),"drone grazing ray ignores actual 12px nest body")
	player._damage_enemies_on_laser(from,Vector2.LEFT,100,1,3,[nest])
	check(nest.health.current_health==79,"grazing explicit laser damage ignores actual12px pressure plate")
	grenade = Grenade.new(); grenade.position = nest.global_position+Vector2(90,0); grenade.damage = 80
	grenade.enemy_provider = player._get_enemies; shots.add_child(grenade); grenade.set_physics_process(false); grenade._explode()
	check(nest.stage==nest.Stage.DESTROYED and not player._get_enemies().has(nest) and kills[0]==0,"environment explosion creates kill reward or stale target")
	director.state = director.State.COLLECT
	check(player._get_enemies().is_empty(),"safe collection retains combat targets")
	host.free(); await process_frame; await process_frame
	if not failures: print("TEST PASS: ArchiveDamageTargetsTest %d"%checks)
	quit(1 if failures else 0)
