extends SceneTree
## Actual fourth-region placement and physics time. Controlled encounter fixture,
## not a playthrough: isolate one factory-admitted Planter without fake kills.
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/ArchiveEncounterDirector.gd")
const Planter = preload("res://scripts/actors/CapsulePlanterEnemy.gd")
const Plant = preload("res://scripts/components/CapsulePlantHazard.gd")
const Mote = preload("res://scripts/actors/SplittingMoteEnemy.gd")
const LoopRules = preload("res://scripts/systems/CampaignLoopRules.gd")

class DropRecorder extends Node2D:
	var coins := 0
	func spawn_coins(_at: Vector2,count: int) -> void: coins += count
	func spawn_shield(_at: Vector2,_amount: float) -> void: pass
	func spawn_heart(_at: Vector2,_amount: float) -> void: pass

var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignCapsuleHatchTest "+label)
func _initialize() -> void: call_deferred("run")

func fixture(loop_value:=1) -> Dictionary:
	var host := DropRecorder.new(); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); player.position = Vector2(240,0)
	player.world_bounds = map.layout.world_bounds; host.add_child(player); player.set_physics_process(false)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director := Director.new(); host.add_child(director); director.set_process(false)
	check(director.configure_loop(loop_value),"actual incubation loop configured")
	check(director.bind_spore_field(map.spore_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"actual Archive context start")
	# Select a small controlled encounter; no actor is removed or pronounced dead.
	director.spawn_queue.clear(); check(director.begin_encounter(),"actual COMBAT boundary")
	director._spawn_enemy_at(director.EnemyScript.EnemyKind.SPITTER,Vector2.ZERO)
	var planter = director.get_active_enemies()[0]; planter.set_physics_process(false)
	check(planter is Planter and planter.native_visual!=null,"factory substituted Planter")
	var kills := [0]; director.enemy_killed.connect(func(_actor,_source,_coins): kills[0] += 1)
	return {"host":host,"map":map,"player":player,"enemies":enemies,"shots":shots,"portals":portals,"growth":growth,"director":director,"planter":planter,"kills":kills}

func place(f: Dictionary) -> Node:
	await physics_frame; await physics_frame
	var planter = f.planter; planter.shoot_cooldown = 0
	planter._update_spitter(0.01,f.player)
	check(planter.ranged_is_winding_up,"real safe placement did not enter warning")
	for _step in 120:
		if not planter.ranged_is_winding_up: break
		planter._update_spitter(1.0/120.0,f.player)
	await process_frame; await physics_frame
	var plants: Array = f.shots.get_children().filter(func(n): return n is Plant and not n.is_queued_for_deletion())
	check(plants.size()==1,"real placement must admit one capsule")
	if plants.size()!=1: return null
	var plant = plants[0]
	check(plant.health.max_health==16 and plant.health.current_health==16,"capsule is not a 16HP destructible body")
	check(f.director.get_attack_targets().has(plant),"actual weapon provider omits landed capsule")
	return plant

func elapse(seconds: float) -> void:
	for _step in ceili(seconds*Engine.physics_ticks_per_second): await physics_frame
	await process_frame

func hatchlings(f: Dictionary) -> Array[Node]:
	return f.director.get_active_enemies().filter(func(n): return n is Mote and not n.is_queued_for_deletion())

func check_hatch(f: Dictionary,label: String) -> void:
	var born := hatchlings(f)
	check(born.size()==1,label+" did not hatch exactly one actual director-owned Mote")
	if born.size()!=1: return
	var actor = born[0]; actor.set_physics_process(false)
	check(actor.get_parent()==f.enemies and actor.native_visual!=null and actor.native_visual.skeleton.get_bone_count()==16,label+" hatchling is not native body/owned enemy")
	check(actor.is_fragment and actor.coin_value==0 and actor.body_radius==9,label+" hatchling repeats splitting or manufactures loot")
	check(is_equal_approx(actor.health.max_health,14.0*(1.0+0.13*actor.difficulty_index)*LoopRules.health_scale(f.director.run_loop)),label+" actual hatchling loop HP applied exactly once")
	var probe := Node2D.new(); f.host.add_child(probe); probe.global_position = actor.global_position+Vector2(15,0)
	check(actor.neighbor_provider.is_valid() and f.director._get_enemy_neighbors(probe).has(actor),label+" hatchling missing actual neighbor membership")
	probe.free()
	check(f.director.get_attack_targets().has(actor),label+" hatchling missing weapon provider")
	check(f.map.layout.is_position_walkable(actor.global_position,actor.body_radius) and actor.global_position.distance_to(f.player.global_position)>=actor.body_radius+16.9,label+" hatched into wall/player")

func defeat_with_small_hits(actor: Node) -> void:
	# Real modest hits resolve actual death; no forged died signal or mass clear.
	for _hit in 2000:
		if not is_instance_valid(actor) or actor.death_resolved: break
		actor.take_damage(9)
	check(is_instance_valid(actor) and actor.death_resolved,"small actual hits did not resolve death")

func wall_at(f: Dictionary,at: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new(); wall.collision_layer = 1
	var collision := CollisionShape2D.new(); var shape := CircleShape2D.new(); shape.radius = 38
	collision.shape = shape; wall.add_child(collision); wall.position = at
	f.host.add_child(wall); return wall

func safe_birth_observer(f: Dictionary,label: String) -> void:
	f.enemies.child_entered_tree.connect(func(actor: Node):
		if not actor is Mote: return
		check(actor.global_position.distance_to(f.player.global_position)>=actor.body_radius+16.9,label+" birth overlaps actual player hitbox")
		check(f.map.layout.is_position_walkable(actor.global_position,actor.body_radius),label+" birth crosses actual map terrain")
		var shape := CircleShape2D.new(); shape.radius = actor.body_radius
		var query := PhysicsShapeQueryParameters2D.new(); query.shape = shape
		query.transform = Transform2D(0,actor.global_position); query.collision_mask = 1
		query.exclude = [actor.get_rid()]
		check(actor.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),label+" birth overlaps real new wall/actor collider")
		actor.set_physics_process(false))

func test_mother_death() -> void:
	var f := fixture(); var plant = await place(f)
	if is_instance_valid(plant):
		var expected_coins: int = f.planter.coin_value
		defeat_with_small_hits(f.planter)
		await process_frame; await process_frame; f.director._process(0)
		check(is_instance_valid(plant) and not plant.is_queued_for_deletion(),"landed capsule cancelled with defeated mother")
		check(f.director.state==f.director.State.COMBAT and not f.director.finish_reward(),"unhatched capsule debt permitted collection/reward")
		check(f.kills[0]==1 and f.host.coins==expected_coins,"landed capsule forged a mother reward")
		await elapse(3.3); check_hatch(f,"capsule whose mother was defeated")
		f.director._process(0)
		check(f.director.state==f.director.State.COMBAT,"living hatchling permits collection")
		var born := hatchlings(f)
		if born.size()==1:
			defeat_with_small_hits(born[0]); await process_frame; await process_frame
			f.director._process(0)
			check(hatchlings(f).is_empty() and f.director.state==f.director.State.COLLECT,"fragment split again or debt never cleared")
			check(f.kills[0]==2 and f.host.coins==expected_coins,"hatchling cancellation/death duplicated coin reward")
	f.host.free(); await process_frame; await process_frame

func test_pause() -> void:
	var f := fixture(); var plant = await place(f)
	if is_instance_valid(plant):
		await elapse(2.65); var before: float = plant.age
		paused = true; await create_timer(0.12,true,false,true).timeout
		check(is_instance_valid(plant) and is_equal_approx(plant.age,before) and hatchlings(f).is_empty(),"pause advances capsule/hatch clock")
		paused = false; await elapse(0.65); check_hatch(f,"resumed capsule")
	f.host.free(); await process_frame; await process_frame

func test_removed_capsule() -> void:
	var f := fixture(); var plant = await place(f)
	if is_instance_valid(plant):
		f.shots.remove_child(plant)
		check(plant.resolved or plant.is_queued_for_deletion(),"removed capsule retains live birth authority")
		if not plant.is_queued_for_deletion(): f.shots.add_child(plant)
		defeat_with_small_hits(f.planter)
		await process_frame; await process_frame; f.director._process(0)
		var live: bool = is_instance_valid(plant) and not plant.resolved and not plant.is_queued_for_deletion()
		check(not live or f.director.state==f.director.State.COMBAT,"reinserted live capsule silently lost clearance debt")
		await elapse(3.3)
		check(not is_instance_valid(plant) or plant.resolved,"reinserted capsule remains an indefinite harmless orphan")
		check(hatchlings(f).is_empty(),"removed capsule regained late hatch authority")
	f.host.free(); await process_frame; await process_frame

func test_obstructed_birth() -> void:
	for mode in ["wall","player"]:
		var f := fixture(); var plant = await place(f)
		if is_instance_valid(plant):
			var at: Vector2 = plant.global_position
			safe_birth_observer(f,mode)
			var obstruction: StaticBody2D
			if mode=="wall": obstruction = wall_at(f,at)
			else: f.player.global_position = at
			await physics_frame; await physics_frame; await elapse(3.3)
			if mode=="wall":
				check(is_instance_valid(plant) and not plant.resolved, "blocked mature capsule was cancelled rather than retained")
				check(is_instance_valid(plant) and f.director.pending_births.has(plant), "blocked mature capsule lost clearance debt")
				obstruction.free(); await physics_frame; await physics_frame
				await elapse(0.4)
			check_hatch(f,mode+" safely cleared/relocated birth")
			check(not is_instance_valid(plant) or plant.is_queued_for_deletion(),mode+" safe hatch left stale debt")
		f.host.free(); await process_frame; await process_frame

func test_cancelled_contexts() -> void:
	for mode in ["boss-victory","player-death","player-departure","enemy-owner-departure","shot-owner-departure","director-departure"]:
		var f := fixture(); var plant = await place(f); var detached: Node
		if is_instance_valid(plant):
			match mode:
				"boss-victory":
					f.director._prepare_boss(); check(f.director.begin_boss(),"cancel fixture actual Boss start")
					var boss = f.director.get_active_boss(); boss.set_physics_process(false)
					boss.get_attack_director().advance(1.4); boss._update_entrance_reveal()
					defeat_with_small_hits(boss)
				"player-death": f.player.health.damage(100,true)
				"player-departure": detached = f.player; f.host.remove_child(detached)
				"enemy-owner-departure": detached = f.enemies; f.host.remove_child(detached)
				"shot-owner-departure": detached = f.shots; f.host.remove_child(detached)
				"director-departure": detached = f.director; f.host.remove_child(detached)
			await process_frame; await process_frame; await elapse(3.3)
			check(hatchlings(f).is_empty(),mode+" allowed a late hatchling")
			check(f.enemies.get_children().filter(func(n): return n is Mote and not n.is_queued_for_deletion()).is_empty(),mode+" leaked an unregistered hatchling")
			if mode=="boss-victory": check(f.director.state==f.director.State.CLEARED,"real Boss victory not terminal")
		if is_instance_valid(detached): detached.free()
		f.host.free(); await process_frame; await process_frame

func run() -> void:
	if OS.get_cmdline_user_args().has("--review-only"):
		await test_removed_capsule(); await test_obstructed_birth()
		print("CAPSULE REVIEW CHECKS: %d failures=%d"%[checks,failures])
		if not failures: print("TEST PASS: CampaignCapsuleHatchTest review %d"%checks)
		quit(1 if failures else 0); return
	var f: Dictionary
	var plant: Node
	for loop_value in [1,2]:
		f=fixture(loop_value); plant=await place(f)
		if is_instance_valid(plant):
			await elapse(2.65); check(hatchlings(f).is_empty(),"capsule hatches too early")
			await elapse(0.65); check_hatch(f,"surviving capsule after about three seconds")
			check(f.kills[0]==0 and f.host.coins==0,"hatching manufactures a kill/coin")
		f.host.free(); await process_frame; await process_frame
	f = fixture(); plant = await place(f)
	if is_instance_valid(plant):
		check(plant.take_damage(16),"destroying real capsule failed")
		await elapse(3.3)
		check(hatchlings(f).is_empty() and f.kills[0]==0 and f.host.coins==0,"destroyed capsule births or fabricates loot")
	f.host.free(); await process_frame; await process_frame
	await test_mother_death()
	await test_pause()
	await test_removed_capsule()
	await test_obstructed_birth()
	await test_cancelled_contexts()
	print("CAPSULE HATCH CHECKS: %d failures=%d"%[checks,failures])
	if not failures: print("TEST PASS: CampaignCapsuleHatchTest %d"%checks)
	quit(1 if failures else 0)
