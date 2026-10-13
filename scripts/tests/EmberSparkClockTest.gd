extends SceneTree
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
func _initialize() -> void:
	Engine.max_fps = 60
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	var shots := Node2D.new()
	arena.add_child(shots)
	var target := Node2D.new()
	target.position = Vector2(260,0)
	arena.add_child(target)
	var enemy = Factory.create_actor(2,"spark_gunner",0,shots,target)
	enemy.shoot_cooldown = 0
	enemy.world_bounds = Rect2(-650,-450,1300,900)
	arena.add_child(enemy)
	var observed := {"warning":0,"shot":0}
	shots.child_entered_tree.connect(func(_node):
		if observed.shot==0:
			observed.shot = Time.get_ticks_usec()
	)
	var started := Time.get_ticks_usec()
	while observed.shot==0 and Time.get_ticks_usec()-started<2500000:
		if enemy.ranged_is_winding_up and observed.warning==0:
			observed.warning = Time.get_ticks_usec()
		await process_frame # Real actor physics, never manually advance attacks.
	check(observed.warning>0 and observed.shot>observed.warning,"actual engine does not expose short warning then fan")
	if observed.warning>0 and observed.shot>observed.warning:
		var delay: float = (observed.shot-observed.warning)/1000000.0
		check(delay>=0.145 and delay<=0.25,"actual actor warning has a second clock or stalls")
		print("EmberSparkClockTest actual_warning=%.6f" % delay)
	check(shots.get_child_count()==3,"actual engine fan does not emit three unique sparks")
	check(enemy.native_visual.player.current_animation=="attack" and not enemy.should_show_attack_marker(),"actual emission not bound to new attack pose")
	arena.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(arena),"actual actor fixture leaks")
	for failure in failures:
		push_error("TEST FAIL: EmberSparkClockTest "+failure)
	if failures.is_empty():
		print("TEST PASS: EmberSparkClockTest %d" % checks)
	quit(0 if failures.is_empty() else 1)
