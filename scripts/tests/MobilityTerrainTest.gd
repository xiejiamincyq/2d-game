extends SceneTree
const Definitions=preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Player=preload("res://scripts/actors/Player.gd")
const Flame=preload("res://scripts/components/FlameTrail.gd")
const Trap=preload("res://scripts/world/ReusableStepTrap.gd")
const Obstacle=preload("res://scripts/world/ArenaObstacle.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1; push_error("TEST FAIL: MobilityTerrainTest "+label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func run() -> void:
	for chapter in range(1,7): await map_case(chapter)
	await burn_case()
	await cover_case()
	if failures==0: print("TEST PASS: MobilityTerrainTest %d"%checks)
	quit(1 if failures else 0)
func map_case(chapter: int) -> void:
	var host:=Node2D.new(); root.add_child(host)
	var definition: Dictionary=Definitions.get_definition(chapter)
	var map: Node2D=definition.map.instantiate(); map.map_seed=521; host.add_child(map)
	var wall: Node2D=map.layout.get_child(0); var rect: Rect2=wall.get_damage_rect()
	var player:=Player.new(); player.position=Vector2(rect.position.x-80,rect.get_center().y)
	host.add_child(player); player.set_physics_process(false); player.set_enemy_provider(func(): return [])
	await tick(); await tick()
	var hp: float=wall.health.current_health
	player._apply_dash_melee_sweep(Vector2(rect.position.x-50,rect.get_center().y),Vector2(rect.position.x-20,rect.get_center().y))
	player._apply_dash_melee_sweep(Vector2(rect.position.x-50,rect.get_center().y),Vector2(rect.position.x-20,rect.get_center().y))
	check(is_equal_approx(wall.health.current_health,hp-player.dash_melee_damage),"chapter%d dash touches true wall once per dash, without provider registration"%chapter)
	var flame:=Flame.new(); flame.position=Vector2(rect.position.x-21,rect.get_center().y)
	host.add_child(flame); flame.set_physics_process(false)
	hp=wall.health.current_health; flame._update_burning_enemies(0.20)
	check(wall.health.current_health==hp,"chapter%d flame applies burn, not immediate direct damage"%chapter)
	var deadline:=Time.get_ticks_msec()+500
	while wall.health.current_health==hp and Time.get_ticks_msec()<deadline: await tick()
	check(wall.health.current_health<hp,"chapter%d flame grazing real edge produces timed terrain burn"%chapter)
	check(not wall.is_in_group(&"enemies") and player._get_enemies().is_empty(),"chapter%d mobility terrain remains separate from enemy roster"%chapter)
	host.free(); await process_frame
func burn_case() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var plate:=Trap.new(); host.add_child(plate)
	var flame:=Flame.new(); flame.position=Vector2(33,0); flame.burn_base_attack=1
	host.add_child(flame); flame.set_physics_process(false)
	await tick(); await tick()
	flame._update_burning_enemies(0.2)
	var burn:=plate.get_node_or_null("TerrainFlameBurn")
	check(burn!=null,"Area gets terrain burn component")
	if burn==null: host.free(); await process_frame; return
	burn.set_process(false)
	check(burn.status.get_stack_count()==1,"Area overlap plus query does not duplicate one burn stack")
	burn._process(0.5)
	check(is_equal_approx(plate.health.current_health,79.7),"one stack uses existing60% damage-per-second")
	flame._update_burning_enemies(1.0)
	burn.set_process(false) # A fresh contact wakes the real process clock.
	check(burn.status.get_stack_count()==5,"terrain burn keeps existing five-stack cap")
	flame.queue_free(); await process_frame
	burn._process(0.5)
	check(is_equal_approx(plate.health.current_health,78.2),"terrain burn outlives its emitting trail")
	burn._process(5.0)
	check(burn.status.get_stack_count()==0,"burn expires with finite remaining duration")
	# A fresh contact during the same deferred-delete frame must not vanish.
	flame=Flame.new(); flame.position=Vector2(33,0); flame.burn_base_attack=1
	host.add_child(flame); flame.set_physics_process(false); flame._update_burning_enemies(0.2)
	var refreshed:=plate.get_node_or_null("TerrainFlameBurn")
	check(refreshed!=null and not refreshed.is_queued_for_deletion() and refreshed.status.get_stack_count()==1,"contact at expiry immediately renews a live burn receiver")
	host.free(); await process_frame
func cover_case() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var wall:=Obstacle.new(); wall.setup(Rect2(0,-80,2,160),&"planter"); host.add_child(wall)
	var behind:=Trap.new(); behind.position=Vector2(18,0); host.add_child(behind)
	var player:=Player.new(); player.position=Vector2(-80,0); host.add_child(player)
	player.set_physics_process(false); player.set_enemy_provider(func(): return [behind,behind])
	await tick(); await tick()
	wall.health.current_health=1
	player._apply_dash_melee_sweep(Vector2(-60,0),Vector2(-17,0))
	check(wall.is_queued_for_deletion() and behind.health.current_health==80,"one dash strike cannot remove cover then tunnel damage through it")
	await tick(); await tick(); player.dash_hit_bodies.clear()
	player._apply_dash_melee_sweep(Vector2(-60,0),Vector2(-17,0))
	check(is_equal_approx(behind.health.current_health,80-player.dash_melee_damage),"next dash may hit exposed Area after actual wall release")
	host.free(); await process_frame
