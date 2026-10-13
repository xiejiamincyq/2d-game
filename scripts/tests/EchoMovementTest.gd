extends SceneTree
## Actual Player: ordinary inputs after initial placement, current full radius.
const Map = preload("res://scenes/world/echo_court.tscn")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
var moves := 0
static func has_clearance(point: Vector2,bounds: Rect2,entries: Array[Dictionary],radius: float) -> bool:
	# Independent true circle/rectangle oracle; 0.05 only admits contact jitter.
	var margin := radius-0.05
	if not bounds.grow(-margin).has_point(point): return false
	for entry in entries:
		var rect: Rect2 = entry.rect
		if point.distance_to(point.clamp(rect.position,rect.end))<margin: return false
	return true
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoMovementTest "+label)
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
		var entries: Array[Dictionary] = map.layout.get_obstacle_descriptors()
		var stone: Rect2 = entries[0].rect
		var player := Player.new(); player.world_bounds = map.layout.world_bounds
		player.position = stone.get_center()+Vector2.RIGHT*(stone.size.x/2+55)
		map.add_child(player); await physics_frame; await process_frame
		check(is_equal_approx(player.get_body_radius(),16.9) and is_equal_approx(player.move_speed,235),"fixture changes actual radius or movement")
		for _step in ceili(case.hz*0.6): await tick(player,Vector2.LEFT)
		check(player.get_slide_collision_count()>0,"%sHz fails to contact actual pillar"%case.hz)
		check(has_clearance(player.position,map.layout.world_bounds,entries,player.get_body_radius()),"contact penetrates actual full body")
		var gates: Array[Dictionary] = map.layout.get_gateways()
		var targets: Array[Vector2] = [gates[0].inside,gates[0].outside,gates[1].inside]
		var before_route := moves
		for target in targets:
			var reached := false
			for _step in ceili(case.hz*18):
				if player.position.distance_to(target)<12: reached = true; break
				await tick(player,map.layout.get_navigation_direction(player.position,target,player.get_body_radius()))
				check(has_clearance(player.position,map.layout.world_bounds,entries,player.get_body_radius()),"normal input embeds full Player in pillar")
			check(reached,"%sHz fails ordinary ring crossing to %s"%[case.hz,target])
		check(moves>before_route+20,"input decisions replace real movement")
		print("ECHO MOVEMENT CASE: %sHz seed=%s moves=%s"%[case.hz,case.seed,moves-before_route])
		release(); map.free(); await process_frame
	Engine.physics_ticks_per_second = original_hz; release()
	if not failures: print("TEST PASS: EchoMovementTest %d; %d actual adjacent moves"%[checks,moves])
	quit(1 if failures else 0)
