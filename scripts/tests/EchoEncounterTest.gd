extends SceneTree
## Controlled lifecycle/transactions, not ordinary-input victory evidence.
const Map = preload("res://scenes/world/echo_court.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/EchoEncounterDirector.gd")
const Sentinel = preload("res://scripts/actors/EchoSentinelEnemy.gd")
const Shade = preload("res://scripts/actors/CirclingShadeEnemy.gd")
const Coin = preload("res://scripts/pickups/CoinPickup.gd")
class Host extends Node2D:
	var player: Node2D
	var growth: Node
	var drops: Array[int] = []
	var pickups := Node2D.new()
	func _ready() -> void: add_child(pickups)
	func spawn_coins(at: Vector2,value: int) -> void:
		drops.append(value)
		var coin := Coin.new(); coin.value = value; coin.target_player = player; coin.position = at
		pickups.add_child(coin); coin.collected.connect(func(amount): growth.add_coins(amount))
var checks := 0
var failures := 0
var clears := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoEncounterTest "+label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func fixture() -> Dictionary:
	var host := Host.new(); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; host.add_child(player); player.set_physics_process(false)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player); host.player = player; host.growth = growth
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var director := Director.new(); host.add_child(director); director.set_process(false)
	director.chapter_cleared.connect(func(_chapter): clears += 1)
	check(director.bind_echo_field(map.echo_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"actual owner run refused")
	return {"host":host,"map":map,"player":player,"growth":growth,"director":director,"enemies":enemies}
func clear_encounter(f: Dictionary,count: int) -> void:
	var d = f.director; var policy: Dictionary = d.get_encounter(); var coins: int = f.growth.coins
	var previous_drops: int = f.host.drops.size()
	check(d.begin_encounter() and not d.begin_encounter(),"duplicate combat start")
	check(f.map.echo_field.active and f.map.echo_field.get_children().filter(func(n): return n.enabled).size()==count,"actual combat clock count")
	for _step in 100:
		d._process(0.25)
		if d.spawn_queue.is_empty() and d.active_portals.is_empty(): break
	var actors: Array = d.get_active_enemies().duplicate(); var expected_coins := 0
	check(actors.size()==policy.sentinel+policy.shade and d.state==d.State.COMBAT,"actual mixed debt differs from policy")
	check(d.get_attack_targets().size()==actors.size(),"nonenemy clock becomes weapon/reward target")
	var sentinels := 0; var shades := 0
	for actor in actors:
		actor.set_physics_process(false); expected_coins += actor.coin_value
		check(actor.native_visual!=null and actor.should_show_health_bar() and f.map.layout.is_position_walkable(actor.global_position,actor.body_radius),"real native body/status/spawn")
		if actor is Sentinel: sentinels += 1; check(actor.body_radius==16 and actor.speed==132,"spacing family body/movement")
		elif actor is Shade: shades += 1; check(actor.body_radius==15 and actor.speed==160,"flanking family body/movement")
		else: check(false,"generic family substituted")
		actor.died.emit(actor,999,&"test"); check(not actor.get_meta(&"kill_resolved",false),"forged living death rewarded")
	check(sentinels==policy.sentinel and shades==policy.shade and not d.finish_reward(),"unfinished debt allows reward")
	var first = actors[0]; first.take_damage(1000,&"test"); first.take_damage(1000,&"test")
	await process_frame; await process_frame; d._process(0)
	check(d.state==d.State.COMBAT and f.host.drops.size()==previous_drops+1,"one death clears entire wave or duplicate reward")
	for index in range(1,actors.size()): actors[index].take_damage(1000,&"test")
	await process_frame; await process_frame; d._process(0)
	check(d.state==d.State.COLLECT and not f.map.echo_field.active and f.map.echo_field.get_children().all(func(n): return not n.enabled),"true clear retains danger")
	for _frame in 180:
		if f.host.pickups.get_child_count()==0: break
		await tick()
	check(f.host.pickups.get_child_count()==0 and f.growth.coins==coins+expected_coins,"real coin homing/collection or unique value")
	d._process(3.1)
	check(d.state==d.State.REWARD and not d.finish_reward(),"unclaimed reward bypass")
	var offer: Dictionary = f.growth.get_settlement_state().families[0].offers[0].duplicate(true)
	var forged := offer.duplicate(true); forged._settlement_transaction = -1; forged.transaction = -1
	check(not d.claim_reward(forged) and d.claim_reward(offer) and not d.claim_reward(offer),"forged/duplicate build choice")
	var upgraded: Dictionary = f.growth.upgrade_counts.duplicate(true)
	check(not upgraded.is_empty() and d.finish_reward() and not d.finish_reward(),"real build/reward transaction absent or repeated")
func run() -> void:
	for route in [&"supply",&"risk"]:
		var f := fixture(); await tick(); await tick()
		await clear_encounter(f,2); await clear_encounter(f,2)
		check(f.director.state==f.director.State.ROUTE and not f.map.echo_field.active,"two mandatory battles not before route")
		var coins: int = f.growth.coins; f.player.health.damage(30,true); var health: float = f.player.health.current_health
		var nested := [false]
		f.growth.progression_state_changed.connect(func(_v): nested[0] = nested[0] or f.director.choose_route(route))
		check(f.director.choose_route(route) and not f.director.choose_route(route) and not nested[0],"route/reentrant transaction repeats")
		if route==&"supply": check(f.growth.coins==coins+12 and f.player.health.current_health==health+20,"actual supply coins/heal")
		else:
			check(f.growth.coins==coins,"risk reward prepaid")
			await clear_encounter(f,4)
			check(f.growth.coins>coins+35 and f.director.state==f.director.State.BOSS_READY,"risk debt/kill coins/route bonus")
		check(f.director.state==f.director.State.BOSS_READY and f.director._boss_available() and clears==0 and not f.map.echo_field.active,"mandatory route lacks verified priest gate or forges clear")
		f.host.free(); await process_frame
	for departure in ["player","enemies","field","director","live_enemy"]:
		var f := fixture(); await tick(); await tick(); f.director.begin_encounter(); f.director._process(1.5)
		var field = f.map.echo_field
		match departure:
			"player": f.player.health.damage(f.player.health.current_health,true)
			"enemies": f.host.remove_child(f.enemies)
			"field": f.map.remove_child(field)
			"director": f.host.remove_child(f.director)
			"live_enemy": f.director.get_active_enemies()[0].queue_free(); await process_frame; await process_frame
		check(not field.active and field.get_children().all(func(n): return not n.enabled),"departure/death retains clock "+departure)
		if departure!="director": check(f.director.state==f.director.State.FAILED and not f.director.finish_reward(),"departure forges clear "+departure)
		if departure=="enemies": f.enemies.free()
		if departure=="field": field.free()
		if departure=="director": f.director.free()
		f.host.free(); await process_frame
	if not failures: print("TEST PASS: EchoEncounterTest %d"%checks)
	quit(1 if failures else 0)
