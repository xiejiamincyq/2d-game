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
		{"kind": EnemyScript.EnemyKind.SPITTER, "path": "res://assets/art/actors/enemies/enemy_spitter_chibi_b_v1.png", "radius": 14.0, "damage": 15.0, "scale": Vector2(0.45, 0.45)},
		{"kind": EnemyScript.EnemyKind.BRUISER, "path": "res://assets/art/actors/enemies/enemy_bruiser_chibi_b_v1.png", "radius": 24.0, "damage": 54.0, "scale": Vector2(0.66, 0.66)},
		{"kind": EnemyScript.EnemyKind.MARKSMAN, "path": "res://assets/art/actors/enemies/enemy_marksman_chibi_b_v1.png", "radius": 14.0, "damage": 15.0, "scale": Vector2(0.55, 0.55)},
		{"kind": EnemyScript.EnemyKind.LOBBER, "path": "res://assets/art/actors/enemies/enemy_lobber_chibi_b_v1.png", "radius": 17.0, "damage": 24.0, "scale": Vector2(0.60, 0.60)},
		{"kind": EnemyScript.EnemyKind.OVERSEER, "path": "res://assets/art/actors/enemies/enemy_overseer_chibi_b_v1.png", "radius": 40.0, "damage": 72.0, "scale": Vector2(1.0, 1.0)},
	]:
		if not _assert_true(FileAccess.file_exists(fixture.path), "static enemy texture is missing: " + fixture.path):
			return
		var enemy: CharacterBody2D = EnemyScript.new()
		enemy.setup(fixture.kind, 1, root)
		root.add_child(enemy)
		await process_frame
		enemy.set_physics_process(false)
		var native: bool = fixture.kind == EnemyScript.EnemyKind.SPITTER
		var visual: Node2D = enemy.get_visual_node()
		if not _assert_true(visual != null, "enemy did not create a visual"):
			return
		if not _assert_true(visual.scene_file_path == "res://scenes/actors/native/sporeling_paper_v1.tscn" if native else visual.texture.resource_path == fixture.path, "enemy loaded wrong native/raster resource"):
			return
		if not _assert_true(visual.skeleton.get_bone_count() == 14 if native else visual.texture.get_size() == Vector2(128, 128), "enemy lacks bounded raster / complete native rig"):
			return
		if not _assert_true(visual.scale.is_equal_approx(Vector2.ONE if native else fixture.scale), "enemy display scale drifted"):
			return
		if not _assert_true(is_equal_approx(enemy.body_radius, fixture.radius), "art integration changed collision radius"):
			return
		if not _assert_true(is_equal_approx(enemy.contact_damage, fixture.damage), "art integration changed contact damage"):
			return
		var material: ShaderMaterial = visual.get_node("Facing/Skin").material if native else visual.material
		if not _assert_true(material != null, "enemy lacks hit-flash material"):
			return
		if not _assert_true(enemy.has_method("should_show_health_bar") and enemy.has_method("should_show_status_marker"), "enemy marker visibility policy missing"):
			return
		if not _assert_true(enemy.should_show_health_bar() == (fixture.kind != EnemyScript.EnemyKind.BRUISER), "living small enemy or overseer must show full-health bar"):
			return
		if not _assert_true(not enemy.should_show_status_marker(), "illustrated enemy still has a decorative status strip"):
			return

		var player := Node2D.new()
		player.add_to_group("player")
		root.add_child(player)
		enemy.global_position = Vector2.ZERO
		player.global_position = Vector2(100, 0)
		enemy._physics_process(0.0)
		if not _assert_true(visual.get_node("Facing").scale.x == 1 if native else not visual.flip_h, "right-facing enemy flipped with player on the right"):
			return
		player.global_position = Vector2(-100, 0)
		enemy._physics_process(0.0)
		if not _assert_true(visual.get_node("Facing").scale.x == -1 if native else visual.flip_h, "enemy did not flip toward player on the left"):
			return

		enemy.take_damage(1.0)
		if not _assert_true(enemy.should_show_health_bar(), "damaged enemy lost health feedback"):
			return
		if not _assert_true(is_equal_approx(float(material.get_shader_parameter("flash_amount")), 0.35), "static enemy palette-preserving hit flash did not activate"):
			return
		enemy._physics_process(0.1)
		if not _assert_true(is_zero_approx(float(material.get_shader_parameter("flash_amount"))), "static enemy hit flash did not clear"):
			return
		enemy.health.current_health = enemy.health.max_health
		if not _assert_true(enemy.should_show_health_bar() == (fixture.kind != EnemyScript.EnemyKind.BRUISER), "restored health must preserve small bars and hide incidental heavy bar"):
			return
		enemy.health.current_health = 0.0
		if not _assert_true(not enemy.should_show_health_bar(), "dead enemy retains a health bar"):
			return

		player.queue_free()
		enemy.queue_free()
		await process_frame

	print("TEST PASS: EnemyStaticArtTest %d" % assertions)
	quit(0)
