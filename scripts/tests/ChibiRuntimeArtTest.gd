extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const CombatVfxScript = preload("res://scripts/effects/CombatVfx.gd")
const BossScript = preload("res://scripts/actors/OverseerBoss.gd")

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
	if not _assert_true(player.get_visual_node().scene_file_path == "res://scenes/actors/native/player_paper_v1.tscn", "player did not load the new four-facing native actor"):
		return
	if not _assert_true(player.player_body_texture == null and player.player_weapon_texture == null, "player still loads old atlases instead of actual bones"):
		return
	if not _assert_true(player.get_visual_node().get_node("Front/Skeleton2D").get_bone_count() == 13, "native player lacks body/hand weapon chain"):
		return
	if not _assert_true(player.get_visual_node().scale == Vector2.ONE * player.PLAYER_SIZE_SCALE, "native player scale drifted"):
		return
	if not _assert_true(CombatVfxScript.HIT_TEXTURE.resource_path == HIT_EFFECT_PATH, "combat spark did not load the B-style hit effect"):
		return
	var boss: Node2D = BossScript.new()
	boss.setup(6, root, player)
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(boss)
	await process_frame
	if not _assert_true(boss.boss_visual.texture.resource_path == OVERSEER_PATH, "final Boss still uses legacy mechanical art instead of the B-style warden"):
		return
	var boss_transform: Transform2D = boss.global_transform
	var boss_health: float = boss.health.current_health
	var boss_collision: CircleShape2D
	for child in boss.get_children():
		if child is CollisionShape2D:
			boss_collision = child.shape as CircleShape2D
	boss.entrance_resolved = true
	boss.velocity = Vector2.RIGHT * 63.8
	boss._update_boss_motion(0.12)
	if not _assert_true(boss.boss_visual.position.y < 0.0 and absf(boss.boss_visual.position.y) <= 2.0, "moving Boss has no bounded visual walk pose"):
		return
	if not _assert_true(boss.global_transform == boss_transform and boss_collision != null and is_equal_approx(boss_collision.radius, 56.0) and is_equal_approx(boss.health.current_health, boss_health), "Boss animation changed body transform, collision or health"):
		return
	boss._update_visual_facing(boss.global_position + Vector2.LEFT * 100)
	if not _assert_true(boss.boss_visual.flip_h, "Boss art did not face a left-side player"):
		return
	boss._update_visual_facing(boss.global_position + Vector2.RIGHT * 100)
	if not _assert_true(not boss.boss_visual.flip_h, "Boss art did not face a right-side player"):
		return
	boss.velocity = Vector2.ZERO
	boss._update_boss_motion(1.0)
	if not _assert_true(boss.boss_visual.position == Vector2.ZERO and is_zero_approx(boss.boss_visual.rotation) and boss.boss_visual.scale.is_equal_approx(Vector2(1.25, 1.25)), "idle Boss retained a stale walk pose"):
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
		var accepted: bool = enemy.native_visual != null and enemy.static_visual == null if fixture.kind in [EnemyScript.EnemyKind.SCRAPPER, EnemyScript.EnemyKind.SPITTER] else enemy.static_visual.texture.resource_path == fixture.path
		if not _assert_true(accepted, "enemy did not use its current approved actor resource: " + fixture.path):
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
	boss.queue_free()
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
