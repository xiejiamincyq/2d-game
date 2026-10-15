extends SceneTree
## Real factory actors/controllers, isolated physics world, no save or damage nerf.
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const PlayerActor = preload("res://scripts/actors/Player.gd")
const MIN_WARNING := 0.55
const STEP := 1.0 / 120.0
const CASES := [
	[1,"spore_spitter",240.0], [2,"spark_gunner",240.0],
	[3,"salt_needle",280.0], [4,"capsule_planter",240.0],
	[5,"echo_sentinel",80.0], [6,"rift_elite",200.0],
	[6,"space_cutter",140.0],
]
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignRangedWarningTest " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for entry in CASES:
		await _case(int(entry[0]), String(entry[1]), float(entry[2]))
	check(checks >= 70,"all seven real factory cases completed")
	if failures == 0:
		print("TEST PASS: CampaignRangedWarningTest %d" % checks)
	else:
		print("TEST RED: CampaignRangedWarningTest %d failures / %d checks" % [failures,checks])
	quit(1 if failures else 0)

func _case(chapter: int, role: String, distance: float) -> void:
	var label := "chapter %d %s: " % [chapter,role]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var arena := Node2D.new()
	viewport.add_child(arena)
	var shots := Node2D.new()
	# Real deferred capsule placement still runs; unrelated projectile flight does not.
	shots.process_mode = Node.PROCESS_MODE_DISABLED
	arena.add_child(shots)
	var target := PlayerActor.new()
	target.position = Vector2(200 + distance,200)
	arena.add_child(target)
	target.set_physics_process(false)
	var actor = Factory.create_actor(chapter,role,0,shots,target)
	check(actor != null,label + "factory role must exist")
	if actor == null:
		viewport.free()
		return
	actor.position = Vector2(200,200)
	actor.world_bounds = Rect2(-1000,-1000,3000,3000)
	arena.add_child(actor)
	actor.set_physics_process(false)
	await physics_frame
	check(is_equal_approx(target.player_collision.shape.radius,16.9) and
		is_equal_approx(target.get_effective_move_speed(),235),label + "normal player radius/speed")
	check(not target.is_damage_immune() and not target.is_stealthed() and
		not target.dash_active and target.shield == 0,label + "ordinary vulnerable player")
	actor.shoot_cooldown = 0
	actor.basic_attack.cooldown = 0
	_update(actor,target,role,0)
	check(_warning(actor,chapter),label + "real attack enters head-cue warning")
	check(actor.should_show_attack_marker() and actor.world_status.warning != null,
		label + "compact actor-local exclamation node exists")
	var duration: float = actor.ranged_windup_duration if chapter <= 4 else actor.basic_attack.get_warning_duration()
	check(duration >= MIN_WARNING,label + "configured warning >=0.55s, actual=" + str(duration))
	var locked: Vector2 = _locked(actor,chapter)
	# Move the real target during windup, then restore the stationary-hit control.
	target.position.y += 50
	_update(actor,target,role,STEP)
	check(_locked(actor,chapter).is_equal_approx(locked),label + "warning aim stays locked after target moves")
	target.position.y -= 50
	var warning_held := _warning(actor,chapter)
	var births_held := shots.get_child_count() == 0
	var ring_held := true
	var elapsed := STEP
	while elapsed < 0.5 - STEP * 0.5:
		_update(actor,target,role,STEP)
		elapsed += STEP
		warning_held = warning_held and _warning(actor,chapter) and actor.should_show_attack_marker()
		births_held = births_held and shots.get_child_count() == 0
		if chapter == 4:
			births_held = births_held and actor.get_owned_plant_count() == 0
		if chapter == 5:
			ring_held = ring_held and actor.basic_attack.radius == 0 and not actor.basic_attack.is_ring_visible()
	check(warning_held,label + "actual warning remains visible through 0.50s")
	check(births_held,label + "no projectile or capsule release through 0.50s")
	check(target.health.current_health == 100,label + "no real player damage through 0.50s")
	if chapter == 5:
		check(ring_held,label + "echo radius stays zero throughout warning, no hardcoded-clock early ring")
	# Once the promised warning ends, unchanged attacks must genuinely release/hit.
	while elapsed < maxf(duration,MIN_WARNING) + 0.35:
		_update(actor,target,role,STEP)
		elapsed += STEP
	if chapter <= 4 or role == "rift_elite":
		check(shots.get_child_count() > 0 or (chapter == 4 and actor.get_owned_plant_count() > 0),
			label + "attack not silently removed to satisfy warning")
		if chapter != 4:
			var expected_damage: float = {1:21.0,2:9.0,3:36.0,6:12.0}[chapter]
			for shot in shots.get_children():
				check(shot.damage == expected_damage,label + "original projectile damage retained")
	else:
		var expected_health := 85.0 if chapter == 5 else 79.0
		check(target.health.current_health == expected_health,label + "stationary normal player takes original 15/21 attack damage")
	print("WARNING CASE: %s duration=%.3f held=%.3f health=%.1f births=%d" %
		[label,duration,elapsed,target.health.current_health,shots.get_child_count()])
	viewport.free()
	await process_frame

func _update(actor: Node, target: Node2D, role: String, delta: float) -> void:
	if role == "salt_needle":
		actor._update_marksman(delta,target)
	else:
		actor._update_spitter(delta,target)

func _warning(actor: Node, chapter: int) -> bool:
	return actor.ranged_is_winding_up if chapter <= 4 else actor.basic_attack.stage == actor.basic_attack.Stage.WARNING

func _locked(actor: Node, chapter: int) -> Vector2:
	if chapter == 4: return actor.planned_plant_position
	if chapter <= 3: return actor.ranged_target_position
	if chapter == 5: return actor.basic_attack.origin
	if actor.basic_attack.get("target_position") != null: return actor.basic_attack.target_position
	return actor.basic_attack.direction
