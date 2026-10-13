extends SceneTree
const Enemy = preload("res://scripts/actors/Enemy.gd")
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const Boss = preload("res://scripts/actors/OverseerBoss.gd")
const Vine = preload("res://scripts/actors/NurseryVineBoss.gd")
const Furnace = preload("res://scripts/actors/FoundryFurnaceBoss.gd")
class Target extends Node2D:
	var health: Node = null
	var stealthed := false
	func is_stealthed() -> bool: return stealthed
	func take_damage(_amount: float) -> bool: return true
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: EnemyWorldStatusTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena := Node2D.new(); arena.y_sort_enabled = true; root.add_child(arena)
	var target := Target.new(); target.position = Vector2(370,300); arena.add_child(target)
	var enemies: Array[Node2D] = []
	for kind in 7:
		var actor := Enemy.new(); actor.setup(kind,0,arena,target); enemies.append(actor)
	var roles := [["root_pursuer","spore_spitter"],["slag_charger","spark_gunner"],["flanking_crab","salt_needle"],["splitting_mote","capsule_planter"],["echo_sentinel","circling_shade"],["rift_elite","space_cutter"]]
	for chapter in 6:
		for role in roles[chapter]: enemies.append(Factory.create_actor(chapter+1,role,0,arena,target))
	for actor in enemies:
		actor.position = Vector2(320,300)
		arena.add_child(actor); actor.set_physics_process(false)
		var at: Transform2D = actor.transform; var body_z: int = actor.z_index
		var radius: float = actor.body_radius; var visual: Node = actor.get_visual_node()
		var hint: Node = actor.get_node_or_null("WorldStatus")
		check(hint!=null and hint==actor.world_status,"every base/regional entry owns hints")
		if hint==null: continue
		check(hint.position==Vector2.ZERO and not hint.z_as_relative and hint.z_index>22,"actor-local status above world shots")
		check(hint.warning.z_index>hint.z_index and not hint.warning.z_as_relative,"warning above neighbour bars")
		check(hint._last_state[0]==actor.should_show_health_bar(),"original visibility policy")
		actor.take_damage(actor.health.max_health*0.25)
		check(actor.should_show_health_bar() and is_equal_approx(hint._last_state[2],0.75),"real damage updates hint synchronously")
		actor.health.heal(actor.health.max_health)
		await process_frame; await process_frame
		check(hint._last_state[0]==actor.should_show_health_bar(),"healing follows full-health bruiser policy")
		if actor.should_show_health_bar(): check(is_equal_approx(hint._last_state[2],1),"healing updates ratio without parent redraw")
		# Controlled real action starts test display/lifecycle, not natural AI.
		actor.basic_attack.cancel(); actor.charge_attack.cancel()
		if actor.kind==Enemy.EnemyKind.DASHER:
			actor.charge_attack.stage = actor.charge_attack.Stage.WARNING
		elif actor.get_script().resource_path.get_file() in ["RiftEliteEnemy.gd","SpaceCutterEnemy.gd"]:
			actor.basic_attack.cooldown = 0; actor.basic_attack.consider(actor,target,0.01)
		elif actor.kind==Enemy.EnemyKind.SCRAPPER or actor.get_script().resource_path.get_file()=="EchoSentinelEnemy.gd":
			actor.basic_attack.begin(actor,target,actor.basic_attack.Move.CLAW)
		else: actor.ranged_is_winding_up = true
		actor._queue_visual_redraw()
		check(actor.should_show_attack_marker() and hint._last_state[3],"live family state drives hint")
		paused = true; await process_frame; await process_frame
		check(hint._last_state[3] and actor.transform==at,"ordinary enemy warning freezes with combat")
		paused = false; target.stealthed = true; await process_frame; await process_frame
		check(not actor.should_show_attack_marker() and not hint._last_state[3],"hidden target withdraws hint")
		target.stealthed = false
		actor.basic_attack.cancel(); actor.charge_attack.cancel(); actor.ranged_is_winding_up = false; actor._queue_visual_redraw()
		check(not hint._last_state[3],"cancel removes stale hint")
		check(actor.transform==at and actor.z_index==body_z and actor.body_radius==radius and actor.get_visual_node()==visual and visual.show_behind_parent,"hints leave body/physics sorting untouched")
		actor.take_damage(1e9)
		check(not actor.should_show_health_bar() and not actor.should_show_attack_marker(),"dead actor hides hints")
		await process_frame
		check(not is_instance_valid(hint),"status freed with actor, corpse owns no hint")
	# Mote death above legitimately births live child bodies near (350,300).
	# A status-only Boss fixture needs a separate clear, in-range target point;
	# do not demand that Escape approve a target embedded in those children.
	target.position = Vector2(120,0)
	for script in [Boss,Vine,Furnace]:
		var actor = script.new(); actor.setup(0,arena,target); arena.add_child(actor); actor.set_physics_process(false)
		var hint = actor.world_status
		check(hint!=null and not hint._has_health,"boss world hint does not duplicate fixed HUD bar")
		if script!=Boss:
			actor.attack_director.advance(1.41); actor._update_entrance_reveal()
			var probe := PhysicsShapeQueryParameters2D.new(); var probe_shape := CircleShape2D.new(); probe_shape.radius = 17
			probe.shape = probe_shape; probe.transform = Transform2D(0,target.global_position); probe.collision_mask = 1
			var contacts: Array = actor.get_world_2d().direct_space_state.intersect_shape(probe,32)
			check(contacts.is_empty(),"Boss status target has a real unobstructed body footprint")
			check(actor.attack_director.start_action(&"jet" if script==Furnace else &"lash"),"real Boss action begins")
			await process_frame; await process_frame
			check(hint._last_state[3],"real Boss short warning displayed")
			paused = true; await process_frame; await process_frame
			check(hint._last_state[3]==actor.should_show_attack_marker(),"paused controller changes invalidate cached hint")
			if script==Furnace: check(not hint._last_state[3],"Furnace pause clears its cancelled cue")
			paused = false
			actor.attack_director.cancel_action(); await process_frame; await process_frame
			check(not hint._last_state[3],"Boss cancel removes stale warning")
		else: check(not actor.should_show_attack_marker(),"legacy Boss cue contract unchanged")
		actor.queue_free(); await process_frame
		check(not is_instance_valid(hint),"Boss departure frees status")
	# Remove the arena including detached death visuals; no orphan status nodes.
	arena.queue_free(); await process_frame; await process_frame
	if failures==0: print("TEST PASS: EnemyWorldStatusTest %d"%checks)
	quit(0 if failures==0 else 1)
