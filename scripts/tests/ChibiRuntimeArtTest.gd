extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const CombatVfxScript = preload("res://scripts/effects/CombatVfx.gd")

const PLAYER_ATLAS_PATH := "res://assets/art/actors/player/player_chibi_b_cardinal_atlas_v1.png"
const PLAYER_WEAPON_PATH := "res://assets/art/actors/player/player_chibi_b_weapon_cardinal_atlas_v1.png"
const SCRAPPER_PATH := "res://assets/art/actors/enemies/enemy_scrapper_chibi_b_v1.png"
const BRUISER_PATH := "res://assets/art/actors/enemies/enemy_bruiser_chibi_b_v1.png"
const DASHER_PATH := "res://assets/art/actors/enemies/enemy_dasher_chibi_b_v1.png"
const SPITTER_PATH := "res://assets/art/actors/enemies/enemy_spitter_chibi_b_v1.png"
const MARKSMAN_PATH := "res://assets/art/actors/enemies/enemy_marksman_chibi_b_v1.png"
const LOBBER_PATH := "res://assets/art/actors/enemies/enemy_lobber_chibi_b_v1.png"
const OVERSEER_PATH := "res://assets/art/actors/enemies/enemy_overseer_chibi_b_v1.png"
const HIT_EFFECT_PATH := "res://assets/art/effects/combat_hit_chibi_b_v1.png"

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: ChibiRuntimeArtTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	for path in [PLAYER_ATLAS_PATH, PLAYER_WEAPON_PATH, SCRAPPER_PATH, BRUISER_PATH, DASHER_PATH, SPITTER_PATH, MARKSMAN_PATH, LOBBER_PATH, OVERSEER_PATH, HIT_EFFECT_PATH]:
		if not _assert_true(FileAccess.file_exists(path), "missing B-style runtime asset: " + path):
			return

	var player: CharacterBody2D = PlayerScript.new()
	root.add_child(player)
	await process_frame
	if not _assert_true(player.player_body_texture.resource_path == PLAYER_ATLAS_PATH, "player did not load the four-direction body atlas"):
		return
	if not _assert_true(player.player_weapon_texture.resource_path == PLAYER_WEAPON_PATH, "player did not load the separate weapon texture"):
		return
	if not _assert_true(player.player_body_texture.get_size() == Vector2(256, 256), "player body atlas is not a 2x2 128px grid"):
		return
	if not _assert_true(player.player_weapon_texture.get_size() == Vector2(256, 256), "player weapon atlas is not a 2x2 128px grid"):
		return
	if not _assert_true(CombatVfxScript.HIT_TEXTURE.resource_path == HIT_EFFECT_PATH, "combat spark did not load the B-style hit effect"):
		return

	for fixture in [
		{"angle": 0.0, "index": 3, "rect": Rect2(128.0, 128.0, 128.0, 128.0)},
		{"angle": 90.0, "index": 0, "rect": Rect2(0.0, 0.0, 128.0, 128.0)},
		{"angle": 180.0, "index": 2, "rect": Rect2(0.0, 128.0, 128.0, 128.0)},
		{"angle": 270.0, "index": 1, "rect": Rect2(128.0, 0.0, 128.0, 128.0)},
	]:
		var angle := deg_to_rad(float(fixture.angle))
		if not _assert_true(player.chibi_cardinal_index(angle) == int(fixture.index), "cardinal mapping drifted at %d degrees" % int(fixture.angle)):
			return
		if not _assert_true(player.chibi_cardinal_rect(int(fixture.index)) == fixture.rect, "cardinal atlas rectangle drifted"):
			return
		if not _assert_true(player.chibi_weapon_rect(int(fixture.index)) == fixture.rect, "weapon atlas did not follow the body cardinal frame"):
			return
		var weapon_offset: Vector2 = player.chibi_weapon_offset(int(fixture.index))
		if not _assert_true(weapon_offset.dot(Vector2.RIGHT.rotated(angle)) > 0.0, "weapon socket did not stay on the aimed side of the body"):
			return
		if not _assert_true(weapon_offset.length() <= 20.0, "weapon socket detached too far from the hands"):
			return

	var enemies: Array[CharacterBody2D] = []
	for fixture in [
		{"kind": EnemyScript.EnemyKind.SCRAPPER, "path": SCRAPPER_PATH},
		{"kind": EnemyScript.EnemyKind.DASHER, "path": DASHER_PATH},
		{"kind": EnemyScript.EnemyKind.SPITTER, "path": SPITTER_PATH},
		{"kind": EnemyScript.EnemyKind.BRUISER, "path": BRUISER_PATH},
		{"kind": EnemyScript.EnemyKind.MARKSMAN, "path": MARKSMAN_PATH},
		{"kind": EnemyScript.EnemyKind.LOBBER, "path": LOBBER_PATH},
		{"kind": EnemyScript.EnemyKind.OVERSEER, "path": OVERSEER_PATH},
	]:
		var enemy := await _spawn_enemy(int(fixture.kind))
		enemies.append(enemy)
		if not _assert_true(enemy.static_visual.texture.resource_path == fixture.path, "enemy did not use its B-style art: " + fixture.path):
			return
	var bruiser: CharacterBody2D = enemies[3]
	var collision_shape := bruiser.get_child(bruiser.get_child_count() - 1) as CollisionShape2D
	var radius_before: float = (collision_shape.shape as CircleShape2D).radius
	var visual_position_before: Vector2 = bruiser.static_visual.position
	bruiser.velocity = Vector2.RIGHT * 100.0
	bruiser._update_static_motion(0.12)
	if not _assert_true(bruiser.static_visual.position != visual_position_before, "moving static enemy received no lightweight walk animation"):
		return
	if not _assert_true(is_equal_approx((collision_shape.shape as CircleShape2D).radius, radius_before), "visual animation changed enemy collision"):
		return

	player.queue_free()
	for enemy in enemies:
		enemy.queue_free()
	await process_frame
	print("TEST PASS: ChibiRuntimeArtTest %d" % assertions)
	quit(0)

func _spawn_enemy(kind: int) -> CharacterBody2D:
	var enemy: CharacterBody2D = EnemyScript.new()
	enemy.setup(kind, 1, root)
	root.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	return enemy
