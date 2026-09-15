extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const OutlineScript = preload("res://scripts/art/PlayerOcclusionOutline.gd")
const FloorScript = preload("res://scripts/world/FloorGrid.gd")
const LobScript = preload("res://scripts/components/LobbedProjectile.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var legacy_fill := args.has("landing-before")
	var landing_preview := legacy_fill or args.has("landing")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(FloorScript.new())
	for index in range(4):
		var origin := Vector2((index % 2) * 480, (index / 2) * 360)
		var center := origin + Vector2(240, 190)
		var world := Node2D.new()
		world.y_sort_enabled = true
		viewport.add_child(world)
		var player := PlayerScript.new()
		player.process_mode = Node.PROCESS_MODE_DISABLED
		world.add_child(player)
		await process_frame
		player.position = center
		player.gun_angle = PI * 0.5 * index
		player.queue_redraw()
		for enemy_index in range(8):
			var enemy := EnemyScript.new()
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.setup(EnemyScript.EnemyKind.OVERSEER if enemy_index % 2 == 0 else EnemyScript.EnemyKind.BRUISER, 1, world, player)
			world.add_child(enemy)
			await process_frame
			var angle := TAU * float(enemy_index) / 8.0
			enemy.position = center + Vector2(cos(angle) * 48.0, sin(angle) * 28.0 + 12.0)
			enemy._update_enemy_facing(center)
		var outline := OutlineScript.new()
		if landing_preview:
			var shots := Node2D.new()
			shots.z_index = OutlineScript.OUTLINE_Z_INDEX + 1
			world.add_child(shots)
			for lob_index in range(12):
				var lob := LobScript.new()
				lob.process_mode = Node.PROCESS_MODE_DISABLED
				lob.configure(center + Vector2(160.0, -70.0 + lob_index * 4.0), center, player)
				shots.add_child(lob)
				lob._physics_process(0.3)
				if legacy_fill:
					# Reproduce the former fill layer without changing flight or boundary.
					lob.landing_fill.z_index = 0
		player.add_child(outline)
		outline.setup(player, world, null)
		if not outline.visible:
			push_error("Runtime outline did not activate in crowd fixture")
			quit(1)
			return
		var label := Label.new()
		label.position = origin + Vector2(28, 26)
		label.text = ["C+  Right", "C+  Front", "C+  Left", "C+  Back"][index]
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color("123b3b"))
		viewport.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := viewport.get_texture().get_image()
	var path := "res://docs/art/previews/environment/player-outline-runtime-v1.png"
	if landing_preview:
		path = path.replace("runtime", "landing-before" if legacy_fill else "landing")
	if capture == null or capture.is_empty() or capture.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("Runtime outline screenshot failed")
		quit(1)
		return
	viewport.queue_free()
	await process_frame
	print("OUTLINE RUNTIME PASS: ", path)
	quit(0)
