extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")

const DASHER_PATH := "res://assets/art/actors/enemies/enemy_dasher_chibi_b_v1.png"
const EXPECTED_RUNTIME_SCALE := Vector2(0.5, 0.5)
const EXPECTED_OVERDRIVE_DASHER_SPEED := 235.0 * 1.10

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: EnemyDasherArtTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(FileAccess.file_exists(DASHER_PATH), "B-style Dasher runtime sprite is missing"):
		return

	var enemy: CharacterBody2D = EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.DASHER, 1, root)
	root.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)

	var visual := enemy.static_visual as Sprite2D
	if not _assert_true(visual != null, "Dasher did not use the shared static-sprite path"):
		return
	if not _assert_true(visual.texture.resource_path == DASHER_PATH, "Dasher did not load the B-style sprite"):
		return
	if not _assert_true(visual.texture.get_size() == Vector2(128, 128), "Dasher sprite is not 128x128"):
		return
	if not _assert_true(visual.scale.is_equal_approx(EXPECTED_RUNTIME_SCALE), "Dasher runtime scale drifted"):
		return
	if not _assert_true(is_equal_approx(enemy.body_radius, 14.0), "art integration changed the Dasher collision radius"):
		return
	if not _assert_true(is_equal_approx(enemy.speed, EXPECTED_OVERDRIVE_DASHER_SPEED), "art integration changed the five-minute-overdrive Dasher speed"):
		return
	if not _assert_true(is_equal_approx(enemy.contact_damage, 6.0), "art integration changed Dasher contact damage"):
		return

	var player := Node2D.new()
	player.add_to_group("player")
	root.add_child(player)
	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(120.0, 0.0)
	enemy._physics_process(0.0)
	if not _assert_true(not visual.flip_h, "right-facing master flipped while the player was to the right"):
		return
	player.global_position = Vector2(-120.0, 0.0)
	enemy._physics_process(0.0)
	if not _assert_true(visual.flip_h, "Dasher did not flip toward a player on its left"):
		return

	var collision_shape := enemy.get_child(enemy.get_child_count() - 1) as CollisionShape2D
	var radius_before: float = (collision_shape.shape as CircleShape2D).radius
	var visual_position_before := visual.position
	enemy.velocity = Vector2.RIGHT * 100.0
	enemy._update_static_motion(0.12)
	if not _assert_true(visual.position != visual_position_before, "Dasher received no lightweight walk animation"):
		return
	if not _assert_true(is_equal_approx((collision_shape.shape as CircleShape2D).radius, radius_before), "visual animation changed Dasher collision"):
		return

	var flash_material := visual.material as ShaderMaterial
	enemy.take_damage(1.0)
	if not _assert_true(float(flash_material.get_shader_parameter("flash_amount")) > 0.99, "Dasher hit flash did not activate immediately"):
		return
	enemy._physics_process(0.1)
	if not _assert_true(is_zero_approx(float(flash_material.get_shader_parameter("flash_amount"))), "Dasher hit flash did not clear after its timer"):
		return

	player.queue_free()
	enemy.queue_free()
	await process_frame
	print("TEST PASS: EnemyDasherArtTest %d" % assertions)
	quit(0)
