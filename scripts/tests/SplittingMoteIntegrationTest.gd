extends SceneTree
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const ROSTER_PATH := "res://scripts/campaign/RegionalEnemyRoster.gd"
class Target extends Node2D:
	var hits: Array[float] = []
	var stealth_active := false
	func take_damage(amount: float) -> void: hits.append(amount)
	func is_stealthed() -> bool: return stealth_active
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: SplittingMoteIntegrationTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(ROSTER_PATH),"pending/live regional roster absent")
	if failures:
		quit(1)
		return
	var arena := Node2D.new()
	arena.position = Vector2(180,120) # Birth placement must preserve global position.
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(200,0)
	target.add_to_group("player")
	arena.add_child(target)
	var roster = load(ROSTER_PATH).new()
	var moth = Factory.create_actor(4,"splitting_mote",0,arena,target)
	check(moth!=null,"actual fourth-region split actor missing")
	if moth==null:
		arena.free()
		quit(1)
		return
	moth.world_bounds = Rect2(-650,-450,1300,900)
	arena.add_child(moth)
	moth.set_physics_process(false)
	check(roster.register_actor(moth) and not roster.register_actor(moth),"roster double-registers parent")
	check(moth.native_visual.skeleton.get_bone_count()==16 and moth.should_show_health_bar(),"actual parent lacks new rig/bar")
	var rewards := [0]
	var clears := [0]
	roster.enemy_defeated.connect(func(_actor,coins,_source): rewards[0]+=coins)
	roster.cleared.connect(func(): clears[0]+=1)
	var prepared: Array[CharacterBody2D] = []
	moth.offspring_prepared.connect(func(children: Array[CharacterBody2D]): prepared.assign(children))
	var counts_on_death: Array[int] = []
	moth.died.connect(func(_actor,_coins,_source): counts_on_death.append(roster.get_active_count()))
	var corpse = moth.native_visual
	var at: Transform2D = corpse.global_transform
	var center: Vector2 = moth.global_position
	moth.take_damage(1000)
	moth.take_damage(1000)
	check(prepared.size()==2 and roster.get_active_count()==2 and counts_on_death==[2] and clears[0]==0,"last parent clears encounter before split births register")
	check(rewards[0]==3 and corpse.get_parent()==arena and corpse.global_transform.is_equal_approx(at),"parent reward/death anchor duplicates")
	check(prepared.all(func(child): return not child.is_inside_tree()),"physics-tree births not deferred safely")
	await process_frame
	await physics_frame
	check(prepared.all(func(child): return child.is_inside_tree() and child.is_fragment and child.native_visual!=null),"prepared fragments do not enter actual engine")
	for child in prepared:
		child.set_physics_process(false)
		check(child.global_position.distance_to(center)<80 and child.global_position.distance_to(center)>20,"fragment born at transformed parent origin")
		check(child.body_radius==9 and child.native_visual.scale==Vector2(0.62,0.62) and child.scale==Vector2.ONE,"small fragment changes physical root scale")
		check(child.should_show_health_bar() and child.health.current_health==14 and child.coin_value==0,"fragment bar/health/reward wrong")
		check(roster.get_neighbors(child).size()==1,"split fragments are not in social neighbor grid")
	for child in prepared:
		child.take_damage(1000)
		child.take_damage(1000)
	check(roster.get_active_count()==0 and clears[0]==1 and rewards[0]==3,"one-generation fragments recurse, duplicate rewards or fail to clear")
	await process_frame
	check(arena.get_tree().get_nodes_in_group("enemies").is_empty(),"fragment deaths leave live enemies")
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: SplittingMoteIntegrationTest %d" % checks)
	quit(1 if failures else 0)
