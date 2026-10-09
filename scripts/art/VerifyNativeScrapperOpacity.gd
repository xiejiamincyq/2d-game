extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const OUTPUT := "res://docs/art/previews/campaign/native-scrapper-opacity-v1.json"

func _initialize() -> void:
	await process_frame
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var enemy := EnemyScript.new()
	enemy.set_physics_process(false)
	enemy.setup(EnemyScript.EnemyKind.SCRAPPER, 0, viewport)
	viewport.add_child(enemy)
	# Preserve the actual Enemy-created native body AND its shader; isolate it
	# from HUD/old hit sparks so this is body opacity, not scene alpha metadata.
	var body: Node2D = enemy.native_visual
	enemy.remove_child(body)
	viewport.add_child(body)
	body.position = Vector2(128, 128)
	var material: ShaderMaterial = enemy.static_flash_material
	enemy.native_visual = null
	enemy.free()
	var samples: Array[Dictionary] = []
	var passed := true
	for clip in ["idle", "walk", "warning", "attack", "hit", "death"]:
		for phase in [0.0, 0.5, 1.0]:
			# death is terminal; it is deliberately the last clip here.
			body.sample_clip(clip, body.player.get_animation(clip).length * phase)
			for flash in [0.0, 0.35]:
				material.set_shader_parameter("flash_amount", flash)
				await process_frame
				await RenderingServer.frame_post_draw
				var bitmap := viewport.get_texture().get_image()
				var opaque := 0
				var partial := 0
				var edge := 0
				for y in 256:
					for x in 256:
						var alpha: float = bitmap.get_pixel(x, y).a
						opaque += 1 if alpha > 0.99 else 0
						partial += 1 if alpha > 0.01 and alpha < 0.99 else 0
						edge += 1 if alpha > 0 and (x == 0 or x == 255 or y == 0 or y == 255) else 0
				var ok := opaque > 1000 and partial == 0 and edge == 0
				passed = passed and ok
				samples.append({"clip": clip, "phase": phase, "flash": flash, "opaque": opaque, "partial": partial, "edge_pixels": edge, "passed": ok})
	viewport.queue_free()
	await process_frame
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		passed = false
	else:
		file.store_string(JSON.stringify({"scope": "GPU Enemy-created body with actual hit shader, six clips at three visual samples and two flash amounts; not every continuous pose or human gameplay approval", "passed": passed, "samples": samples}, "\t"))
		file.close()
	print("NATIVE BODY OPACITY %s: %d GPU pose/flash samples" % ["PASS" if passed else "FAIL", samples.size()])
	quit(0 if passed else 1)
