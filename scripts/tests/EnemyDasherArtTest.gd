extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")

const DASHER_A_PATH := "res://assets/art/actors/enemies/enemy_dasher_a.png"
const DASHER_B_PATH := "res://assets/art/actors/enemies/enemy_dasher_b.png"
const EXPECTED_MASTER_SIZE := Vector2(1024.0, 1024.0)
const EXPECTED_RUNTIME_SCALE := Vector2(0.0625, 0.0625)

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
	if not _assert_true(visual.texture.get_size() == EXPECTED_MASTER_SIZE, "selected Dasher master is not 1024x1024"):
		return

	enemy.set_dasher_variant(0)
	if not _assert_true(visual.texture.resource_path == DASHER_A_PATH, "variant 0 did not select Dasher A"):
		return
	enemy.set_dasher_variant(1)
	if not _assert_true(visual.texture.resource_path == DASHER_B_PATH, "variant 1 did not select Dasher B"):
		return
	if not _assert_true(is_equal_approx(enemy.body_radius, 14.0), "art integration changed the Dasher collision radius"):
		return
	if not _assert_true(is_equal_approx(enemy.speed, 149.0), "art integration changed wave-one Dasher speed"):
		return
	if not _assert_true(is_equal_approx(enemy.contact_damage, 6.0), "art integration changed Dasher contact damage"):
		return

	enemy.queue_free()
	await process_frame
	print("TEST PASS: EnemyDasherArtTest %d" % assertions)
	quit(0)
