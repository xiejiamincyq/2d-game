extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")

const DASHER_PATH := "res://scenes/actors/native/cinder_runner_paper_v1.tscn"
const EXPECTED_RUNTIME_SCALE := Vector2.ONE
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
	if not _assert_true(FileAccess.file_exists(DASHER_PATH), "new native Dasher resource is missing"):
		return

	var enemy: CharacterBody2D = EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.DASHER, 1, root)
	root.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)

	var visual: Node2D = enemy.native_visual
	if not _assert_true(visual != null and enemy.static_visual == null, "Dasher still uses the old raster"):
		return
	if not _assert_true(visual.scene_file_path == DASHER_PATH, "Dasher loaded incorrect native resource"):
		return
	if not _assert_true(visual.skeleton.get_bone_count() == 15, "Dasher does not have 15 articulated bones"):
		return
	if not _assert_true(visual.scale.is_equal_approx(EXPECTED_RUNTIME_SCALE), "Dasher runtime scale drifted"):
		return
	if not _assert_true(is_equal_approx(enemy.body_radius, 14.0), "art integration changed the Dasher collision radius"):
		return
	if not _assert_true(is_equal_approx(enemy.speed, EXPECTED_OVERDRIVE_DASHER_SPEED), "art integration changed the five-minute-overdrive Dasher speed"):
		return
	if not _assert_true(is_equal_approx(enemy.contact_damage, 18.0), "art integration changed Dasher contact damage"):
		return

	var player := Node2D.new()
	player.add_to_group("player")
	root.add_child(player)
	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(120.0, 0.0)
	enemy._physics_process(0.0)
	if not _assert_true(visual.get_node("Facing").scale.x == 1, "right-facing native body flipped"):
		return
	player.global_position = Vector2(-120.0, 0.0)
	enemy._physics_process(0.0)
	if not _assert_true(visual.get_node("Facing").scale.x == -1, "Dasher did not mirror toward left target"):
		return

	var collision_shape := enemy.get_child(enemy.get_child_count() - 1) as CollisionShape2D
	var radius_before: float = (collision_shape.shape as CircleShape2D).radius
	var leg: Bone2D = visual.skeleton.get_node("Torso/LegL/ShinL")
	var leg_before: Transform2D = leg.transform
	enemy.velocity = Vector2.RIGHT * 100.0
	enemy._update_static_motion(0.12)
	if not _assert_true(not leg.transform.is_equal_approx(leg_before) and visual.position == Vector2.ZERO, "Dasher lacks native gait or moves its visual root"):
		return
	if not _assert_true(is_equal_approx((collision_shape.shape as CircleShape2D).radius, radius_before), "visual animation changed Dasher collision"):
		return

	var flash_material := visual.get_node("Facing/Skin").material as ShaderMaterial
	enemy.take_damage(1.0)
	if not _assert_true(is_equal_approx(float(flash_material.get_shader_parameter("flash_amount")), 0.35), "Dasher palette-preserving hit flash did not activate immediately"):
		return
	enemy._physics_process(0.1)
	if not _assert_true(is_zero_approx(float(flash_material.get_shader_parameter("flash_amount"))), "Dasher hit flash did not clear after its timer"):
		return

	player.queue_free()
	enemy.queue_free()
	await process_frame
	print("TEST PASS: EnemyDasherArtTest %d" % assertions)
	quit(0)
