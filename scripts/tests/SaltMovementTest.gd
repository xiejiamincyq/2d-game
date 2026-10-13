extends SceneTree
## Ordinary Player movement against actual reservoir solids at three physics rates.
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
var adjacent_moves := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: SaltMovementTest "+label)
func release() -> void:
	for action in ["move_left","move_right","move_up","move_down","fire","dash_melee"]: Input.action_release(action)
func tick(player: CharacterBody2D,direction: Vector2) -> void:
	release()
	for axis in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
		if axis[1]>0: Input.action_press(axis[0],axis[1])
	var before := player.global_position
	await physics_frame
	await process_frame
	adjacent_moves += 1 if player.global_position.distance_to(before)>0.01 else 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scenes/world/salt_waterway.tscn"
	check(ResourceLoader.exists(path),"salt assembly missing")
	if failures: quit(1); return
	var scene = load(path)
	var original_hz := Engine.physics_ticks_per_second
	for case in [{"hz":30,"seed":0},{"hz":60,"seed":521},{"hz":120,"seed":20261011}]:
		Engine.physics_ticks_per_second = case.hz
		var map = scene.instantiate()
		map.map_seed = case.seed
		root.add_child(map)
		var layout = map.layout
		var rect: Rect2 = layout.get_obstacle_descriptors()[0].rect
		var player := Player.new()
		player.world_bounds = layout.world_bounds
		player.position = Vector2(rect.position.x-55,rect.get_center().y)
		map.add_child(player)
		await physics_frame
		await process_frame
		for _step in ceili(case.hz*0.7): await tick(player,Vector2.RIGHT)
		check(player.global_position.x<=rect.position.x-player.get_body_radius()+0.5,"actual blocked water passed at %sHz"%case.hz)
		check(player.get_slide_collision_count()>0,"input never meets reservoir collider")
		check(player.global_position.x>rect.position.x-55,"player cannot approach bank")
		var previous := adjacent_moves
		var waypoints: Array[Vector2] = [Vector2(rect.position.x-55,rect.position.y-60),Vector2(rect.end.x+55,rect.position.y-60),Vector2(rect.end.x+55,rect.get_center().y)]
		for target in waypoints:
			var reached := false
			for _step in ceili(case.hz*5):
				var offset: Vector2 = target-player.global_position
				if offset.length()<10: reached = true; break
				await tick(player,offset.normalized())
				check(layout.is_position_walkable(player.global_position,player.get_body_radius()-0.5),"ordinary movement embeds player in water")
			check(reached,"%sHz cannot walk around reservoir to %s"%[case.hz,target])
		check(adjacent_moves>previous+10,"input decisions substituted for displacement")
		release()
		map.free()
		await process_frame
	Engine.physics_ticks_per_second = original_hz
	release()
	if not failures: print("TEST PASS: SaltMovementTest %d; %d actual adjacent moves"%[checks,adjacent_moves])
	quit(1 if failures else 0)
