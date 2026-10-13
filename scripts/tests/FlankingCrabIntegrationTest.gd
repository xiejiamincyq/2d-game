extends SceneTree
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
class Target extends Node2D:
	var stealth_active := false
	var hits: Array[float] = []
	func is_stealthed() -> bool: return stealth_active
	func take_damage(amount: float) -> void: hits.append(amount)
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: FlankingCrabIntegrationTest "+label)
func _initialize() -> void:
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(250,0)
	target.add_to_group("player")
	arena.add_child(target)
	var enemy = Factory.create_actor(3,"flanking_crab",0,arena,target)
	check(enemy!=null,"third-region original flanker absent from real factory")
	if enemy==null:
		arena.free()
		quit(1)
		return
	enemy.world_bounds = Rect2(-650,-450,1300,900)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	var view = enemy.native_visual
	check(view!=null and enemy.static_visual==null and view.skeleton.get_bone_count()==20,"actual crab still raster/placeholder")
	check(enemy.should_show_health_bar() and enemy._uses_flocking(),"ordinary crab lacks healthy bar/social steering")
	var needler = Factory.create_actor(3,"salt_needle",0,arena,target)
	arena.add_child(needler)
	needler.set_physics_process(false)
	check(needler.get_visual_node().scene_file_path=="res://scenes/actors/native/salt_needler_paper_v1.tscn","third-region pairing uses old needle raster")
	needler.free()
	enemy.formation_slot_index = 0
	var left: Vector2 = enemy._get_melee_desired_velocity(Vector2(250,0))
	enemy.formation_slot_index = 1
	var right: Vector2 = enemy._get_melee_desired_velocity(Vector2(250,0))
	print("FlankingCrabIntegrationTest opposite flank intents: ",left," / ",right)
	check(left.x>0 and right.x>0 and left.y< -0.4 and right.y>0.4,"flankers all pursue one straight line")
	check(enemy._get_melee_desired_velocity(Vector2(600,0)).x>0.99,"distant crab endlessly orbits")
	check(enemy._get_melee_desired_velocity(Vector2(45,0)).x>0.99,"nearby crab cannot close for pincer")
	enemy.basic_attack.cooldown = 0
	target.position = Vector2(50,0)
	enemy._physics_process(0.01)
	check(enemy.should_show_attack_marker() and view.player.current_animation=="warning" and target.hits.is_empty(),"short warning absent or early hit")
	enemy._physics_process(0.14)
	check(target.hits.is_empty(),"pincer damage before short head warning ends")
	enemy._physics_process(0.04)
	check(target.hits==[21.0] and not enemy.should_show_attack_marker() and view.player.current_animation=="attack","locked pincer not bound to actual unique hit")
	for index in 5: enemy._physics_process(0.01)
	check(target.hits==[21.0],"pincer damages every active frame")
	enemy.basic_attack.cancel()
	enemy.basic_attack.cooldown = 0
	var wall := StaticBody2D.new()
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8,40)
	shape_node.shape = shape
	wall.add_child(shape_node)
	wall.position = Vector2(25,0)
	arena.add_child(wall)
	await physics_frame
	enemy._physics_process(0.01)
	enemy._physics_process(0.19)
	check(target.hits==[21.0],"pincer damages through solid terrain")
	enemy._physics_process(0.32)
	wall.free()
	await physics_frame
	enemy.basic_attack.cancel()
	enemy.basic_attack.cooldown = 0
	target.position = Vector2(50,0)
	enemy._physics_process(0.01)
	target.position = Vector2(-50,0)
	enemy._physics_process(0.19)
	check(target.hits==[21.0],"pincer tracks escaped target behind locked direction")
	enemy.basic_attack.cancel()
	enemy.basic_attack.cooldown = 0
	target.position = Vector2(50,0)
	enemy._physics_process(0.01)
	target.stealth_active = true
	enemy._physics_process(0.2)
	check(not enemy.basic_attack.is_active() and not enemy.should_show_attack_marker() and view.player.current_animation!="attack","hidden target leaves a stale snap")
	target.stealth_active = false
	enemy.basic_attack.cooldown = 0
	enemy._physics_process(0.01)
	enemy.apply_spawn_impulse(Vector2.ZERO,0.3)
	enemy._physics_process(0.1)
	check(not enemy.basic_attack.is_active() and target.hits==[21.0],"spawn motion releases canceled pincer")
	enemy.spawn_impulse_remaining = 0
	enemy.velocity = Vector2(80,0)
	enemy._update_static_motion(0.12)
	check(view.player.current_animation=="walk" and absf(view.skeleton.get_node("Torso/LegFL/ShinFL").rotation)>0.04,"four-legged gait not articulated")
	check(enemy.rotation==0 and enemy.scale==Vector2.ONE and enemy.modulate.a==1,"flanking rotates physical body")
	enemy.take_damage(1)
	enemy._update_static_motion(0)
	check(view.player.current_animation=="hit" and enemy.should_show_health_bar(),"pincer crab lacks recoil/bar")
	var before: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(before),"paused crab moves")
	paused = false
	var deaths := [0]
	enemy.died.connect(func(_actor,_coins,_source): deaths[0]+=1)
	var at: Transform2D = view.global_transform
	enemy.take_damage(1000)
	enemy.take_damage(1000)
	check(deaths[0]==1 and view.get_parent()==arena and view.global_transform.is_equal_approx(at),"death duplicates or corpse drifts")
	view.player.advance(1)
	await process_frame
	check(not is_instance_valid(view),"native crab corpse leaks")
	arena.free()
	await process_frame
	if not failures:
		print("TEST PASS: FlankingCrabIntegrationTest %d" % checks)
	quit(1 if failures else 0)
