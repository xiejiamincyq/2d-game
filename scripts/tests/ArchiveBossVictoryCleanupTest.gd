extends SceneTree
## Genuine actors/deferred births and lethal damage. Controlled lifecycle, not a
## six-chapter playthrough: the fixture enters the actual Boss boundary directly.
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Boss = preload("res://scripts/actors/ArchiveArchivistBoss.gd")
const Mote = preload("res://scripts/actors/SplittingMoteEnemy.gd")
const Planter = preload("res://scripts/actors/CapsulePlanterEnemy.gd")
const Plant = preload("res://scripts/components/CapsulePlantHazard.gd")

const ActualBossFixture = preload("res://scripts/systems/ArchiveEncounterDirector.gd")

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
		push_error("TEST FAIL: ArchiveBossVictoryCleanupTest "+label)
func _initialize() -> void: call_deferred("run")

func fixture() -> Dictionary:
	var host := DropRecorder.new(); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); player.position = Vector2(240,0)
	player.world_bounds = map.layout.world_bounds; host.add_child(player)
	player.set_physics_process(false)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director := ActualBossFixture.new(); host.add_child(director); director.set_process(false)
	check(director.bind_spore_field(map.spore_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"real map/player/build/director start")
	# No counterfeit kill, reward, or unlock. Only select the lifecycle boundary.
	director.spawn_queue.clear(); director._prepare_boss()
	check(director.begin_boss(),"real Boss boundary failed")
	var boss = director.get_active_boss()
	check(boss is Boss and boss.health.current_health==boss.BASE_MAX_HEALTH,"fixture substituted an actor/health")
	boss.set_physics_process(false)
	boss.get_attack_director().advance(1.4); boss._update_entrance_reveal()
	return {"host":host,"map":map,"player":player,"enemies":enemies,"shots":shots,"portals":portals,"growth":growth,"director":director,"boss":boss}

func live_hostiles(f: Dictionary) -> int:
	var count := 0
	for actor in f.enemies.get_children():
		if actor is CharacterBody2D and not actor.is_queued_for_deletion() and actor.get("health")!=null and actor.health.current_health>0: count += 1
	for hazard in f.shots.get_children():
		if not hazard.is_queued_for_deletion() and hazard.is_in_group(&"enemies"): count += 1
	return count

func observe_victory(f: Dictionary,label: String) -> void:
	var director = f.director
	check(live_hostiles(f)==0,label+" published before owned live followers/hazards cancelled")
	check(director.pending_births.is_empty(),label+" published with reserved fragments")
	check(director.spawn_queue.is_empty() and director.active_portals.is_empty() and director.portal_spawn_queues.is_empty() and director.portal_spawn_timers.is_empty(),label+" published with a live portal/reinforcement reservation")
	check(not f.map.spore_field.active and f.map.spore_field.get_children().all(func(n): return not n.enabled),label+" published with environmental attacks enabled")
	check(director.get_attack_targets().is_empty(),label+" still supplies hostile weapon targets")

func run() -> void:
	var f := fixture(); await physics_frame; await process_frame
	var director = f.director; var boss = f.boss
	var kills: Array[int] = []; var rewards: Array[int] = []
	director.enemy_killed.connect(func(actor: Node,_source: StringName,coins: int): kills.append(actor.get_instance_id()); rewards.append(coins))
	var original_coins: int = f.growth.coins
	# Actual factory admission, not a manually maintained active_enemies list.
	director._spawn_enemy_at(director.EnemyScript.EnemyKind.SCRAPPER,Vector2(-240,-150))
	director._spawn_enemy_at(director.EnemyScript.EnemyKind.SPITTER,Vector2.ZERO)
	director._spawn_enemy_at(director.EnemyScript.EnemyKind.SCRAPPER,Vector2(0,180))
	var live_mote = director.get_active_enemies()[1]
	var planter = director.get_active_enemies()[2]
	var split_parent = director.get_active_enemies()[3]
	check(live_mote is Mote and planter is Planter and split_parent is Mote,"real regional follower roles unavailable")
	for actor in [live_mote,planter,split_parent]: actor.set_physics_process(false)
	await physics_frame
	# Let a genuine Planter own and admit its capsule before the fatal Boss hit.
	planter.planned_plant_position = Vector2(56,0); planter.pending_plant = true
	planter._fire_spitter()
	check(planter.get_owned_plant_count()==1,"actual Planter did not reserve safe capsule")
	await process_frame; await physics_frame
	var plant = planter.owned_plants[0].get_ref() if not planter.owned_plants.is_empty() else null
	check(is_instance_valid(plant) and plant is Plant and plant.get_parent()==f.shots,"actual owned capsule did not enter physics tree")
	if is_instance_valid(plant): plant.set_physics_process(false)
	# A different ownership domain must not be swept by global group cleanup.
	var other_world := Node2D.new(); root.add_child(other_world)
	var outsider := Plant.new(); other_world.add_child(outsider); outsider.set_physics_process(false)
	var boss_id: int = boss.get_instance_id(); var split_id: int = split_parent.get_instance_id()
	var clears := [0]; var defeat_notifications := [0]; var failed := [0]
	director.run_failed.connect(func(_reason): failed[0] += 1)
	director.boss_defeated.connect(func(_actor):
		defeat_notifications[0] += 1
		observe_victory(f,"boss_defeated"))
	director.chapter_cleared.connect(func(chapter: int):
		clears[0] += 1; check(chapter==4,"wrong chapter cleared")
		observe_victory(f,"chapter_cleared")
		# Synchronous UI/game callbacks must not reopen or refill a finished fight.
		check(not director.begin_boss() and not director.begin_encounter(),"victory callback reopened battle")
		director._on_boss_reinforcements_requested(boss,2)
		director._process(10))
	var reentry := [false]
	boss.died.connect(func(actor: Node,_coins: int,_source: StringName):
		reentry[0] = actor.take_damage(1) or actor.get_attack_director().start_action(&"page")
		actor.reinforcements_requested.emit(actor,2))
	# Existing owned-portal debt is an independent lifecycle fixture, not evidence
	# of the new finite brood attack (which need not create any portals).
	var legacy_queues: Array[Array] = [[director.EnemyScript.EnemyKind.SCRAPPER]]
	director._open_portals_for_queues(legacy_queues)
	check(not director.active_portals.is_empty() and not director.portal_spawn_queues.is_empty(),"real reinforcement portal reservation missing")
	# Real Mote death produces genuine deferred fragments. No fabricated signals.
	check(split_parent.take_damage(split_parent.health.current_health+1),"actual splitting parent did not die")
	check(director.pending_births.size()==2,"death fixture lacks two genuine pending fragments")
	check(boss.take_damage(boss.health.current_health+1),"actual lethal Boss damage did not resolve")
	check(boss.death_resolved and boss.health.current_health<=0 and not reentry[0],"death callback resurrected actual Boss attack/health")
	await process_frame; await process_frame; await physics_frame
	check(clears[0]==1 and defeat_notifications[0]==1 and failed[0]==0 and director.state==director.State.CLEARED,"true Boss death did not publish unique clean victory")
	check(live_hostiles(f)==0 and director.pending_births.is_empty() and f.portals.get_child_count()==0,"deferred work repopulated cleared arena")
	check(kills.size()==2 and kills.has(boss_id) and kills.has(split_id) and rewards.reduce(func(total,value): return total+value,0)==63,"follower cancellation manufactured kill/coin rewards")
	check(f.host.coins==63 and f.growth.coins==original_coins,"drops or build currency duplicated during cleanup")
	check(not outsider.resolved and not outsider.is_queued_for_deletion(),"victory cleanup touched another world ownership domain")
	f.host.free(); other_world.free(); await process_frame; await process_frame
	# An actual living Boss merely leaving the tree is failure, never a win.
	f = fixture(); var false_clears := [0]
	f.director.chapter_cleared.connect(func(_chapter): false_clears[0] += 1)
	var departed = f.boss; f.enemies.remove_child(departed)
	check(false_clears[0]==0 and f.director.state==f.director.State.FAILED,"living Boss departure fabricated victory")
	departed.free(); f.host.free(); await process_frame; await process_frame
	if not failures: print("TEST PASS: ArchiveBossVictoryCleanupTest %d"%checks)
	quit(1 if failures else 0)
