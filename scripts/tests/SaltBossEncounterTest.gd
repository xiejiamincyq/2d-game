extends SceneTree
## Accelerated encounter ownership fixture, not normal gameplay or a save proof.
const Map = preload("res://scenes/world/salt_waterway.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/SaltEncounterDirector.gd")
const Boss = preload("res://scripts/actors/SaltTideBoss.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: SaltBossEncounterTest "+label)
func _initialize() -> void: call_deferred("run")
func advance_warning(combat: Node) -> void:
	var remaining: float = combat.DURATIONS[combat.action][0]
	while remaining>0.0000001:
		var step := minf(1.0/120.0,remaining)
		combat.advance(step); remaining -= step
func fixture() -> Dictionary:
	var host := Node2D.new(); root.add_child(host)
	var map = Map.instantiate(); host.add_child(map)
	var player := Player.new(); host.add_child(player); player.set_physics_process(false)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director := Director.new(); host.add_child(director); director.set_process(false)
	check(director.bind_tidal_field(map.tidal_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"real run binding")
	return {"host":host,"map":map,"player":player,"director":director,"enemies":enemies,"shots":shots}
func run() -> void:
	var f := fixture(); var director = f.director
	check(director._boss_available(),"native tide Boss unavailable")
	if failures: f.host.free(); await process_frame; quit(1); return
	director.spawn_queue.clear(); director._prepare_boss()
	check(director.begin_boss() and not director.begin_boss(),"unique real Boss start")
	var boss = director.get_active_boss(); boss.set_physics_process(false)
	check(boss.get_script()==Boss and boss.boss_visual!=null and boss.tentacle_attack==null,"old Boss substituted")
	check(f.map.layout.is_position_walkable(boss.global_position,56) and boss.arena_navigation==f.map.layout,"actual large body in terrain")
	check(not f.map.tidal_field.active,"encounter tides continue into Boss")
	var clears: Array[int] = []; director.chapter_cleared.connect(func(chapter): clears.append(chapter))
	boss.died.emit(boss,999,&"test")
	check(clears.is_empty() and director.state==Director.State.BOSS and not director.boss_defeat_pending,"live forged death clears chapter")
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal()
	boss.take_damage(4000); combat.advance(0.65)
	for _step in 20: director._process(0.25)
	var minions: Array = director.get_active_enemies().filter(func(actor): return actor!=boss)
	check(minions.size()==2,"phase two requires two actual minions")
	for actor in minions: check(actor.native_visual!=null and actor.kind in [actor.EnemyKind.SCRAPPER,actor.EnemyKind.MARKSMAN],"foreign or nonnative minion")
	var first_ids := minions.map(func(actor): return actor.get_instance_id())
	boss.take_damage(3500); combat.advance(0.65)
	for _step in 20: director._process(0.25)
	minions = director.get_active_enemies().filter(func(actor): return actor!=boss)
	check(minions.size()==5,"phase three requires three more finite minions")
	for id in first_ids: check(minions.any(func(actor): return actor.get_instance_id()==id),"transition deletes living minion")
	for actor in minions: check(actor.kind in [actor.EnemyKind.SCRAPPER,actor.EnemyKind.MARKSMAN],"phase three uses foreign minion")
	for _step in 80: director._process(0.25)
	check(director.get_active_enemies().size()==6,"infinite legacy Boss trickle remains")
	check(combat.start_action(&"salt"),"actual salt attack missing")
	advance_warning(combat)
	check(combat.owned_projectiles.size()==3,"real salt projectiles missing")
	boss.take_damage(boss.health.current_health+1)
	check(combat.get_state_name()=="DEATH" and combat.owned_projectiles.is_empty(),"death retains attack debt")
	await process_frame; await process_frame
	check(clears==[3] and director.state==Director.State.CLEARED and not director.active,"real death fails exact chapter three clear")
	check(not director.begin_boss() and not director.finish_reward() and clears==[3],"clear can replay")
	f.host.free(); await process_frame
	var removed := fixture(); removed.director.spawn_queue.clear(); removed.director._prepare_boss(); removed.director.begin_boss()
	removed.director.get_active_boss().queue_free(); await process_frame; await process_frame
	check(removed.director.state==Director.State.FAILED,"living Boss removal forges victory")
	removed.host.free(); await process_frame
	if not failures: print("TEST PASS: SaltBossEncounterTest %d"%checks)
	quit(1 if failures else 0)
