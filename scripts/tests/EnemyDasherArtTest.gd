extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")

const DASHER_A_PATH := "res://assets/art/actors/enemies/enemy_dasher_a_actions_runtime_v1.png"
const DASHER_B_PATH := "res://assets/art/actors/enemies/enemy_dasher_b_actions_runtime_v1.png"
const EXPECTED_MASTER_SIZE := Vector2(1536.0, 1024.0)
const EXPECTED_RUNTIME_SCALE := Vector2(0.125, 0.125)
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
	if not _assert_true(FileAccess.file_exists(DASHER_A_PATH), "Dasher A runtime master is missing"):
		return
	if not _assert_true(FileAccess.file_exists(DASHER_B_PATH), "Dasher B runtime master is missing"):
		return

	var enemy: CharacterBody2D = EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.DASHER, 1, root)
	root.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)

	if not _assert_true(enemy.has_method("set_dasher_variant"), "Dasher does not expose deterministic A/B selection"):
		return
	var visual: Sprite2D = enemy.get("dasher_visual") as Sprite2D
	if not _assert_true(visual != null, "Dasher did not create a Sprite2D visual"):
		return
	if not _assert_true(visual.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "Dasher master is not linearly filtered at runtime scale"):
		return
	if not _assert_true(visual.scale.is_equal_approx(EXPECTED_RUNTIME_SCALE), "Dasher master is not scaled to a 64x64 runtime canvas"):
		return
	if not _assert_true(visual.texture.get_size() == EXPECTED_MASTER_SIZE, "selected Dasher action atlas is not 1536x1024"):
		return
	if not _assert_true(visual.hframes == 3 and visual.vframes == 2, "Dasher action atlas is not configured as a 3x2 grid"):
		return

	enemy.set_dasher_variant(0)
	if not _assert_true(visual.texture.resource_path == DASHER_A_PATH, "variant 0 did not select Dasher A"):
		return
	enemy.set_dasher_variant(1)
	if not _assert_true(visual.texture.resource_path == DASHER_B_PATH, "variant 1 did not select Dasher B"):
		return
	if not _assert_true(is_equal_approx(enemy.body_radius, 14.0), "art integration changed the Dasher collision radius"):
		return
	if not _assert_true(is_equal_approx(enemy.speed, EXPECTED_OVERDRIVE_DASHER_SPEED), "art integration changed the five-minute-overdrive Dasher speed"):
		return
	if not _assert_true(is_equal_approx(enemy.contact_damage, 6.0), "art integration changed Dasher contact damage"):
		return
	if not _assert_true(visual.material is ShaderMaterial, "Dasher visual does not have a white hit-flash material"):
		return
	var second_enemy: CharacterBody2D = EnemyScript.new()
	second_enemy.setup(EnemyScript.EnemyKind.DASHER, 1, root)
	root.add_child(second_enemy)
	await process_frame
	second_enemy.set_physics_process(false)
	var second_visual := second_enemy.get("dasher_visual") as Sprite2D
	var first_material := visual.material as ShaderMaterial
	var second_material := second_visual.material as ShaderMaterial
	if not _assert_true(first_material != second_material, "Dasher hit-flash parameters are not isolated per enemy"):
		return
	if not _assert_true(first_material.shader == second_material.shader, "Dasher instances do not share the compiled hit-flash shader"):
		return
	if not _assert_true(EnemyScript.resolve_dasher_animation_frame(false, 0.0, 0.55, false, 0.0) == 0, "idle frame is not stable"):
		return
	if not _assert_true(EnemyScript.resolve_dasher_animation_frame(false, 0.0, 0.55, true, 0.12) == 1, "run loop did not advance"):
		return
	if not _assert_true(EnemyScript.resolve_dasher_animation_frame(false, 0.0, 0.55, true, 0.23) == 2, "run loop did not reach opposite contact"):
		return
	if not _assert_true(EnemyScript.resolve_dasher_animation_frame(true, 0.2, 0.55, false, 0.0) == 3, "attack windup frame did not resolve"):
		return
	if not _assert_true(EnemyScript.resolve_dasher_animation_frame(true, -0.1, 0.55, false, 0.0) == 4, "attack strike frame did not resolve"):
		return
	if not _assert_true(EnemyScript.resolve_dasher_animation_frame(true, -0.5, 0.55, false, 0.0) == 5, "attack recovery frame did not resolve"):
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

	var flash_material := visual.material as ShaderMaterial
	enemy.take_damage(1.0)
	if not _assert_true(float(flash_material.get_shader_parameter("flash_amount")) > 0.99, "Dasher hit flash did not activate immediately"):
		return
	enemy._physics_process(0.1)
	if not _assert_true(is_zero_approx(float(flash_material.get_shader_parameter("flash_amount"))), "Dasher hit flash did not clear after its timer"):
		return

	player.queue_free()
	second_enemy.queue_free()
	enemy.queue_free()
	await process_frame
	print("TEST PASS: EnemyDasherArtTest %d" % assertions)
	quit(0)
