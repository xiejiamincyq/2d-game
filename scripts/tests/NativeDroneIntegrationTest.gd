extends SceneTree
const PlayerSource = preload("res://scripts/actors/Player.gd")
class Target extends Node2D:
	var damage_received := 0.0
	func take_damage(amount: float,_type: String) -> void: damage_received += amount
	func get_body_radius() -> float: return 14
var assertions := 0
var failures := 0
func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativeDroneIntegrationTest "+message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var player = PlayerSource.new()
	player.projectile_parent = fixture
	player.world_bounds = Rect2(-1000,-1000,2000,2000)
	fixture.add_child(player)
	player.set_physics_process(false)
	player.drone_count = 2
	player._sync_drone_visuals()
	check(player.drone_visuals.size()==2 and player.drone_visuals[0].has_method("get_visual_node"),"actual Player still creates legacy drawn companion")
	if failures:
		fixture.free()
		quit(1)
		return
	var drone = player.drone_visuals[0]
	var view = drone.get_visual_node()
	check(view.scene_file_path=="res://scenes/actors/native/ranger_drone_paper_v1.tscn","wrong production companion scene")
	check(view.player.current_animation=="entrance","new companion has no fold-out entrance")
	player.visual_elapsed = 0.3
	player._update_drone_positions()
	var frozen_position: Vector2 = drone.position
	await process_frame
	await process_frame
	player._update_drone_positions()
	check(drone.position.is_equal_approx(frozen_position),"orbit reads wall clock during frozen gameplay")
	check(is_equal_approx(drone.position.length(),48) and player.drone_visuals[1].position.is_equal_approx(-drone.position),"orbit radius/spacing changed")
	player._update_drone_lasers(0.4)
	check(view.player.current_animation=="walk" and not player.drone_lasers[0].visible,"no-target companion firing")
	player.visual_elapsed += 0.1
	player._update_drone_positions()
	check(not drone.position.is_equal_approx(frozen_position),"authoritative gameplay time does not move orbit")
	var target := Target.new()
	target.position = drone.global_position+Vector2(300,0)
	fixture.add_child(target)
	player.set_enemy_provider(func() -> Array[Node]: return [target])
	player._update_drone_lasers(0.1)
	check(view.player.current_animation=="shoot" and player.drone_lasers[0].visible,"live laser does not drive companion shot pose")
	check(target.damage_received>0 and is_equal_approx(player.drone_damage,28.8),"visual migration alters laser damage")
	var before_damage := target.damage_received
	var wing: Bone2D = view.get_node("Facing/Skeleton2D/Torso/WingL")
	var pose := wing.transform
	await process_frame
	await process_frame
	check(wing.transform.is_equal_approx(pose) and is_equal_approx(target.damage_received,before_damage),"companion owns autonomous damage/animation clock")
	player.set_enemy_provider(func() -> Array[Node]: return [])
	player._update_drone_lasers(0.05)
	check(view.player.current_animation=="walk" and not player.drone_lasers[0].visible,"lost target leaves firing pose/beam")
	drone.advance_visual(NAN,true)
	check(view.player.current_animation=="walk","invalid visual clock accepted")
	player.drone_count = 0
	player._sync_drone_visuals()
	await process_frame
	await process_frame
	check(not is_instance_valid(drone) and player.drone_lasers.is_empty() and player.drone_reticles.is_empty(),"removal leaks companion/beam/reticle")
	fixture.free()
	await process_frame
	if failures==0: print("TEST PASS: NativeDroneIntegrationTest %d"%assertions)
	quit(1 if failures else 0)
