extends SceneTree
## Deferred hazard ownership: no direct-kill test is a gameplay witness.
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: CapsuleBirthContextTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for mode in ["live_death","expired_replacement","destination_detached","target_detached","target_queued","target_dead"]:
		var host := Node2D.new(); root.add_child(host)
		var shots := Node2D.new(); host.add_child(shots)
		var target := Player.new(); target.position = Vector2(240,0); host.add_child(target); target.set_physics_process(false)
		var actor = Factory.create_actor(4,"capsule_planter",0,shots,target)
		actor.world_bounds = Rect2(-600,-400,1400,1000); host.add_child(actor); actor.set_physics_process(false)
		await physics_frame
		actor.shoot_cooldown = 0; actor._physics_process(0.01); actor._physics_process(actor.ranged_windup_duration+0.01)
		check(actor.get_owned_plant_count()==1,"missing reserved capsule "+mode)
		if mode=="destination_detached": host.remove_child(shots)
		elif mode=="target_detached": host.remove_child(target)
		elif mode=="target_queued": target.queue_free()
		elif mode=="target_dead": target.health.current_health = 0
		await process_frame; await process_frame
		if mode=="expired_replacement":
			for cycle in 8:
				check(shots.get_child_count()==1,"expired replacement actual birth missing")
				if shots.get_child_count()!=1: break # Keep the failure, avoid a misleading nil crash.
				var plant = shots.get_child(0); plant._physics_process(3)
				await process_frame; await process_frame
				check(actor.get_owned_plant_count()==0 and actor.owned_plants.size()<=2,"dead weak-reference history grows beyond owned cap")
				if cycle<7:
					actor.shoot_cooldown = 0; actor._physics_process(0.01); actor._physics_process(actor.ranged_windup_duration+0.01)
					await process_frame; await process_frame
		elif mode=="live_death":
			check(shots.get_child_count()==1 and actor.get_owned_plant_count()==1,"real capsule admission missing")
			if shots.get_child_count()!=1: host.free(); await process_frame; continue
			var plant = shots.get_child(0)
			check(plant.is_inside_tree() and plant.health.current_health==16 and plant.is_in_group(&"capsule_plants"),"admitted hazard wrong")
			actor.take_damage(1000,&"test")
			check(plant.resolved and not plant.is_in_group(&"capsule_plants") and actor.get_owned_plant_count()==0,"death leaves hazardous live plant")
			await process_frame; await process_frame
			check(shots.get_child_count()==0,"dead owner retains capsule")
		else:
			check(shots.get_child_count()==0 and actor.get_owned_plant_count()==0 and get_nodes_in_group(&"capsule_plants").is_empty(),"invalid birth context admits capsule "+mode)
		if mode=="destination_detached": shots.free()
		if mode=="target_detached": target.free()
		host.free(); await process_frame
	if not failures: print("TEST PASS: CapsuleBirthContextTest %d"%checks)
	quit(1 if failures else 0)
