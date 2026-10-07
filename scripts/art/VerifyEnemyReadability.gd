extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const FloorScript = preload("res://scripts/world/FloorGrid.gd")
const OUTPUT := "res://build/diagnostics/enemy-readability/"
var actors: Array[Node] = []
var poses: Array[Dictionary] = []
var captures: Dictionary = {}
var canvas: SubViewport

func _initialize() -> void:
	call_deferred("_run")

func _capture(tag: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	var path := OUTPUT + tag + ".png"
	var valid := image != null and not image.is_empty() and image.save_png(ProjectSettings.globalize_path(path)) == OK
	captures[tag] = {"path": path.trim_prefix("res://"), "ok": valid, "sha256": FileAccess.get_sha256(path)}
	return valid

func _run() -> void:
	if DisplayServer.get_name() == "headless" or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUTPUT)):
		push_error("Enemy preview needs a native display and unused output directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await process_frame
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	seed(20261007)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1280, 720)
	canvas.world_2d = World2D.new()
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var screen := TextureRect.new()
	screen.texture = canvas.get_texture()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	canvas.add_child(FloorScript.new())
	var title := Label.new()
	title.text = "7 enemy families / right + left / controlled runtime-scale hit feedback"
	title.position = Vector2(24, 24)
	title.add_theme_color_override("font_color", Color("123b3b"))
	canvas.add_child(title)
	for row in range(2):
		for kind in EnemyScript.EnemyKind.values():
			var enemy: Node2D = EnemyScript.new()
			enemy.set_physics_process(false)
			var target := Node2D.new()
			target.position = Vector2(-10000 if row == 1 else 10000, 10000)
			canvas.add_child(target)
			enemy.position = Vector2(94 + kind * 182, 240 + row * 300)
			enemy.setup(kind, 6, canvas, target)
			canvas.add_child(enemy)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy._update_enemy_facing(target.position)
			actors.append(enemy)
			var label := Label.new()
			label.text = EnemyScript.EnemyKind.keys()[kind]
			label.position = enemy.position + Vector2(-48, 95)
			label.add_theme_color_override("font_color", Color("123b3b"))
			canvas.add_child(label)
	var valid := await _capture("idle")
	for frame in range(120):
		for index in range(actors.size()):
			var enemy: Node2D = actors[index]
			enemy.take_damage(0.1, enemy.DamageTypes.LASER)
			enemy.velocity = Vector2.LEFT * enemy.speed if index >= 7 else Vector2.RIGHT * enemy.speed
			enemy._update_static_motion(1.0 / 60.0)
			poses.append({"frame": frame, "actor": index, "kind": enemy.kind,
				"position": [enemy.position.x, enemy.position.y], "velocity": [enemy.velocity.x, enemy.velocity.y],
				"health": enemy.health.current_health, "radius": enemy.body_radius, "speed": enemy.speed,
				"contact_damage": enemy.contact_damage, "alpha": enemy.modulate.a,
				"visual_alpha": enemy.static_visual.modulate.a, "flip_h": enemy.static_visual.flip_h,
				"visual_offset": [enemy.static_visual.position.x, enemy.static_visual.position.y],
				"visual_rotation": enemy.static_visual.rotation,
				"visual_scale": [enemy.static_visual.scale.x, enemy.static_visual.scale.y],
				"flash_timer": enemy.flash_timer, "flash_amount": enemy.static_flash_material.get_shader_parameter("flash_amount")})
		if frame == 0:
			valid = await _capture("single") and valid
		await process_frame
	valid = await _capture("continuous") and valid
	for enemy in actors:
		enemy.flash_timer = maxf(0.0, enemy.flash_timer - 0.081)
		enemy._update_hit_flash()
	valid = await _capture("recovered") and valid
	var report := {"scope": "anchored actors, actual take_damage and visual-motion functions; fixture advances recovery timer, not physics/Main/input/full-gameplay", "viewport": [1280, 720],
		"accepted_hits": 1680, "poses": poses, "captures": captures,
		"enemy_sha256": FileAccess.get_sha256("res://scripts/actors/Enemy.gd"),
		"shader_sha256": FileAccess.get_sha256("res://assets/art/shaders/dasher_hit_flash.gdshader")}
	canvas.free()
	screen.free()
	await process_frame
	report["orphan_before"] = orphans_before
	report["orphan_after"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	valid = valid and report.orphan_after <= orphans_before
	var file := FileAccess.open(OUTPUT + "report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("ENEMY_READABILITY_COMPLETE valid=%s" % valid)
	quit(0 if valid else 1)
