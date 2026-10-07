extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const CombatView = preload("res://scripts/systems/CombatView.gd")
var assertions := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAIL: EnemyFlockPolicyTest: " + message)

func spawn_enemy(fixture: Node2D, target: Node2D, kind: int, position_value: Vector2) -> Node:
	var enemy := EnemyScript.new()
	enemy.setup(kind, 0, fixture, target)
	enemy.position = position_value
	fixture.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.shoot_cooldown = 100.0
	return enemy

func _initialize() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var target := Node2D.new()
	target.position = Vector2(800, 0)
	fixture.add_child(target)
	var subject := spawn_enemy(fixture, target, EnemyScript.EnemyKind.SCRAPPER, Vector2.ZERO)
	var dead := spawn_enemy(fixture, target, EnemyScript.EnemyKind.SCRAPPER, Vector2(40, 0))
	dead.death_resolved = true
	dead.velocity = Vector2(0, 211)
	var queued := spawn_enemy(fixture, target, EnemyScript.EnemyKind.SCRAPPER, Vector2(40, -30))
	var freed := spawn_enemy(fixture, target, EnemyScript.EnemyKind.SCRAPPER, Vector2(40, 30))
	var far := spawn_enemy(fixture, target, EnemyScript.EnemyKind.SCRAPPER, Vector2(800, 800))
	far.velocity = Vector2(0, 211)
	var neighbors: Array[Node] = [subject, dead, queued, freed, far]
	queued.queue_free()
	freed.free()
	dead.collision_layer = 0
	dead.collision_mask = 0
	subject.set_neighbor_provider(func() -> Array[Node]: return neighbors)
	await physics_frame
	subject._physics_process(1.0 / 60.0)
	check(subject.velocity.is_equal_approx(Vector2(211.5, 0)), "inactive/distant peers influenced flock motion")
	check(subject.velocity.is_finite(), "invalid neighbor produced non-finite velocity")
	subject.queue_free()
	dead.queue_free()
	far.queue_free()
	await physics_frame
	var ranged := spawn_enemy(fixture, target, EnemyScript.EnemyKind.SPITTER, Vector2.ZERO)
	target.position = Vector2(80, 0)
	var peers: Array[Node] = [ranged]
	for offset in [Vector2(-40, -20), Vector2(-40, 20), Vector2(-70, 0)]:
		var peer := spawn_enemy(fixture, target, EnemyScript.EnemyKind.SPITTER, offset)
		peer.velocity = Vector2(140, 0)
		peers.append(peer)
	ranged.set_neighbor_provider(func() -> Array[Node]: return peers)
	await physics_frame
	ranged._physics_process(1.0 / 60.0)
	check(ranged.velocity.x <= 0.001, "social steering overrode ranged close-distance retreat: %s" % ranged.velocity)
	check(ranged.velocity.length() <= ranged.get_effective_move_speed() + 0.001, "ranged speed exceeded type cap")
	for peer in peers:
		peer.queue_free()
	await physics_frame
	target.position = Vector2(800, 0)
	var mover := spawn_enemy(fixture, target, EnemyScript.EnemyKind.SCRAPPER, Vector2.ZERO)
	var partner := spawn_enemy(fixture, target, EnemyScript.EnemyKind.SCRAPPER, Vector2(70, 70))
	partner.velocity = Vector2(100, 140)
	var pair: Array[Node] = [mover, partner]
	mover.set_neighbor_provider(func() -> Array[Node]: return pair)
	await physics_frame
	mover._physics_process(1.0 / 60.0)
	var before: Vector2 = mover.velocity
	partner.velocity = Vector2(100, -140)
	mover._physics_process(1.0 / 60.0)
	check(mover.velocity.distance_to(before) <= 211.5 * 6.0 / 60.0 + 0.01, "neighbor change caused instantaneous full-speed turn")
	check(mover.velocity.length() <= mover.get_effective_move_speed() + 0.001, "flock exceeded own speed cap")
	mover.apply_burn_stack(10.0, 4.0, 0.30)
	mover._physics_process(1.0 / 60.0)
	check(mover.velocity.length() <= mover.get_effective_move_speed() + 0.001, "flock bypassed burn slow")
	target.position = mover.position + Vector2(20, 0)
	mover._physics_process(1.0 / 60.0)
	check(mover.is_attacking and mover.velocity == Vector2.ZERO, "flock overrode melee attack anchor/stop")
	var camera := Camera2D.new()
	var reference := CombatView.Reference.new()
	reference.visible_rect = Rect2(-640, -360, 1280, 720)
	CombatView.attach(camera, reference)
	fixture.add_child(camera)
	camera.make_current()
	await process_frame
	for kind in [EnemyScript.EnemyKind.SPITTER, EnemyScript.EnemyKind.MARKSMAN, EnemyScript.EnemyKind.LOBBER]:
		for outward in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			for edge_offset in [2.0, -1.0]:
				var edge_enemy := spawn_enemy(fixture, target, kind, Vector2.ZERO)
				var safe_rect: Rect2 = edge_enemy.get_camera_safe_rect()
				var extent := safe_rect.size.x * 0.5 if outward.x != 0.0 else safe_rect.size.y * 0.5
				edge_enemy.position = safe_rect.get_center() + outward * (extent + edge_offset)
				target.position = safe_rect.get_center() + outward * 300.0
				var edge_peers: Array[Node] = [edge_enemy]
				for offset in [Vector2(-40, -20), Vector2(-40, 20), Vector2(-70, 0)]:
					var edge_peer := spawn_enemy(fixture, target, kind, edge_enemy.position + outward * offset.x + outward.orthogonal() * offset.y)
					edge_peer.velocity = outward * 140.0
					edge_peers.append(edge_peer)
				edge_enemy.set_neighbor_provider(func() -> Array[Node]: return edge_peers)
				await physics_frame
				var baseline: Vector2 = edge_enemy._get_ranged_desired_velocity(target.position - edge_enemy.position, safe_rect)
				check(baseline.dot(-outward) > 0.001, "camera boundary fixture has no pre-existing inward return policy")
				edge_enemy._physics_process(1.0 / 60.0)
				check(edge_enemy.velocity.dot(-outward) > 0.001, "flock reversed camera return/edge guard: kind=%s direction=%s offset=%s velocity=%s" % [kind, outward, edge_offset, edge_enemy.velocity])
				check(edge_enemy.velocity.length() <= edge_enemy.get_effective_move_speed() + 0.001, "camera return exceeded effective speed")
				for edge_peer in edge_peers:
					edge_peer.queue_free()
				await physics_frame
	fixture.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("TEST PASS: EnemyFlockPolicyTest %d" % assertions)
	quit(0 if failures == 0 else 1)
