extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: DashTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	for hz in [30, 60, 120]:
		var player: Node = PlayerScript.new()
		root.add_child(player)
		await process_frame
		player.set_physics_process(false)
		player.global_position = Vector2.ZERO
		player._start_dash(Vector2.RIGHT)
		var delta := 1.0 / float(hz)
		while player.dash_active:
			player._update_dash(delta)
		if not _assert_true(absf(player.global_position.x - 165.0) <= 0.01, "%d Hz dash ended at %.3f" % [hz, player.global_position.x]):
			return
		player.queue_free()
		await process_frame

	var sweep_player: Node = PlayerScript.new()
	root.add_child(sweep_player)
	await process_frame
	sweep_player.set_physics_process(false)
	var enemy: Node = EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.BRUISER, 1, root)
	enemy.global_position = Vector2(82.0, 0.0)
	root.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	var health_before: float = enemy.health.current_health
	sweep_player._start_dash(Vector2.RIGHT)
	sweep_player._update_dash(0.16)
	if not _assert_true(enemy.health.current_health < health_before, "dash sweep missed an enemy crossed between endpoints"):
		return

	sweep_player.queue_free()
	enemy.queue_free()
	await process_frame
	print("TEST PASS: DashTest %d" % assertions)
	quit(0)
