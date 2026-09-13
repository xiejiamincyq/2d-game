extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const ObstacleScript = preload("res://scripts/world/ArenaObstacle.gd")
var assertions := 0

func check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerOcclusionOutlineTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var path := "res://scripts/art/PlayerOcclusionOutline.gd"
	if not check(FileAccess.file_exists(path), "runtime outline component missing"):
		return
	var fixture := Node2D.new()
	root.add_child(fixture)
	var enemies := Node2D.new()
	var obstacles := Node2D.new()
	fixture.add_child(enemies)
	fixture.add_child(obstacles)
	var player := PlayerScript.new()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	fixture.add_child(player)
	var enemy := EnemyScript.new()
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.setup(EnemyScript.EnemyKind.OVERSEER, 1, fixture, player)
	enemies.add_child(enemy)
	await process_frame
	var outline = load(path).new()
	player.add_child(outline)
	outline.setup(player, enemies, obstacles)
	if not check(outline.z_index > 20, "decorative combat effects cover the locator contour"):
		return
	for entry in [[Vector2(0, 24), true], [Vector2(0, -24), false], [Vector2(180, 24), false]]:
		enemy.position = entry[0]
		outline._process(0.0)
		if not check(outline.visible == entry[1], "foreground overlap visibility incorrect"):
			return
	enemy.position = Vector2(0, 24)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		player.gun_angle = angle
		outline._process(0.0)
		if not check(outline.texture.region == player.chibi_cardinal_rect(player.chibi_cardinal_index(angle)), "outline facing mismatch"):
			return
	player.stealth_remaining = 1.0
	outline._process(0.0)
	if not check(not outline.visible, "outline reveals stealth"):
		return
	player.stealth_remaining = 0.0
	player.velocity = Vector2(100.0, 0.0)
	player.visual_elapsed = 0.13
	outline._process(0.0)
	if not check(outline.position.is_equal_approx(player.get_body_visual_center()), "outline detached from moving body"):
		return
	enemy.hide()
	outline._process(0.0)
	if not check(not outline.visible, "invisible enemy triggers outline"):
		return
	enemy.show()
	player.entrance_active = true
	outline._process(0.0)
	if not check(not outline.visible, "outline shows during entrance"):
		return
	player.entrance_active = false
	var obstacle := ObstacleScript.new()
	obstacle.setup(Rect2(-60, -60, 120, 100), &"tank")
	obstacles.add_child(obstacle)
	outline._process(0.0)
	if not check(not outline.visible, "outline penetrates foreground terrain"):
		return
	obstacle.position.x = 300.0
	outline._process(0.0)
	if not check(outline.visible and player.modulate.a == 1.0 and enemy.modulate.a == 1.0, "outline alters actor opacity or remains hidden"):
		return
	player.health.died.emit()
	if not check(not outline.visible, "death did not immediately clear contour before pause"):
		return
	player.health.current_health = 0.0
	outline._process(0.0)
	if not check(not outline.visible, "outline shows on dead player"):
		return
	player.queue_free()
	await process_frame
	if not check(not is_instance_valid(outline), "outline outlives player"):
		return
	fixture.queue_free()
	await process_frame
	print("TEST PASS: PlayerOcclusionOutlineTest %d" % assertions)
	quit(0)
