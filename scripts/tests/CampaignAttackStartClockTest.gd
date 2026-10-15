extends SceneTree
## API boundary: a new attack must not consume time from before it existed.
## Artificial 0.60s update is NOT a default fixed-physics hitch reproduction.
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const PlayerActor = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignAttackStartClockTest " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for entry in [[5,"echo_sentinel",80.0],[6,"rift_elite",200.0],[6,"space_cutter",140.0]]:
		await _case(entry)
	print("TEST %s: CampaignAttackStartClockTest %d" % ["PASS" if failures == 0 else "RED",checks])
	quit(1 if failures else 0)

func _case(entry: Array) -> void:
	var label := String(entry[1]) + ": "
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var arena := Node2D.new()
	viewport.add_child(arena)
	var shots := Node2D.new()
	shots.process_mode = Node.PROCESS_MODE_DISABLED
	arena.add_child(shots)
	var player := PlayerActor.new()
	player.position = Vector2(400 + float(entry[2]),400)
	arena.add_child(player)
	player.set_physics_process(false)
	var actor = Factory.create_actor(int(entry[0]),String(entry[1]),0,shots,player)
	actor.position = Vector2(400,400)
	actor.world_bounds = Rect2(-1000,-1000,3000,3000)
	arena.add_child(actor)
	actor.set_physics_process(false)
	await physics_frame
	# Cooldown is consumed by consider(), but the attack is born only afterwards.
	actor.basic_attack.cooldown = 0.4
	actor._update_spitter(0.6,player)
	check(actor.should_show_attack_marker(),label + "new action keeps its warning")
	check(actor.basic_attack.elapsed == 0,label + "startup does not borrow prior-frame time")
	check(shots.get_child_count() == 0 and player.health.current_health == 100,
		label + "startup cannot release or hit")
	var warning_held := true
	for step in range(60):
		actor._update_spitter(1.0/120.0,player)
		warning_held = warning_held and actor.should_show_attack_marker()
	check(warning_held,label + "warning retained through actual subsequent 0.50s")
	check(shots.get_child_count() == 0 and player.health.current_health == 100,
		label + "no release or damage before promised window")
	for step in range(42):
		actor._update_spitter(1.0/120.0,player)
	if String(entry[1]) == "rift_elite":
		check(shots.get_child_count() == 2,label + "original two shards still release")
	else:
		check(player.health.current_health == (85 if int(entry[0]) == 5 else 79),
			label + "stationary control still suffers original damage")
	viewport.free()
	await process_frame
