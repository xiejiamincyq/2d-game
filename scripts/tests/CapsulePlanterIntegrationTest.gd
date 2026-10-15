extends SceneTree
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const Roster = preload("res://scripts/campaign/RegionalEnemyRoster.gd")
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
		push_error("TEST FAIL: CapsulePlanterIntegrationTest "+label)
func _initialize() -> void: call_deferred("_run")
func finish_windup(actor: Node) -> void:
	for step in 120:
		if not actor.ranged_is_winding_up: break
		actor._physics_process(1.0/120.0)
func _run() -> void:
	var arena := Node2D.new()
	arena.position = Vector2(200,150)
	root.add_child(arena)
	var shots := Node2D.new()
	shots.position = Vector2(75,30)
	arena.add_child(shots)
	var target := Target.new()
	target.position = Vector2(240,0)
	arena.add_child(target)
	var actor = Factory.create_actor(4,"capsule_planter",0,shots,target)
	check(actor!=null,"fourth-region persistent planter missing")
	if failures:
		arena.free()
		quit(1)
		return
	actor.world_bounds = Rect2(-600,-400,1400,1000)
	arena.add_child(actor)
	actor.set_physics_process(false)
	check(actor.native_visual.skeleton.get_bone_count()==20 and actor.should_show_health_bar(),"actual planter lacks new rig/healthy bar")
	check(actor.health.current_health==40 and actor.body_radius==16 and actor.scale==Vector2.ONE,"planter physical/health contract incorrect")
	actor.shoot_cooldown = 0
	actor._physics_process(0.01)
	var locked: Vector2 = actor.planned_plant_position
	check(actor.ranged_is_winding_up and actor.native_visual.player.current_animation=="warning" and actor.should_show_attack_marker() and shots.get_child_count()==0,"short warning releases capsule early")
	target.position.y = 100
	actor._physics_process(0.13)
	check(shots.get_child_count()==0 and actor.planned_plant_position==locked,"windup retargets/places before its promised duration")
	finish_windup(actor)
	check(actor.get_owned_plant_count()==1 and shots.get_child_count()==0,"pending plant not reserved before deferred birth")
	actor._fire_spitter()
	check(actor.get_owned_plant_count()==1,"duplicate release creates another plant")
	await process_frame
	check(shots.get_child_count()==1,"real deferred plant absent")
	var plant = shots.get_child(0)
	plant.set_physics_process(false)
	check(plant.global_position.is_equal_approx(locked) and plant.target_player==target,"transformed parent alters safe landing/target")
	check(actor.native_visual.player.current_animation=="attack" and not actor.ranged_is_winding_up,"placement lacks new attack animation")
	# Reserve two maximum; ordinary actor death disarms ground hazards before settlement.
	actor.shoot_cooldown = 0
	actor._physics_process(0.01)
	finish_windup(actor)
	await process_frame
	for child in shots.get_children(): child.set_physics_process(false)
	check(actor.get_owned_plant_count()==2,"second valid nonoverlapping capsule absent")
	actor.shoot_cooldown = 0
	actor._physics_process(0.01)
	finish_windup(actor)
	await process_frame
	check(actor.get_owned_plant_count()==2 and shots.get_child_count()==2,"per-planter ground hazard cap exceeded")
	var roster := Roster.new()
	roster.register_actor(actor)
	var cleared := [0]
	var rewards := [0]
	roster.cleared.connect(func(): cleared[0]+=1)
	roster.enemy_defeated.connect(func(_actor,coins,_source): rewards[0]+=coins)
	actor.take_damage(1000)
	check(cleared[0]==1 and rewards[0]==3 and plant.resolved,"parent death leaves active hazards or counts them as extra enemies")
	await process_frame
	check(shots.get_child_count()==0,"parent death leaves persistent ground objects")
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: CapsulePlanterIntegrationTest %d" % checks)
	quit(1 if failures else 0)
