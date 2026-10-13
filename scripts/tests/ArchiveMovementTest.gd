extends SceneTree
## Normal Player inputs only after initial placement; actual two-door routing.
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
var moves := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveMovementTest "+label)
func release() -> void:
	for action in ["move_left","move_right","move_up","move_down","fire","dash_melee"]: Input.action_release(action)
func tick(player: CharacterBody2D,direction: Vector2) -> void:
	release()
	for axis in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
		if axis[1]>0: Input.action_press(axis[0],axis[1])
	var before := player.position; await physics_frame; await process_frame
	if player.position.distance_to(before)>0.01: moves += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	for case in [{"hz":30,"seed":0},{"hz":60,"seed":521},{"hz":120,"seed":20261011}]:
		Engine.physics_ticks_per_second = case.hz
		var map = Map.instantiate(); map.map_seed = case.seed; root.add_child(map)
		var room: Rect2 = map.layout.get_chambers()[0]
		var shelf: Rect2 = map.layout.get_obstacle_descriptors()[0].rect
		var horizontal := shelf.size.x>shelf.size.y
		var normal := Vector2.DOWN if horizontal else Vector2.RIGHT
		var player := Player.new(); player.world_bounds = map.layout.world_bounds
		player.position = shelf.get_center()+normal*(52/2.0+55)
		map.add_child(player); await physics_frame; await process_frame
		for _step in ceili(case.hz*0.7): await tick(player,-normal)
		check(player.get_slide_collision_count()>0,"%sHz never contacts actual shelf"%case.hz)
		check(map.layout.is_position_walkable(player.position,12.5),"shelf collision is penetrated")
		var waypoints: Array[Vector2] = [room.get_center()]
		for door: Rect2 in map.layout.get_doorways().slice(0,2):
			var outward := Vector2(signf(door.get_center().x-room.get_center().x),0) if door.size.x<door.size.y else Vector2(0,signf(door.get_center().y-room.get_center().y))
			waypoints.append(door.get_center()+outward*128)
		waypoints.append(room.get_center())
		var before_route := moves
		for target in waypoints:
			var reached := false
			for _step in ceili(case.hz*8):
				if player.position.distance_to(target)<12: reached = true; break
				await tick(player,map.layout.get_navigation_direction(player.position,target,player.get_body_radius()))
				check(map.layout.is_position_walkable(player.position,12.5),"normal route embeds Player in shelves")
			check(reached,"%sHz fails two-door route to %s"%[case.hz,target])
		check(moves>before_route+20,"input decisions substituted for actual displacement")
		release(); map.free(); await process_frame
	Engine.physics_ticks_per_second = original_hz; release()
	if not failures: print("TEST PASS: ArchiveMovementTest %d; %d actual adjacent moves"%[checks,moves])
	quit(1 if failures else 0)
