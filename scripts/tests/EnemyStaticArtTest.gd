extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: EnemyStaticArtTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	for fixture in [
		{"kind": EnemyScript.EnemyKind.SCRAPPER, "path": "res://assets/art/actors/enemies/enemy_scrapper_chibi_b_v1.png", "radius": 14.0, "damage": 8.0, "scale": Vector2(0.44, 0.44)},
		{"kind": EnemyScript.EnemyKind.SPITTER, "path": "res://assets/art/actors/enemies/enemy_spitter_chibi_b_v1.png", "radius": 14.0, "damage": 5.0, "scale": Vector2(0.45, 0.45)},
		{"kind": EnemyScript.EnemyKind.BRUISER, "path": "res://assets/art/actors/enemies/enemy_bruiser_chibi_b_v1.png", "radius": 24.0, "damage": 18.0, "scale": Vector2(0.66, 0.66)},
		{"kind": EnemyScript.EnemyKind.MARKSMAN, "path": "res://assets/art/actors/enemies/enemy_marksman_chibi_b_v1.png", "radius": 14.0, "damage": 5.0, "scale": Vector2(0.55, 0.55)},
		{"kind": EnemyScript.EnemyKind.LOBBER, "path": "res://assets/art/actors/enemies/enemy_lobber_chibi_b_v1.png", "radius": 17.0, "damage": 8.0, "scale": Vector2(0.60, 0.60)},
		{"kind": EnemyScript.EnemyKind.OVERSEER, "path": "res://assets/art/actors/enemies/enemy_overseer_chibi_b_v1.png", "radius": 40.0, "damage": 24.0, "scale": Vector2(1.0, 1.0)},
	]:
		if not _assert_true(FileAccess.file_exists(fixture.path), "static enemy texture is missing: " + fixture.path):
			return
		var enemy: CharacterBody2D = EnemyScript.new()
		enemy.setup(fixture.kind, 1, root)
		root.add_child(enemy)
		await process_frame
		enemy.set_physics_process(false)
		var visual := enemy.get("static_visual") as Sprite2D
		if not _assert_true(visual != null, "static enemy did not create a Sprite2D"):
			return
		if not _assert_true(visual.texture.resource_path == fixture.path, "static enemy loaded the wrong texture"):
			return
		if not _assert_true(visual.texture.get_size() == Vector2(128, 128), "static enemy texture is not the bounded 128px runtime canvas"):
			return
		if not _assert_true(visual.scale.is_equal_approx(fixture.scale), "static enemy display scale drifted"):
			return
		if not _assert_true(is_equal_approx(enemy.body_radius, fixture.radius), "art integration changed collision radius"):
			return
		if not _assert_true(is_equal_approx(enemy.contact_damage, fixture.damage), "art integration changed contact damage"):
			return
		if not _assert_true(visual.material is ShaderMaterial, "static enemy lacks hit-flash material"):
			return

		var player := Node2D.new()
		player.add_to_group("player")
		root.add_child(player)
		enemy.global_position = Vector2.ZERO
		player.global_position = Vector2(100, 0)
		enemy._physics_process(0.0)
		if not _assert_true(not visual.flip_h, "right-facing static enemy flipped with player on the right"):
			return
		player.global_position = Vector2(-100, 0)
		enemy._physics_process(0.0)
		if not _assert_true(visual.flip_h, "static enemy did not flip toward player on the left"):
			return

		enemy.take_damage(1.0)
		var material := visual.material as ShaderMaterial
		if not _assert_true(float(material.get_shader_parameter("flash_amount")) > 0.99, "static enemy hit flash did not activate"):
			return
		enemy._physics_process(0.1)
		if not _assert_true(is_zero_approx(float(material.get_shader_parameter("flash_amount"))), "static enemy hit flash did not clear"):
			return

		player.queue_free()
		enemy.queue_free()
		await process_frame

	print("TEST PASS: EnemyStaticArtTest %d" % assertions)
	quit(0)
