extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const CombatVfxScript = preload("res://scripts/effects/CombatVfx.gd")

const OUTPUT_PATH := "res://docs/art/previews/characters-combat/chibi-b-runtime-v1.png"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const AIM_ANGLES := [0.0, 30.0, 60.0, 90.0, 150.0, 180.0, 270.0, 330.0]

func _initialize() -> void:
	print("RENDER START: Chibi B runtime preview")
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var background := ColorRect.new()
	background.size = Vector2(VIEWPORT_SIZE)
	background.color = Color("123b3b")
	viewport.add_child(background)
	_add_floor_tiles(background)
	_add_label(background, "B 清爽玩具 · 纯2D运行时检查", Vector2(34, 22), 26)
	_add_label(background, "身体四向切换 · 枪械固定双手扇区 · 1280×720 实际尺寸", Vector2(34, 58), 15)

	for index in range(AIM_ANGLES.size()):
		var x := 112.0 + float(index) * 146.0
		await _spawn_player(viewport, Vector2(x, 170.0), deg_to_rad(AIM_ANGLES[index]), index % 2 == 0)
		_add_label(background, "%03d°" % int(AIM_ANGLES[index]), Vector2(x - 22.0, 224.0), 12)

	_add_label(background, "敌人母图 / 水平翻转 / 轻量步行动画", Vector2(34, 278), 17)
	await _spawn_enemy(viewport, EnemyScript.EnemyKind.SCRAPPER, Vector2(150, 385), false, true)
	await _spawn_enemy(viewport, EnemyScript.EnemyKind.SCRAPPER, Vector2(280, 385), true, true)
	await _spawn_enemy(viewport, EnemyScript.EnemyKind.BRUISER, Vector2(470, 395), false, true)
	await _spawn_enemy(viewport, EnemyScript.EnemyKind.BRUISER, Vector2(650, 395), true, true)

	_add_obstacle(background, Rect2(795, 305, 180, 100), Color("9bd7bd"), Color("245b59"))
	_add_obstacle(background, Rect2(1015, 330, 150, 75), Color("f3eddc"), Color("f27a4b"))
	_add_label(background, "地图障碍保持低对比", Vector2(820, 420), 14)

	var vfx := CombatVfxScript.new()
	viewport.add_child(vfx)
	for point in [Vector2(190, 580), Vector2(360, 575), Vector2(540, 585), Vector2(720, 575)]:
		vfx.request_effect(CombatVfxScript.SPARK, point, Vector2.RIGHT, 1.0)
	vfx._process(0.035)
	vfx.set_process(false)
	vfx.queue_redraw()
	_add_label(background, "新命中闪光（实际游戏缩放）", Vector2(34, 650), 15)

	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.get_size() != VIEWPORT_SIZE:
		push_error("Chibi B runtime capture is empty or incorrectly sized")
		quit(1)
		return
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if capture.save_png(absolute_path) != OK:
		push_error("Could not save Chibi B runtime capture: " + OUTPUT_PATH)
		quit(1)
		return
	viewport.queue_free()
	await create_timer(0.2).timeout
	await process_frame
	print("RENDER PASS: Chibi B runtime preview %dx%d -> %s" % [capture.get_width(), capture.get_height(), OUTPUT_PATH])
	quit(0)

func _spawn_player(parent: Node, position: Vector2, aim_angle: float, moving: bool) -> void:
	var player := PlayerScript.new()
	player.position = position
	player.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.gun_angle = aim_angle
	player.visual_elapsed = 0.12
	player.velocity = Vector2.RIGHT.rotated(aim_angle) * (PlayerScript.BASE_MOVE_SPEED if moving else 0.0)
	player.queue_redraw()

func _spawn_enemy(parent: Node, kind: int, position: Vector2, flip_h: bool, moving: bool) -> void:
	var enemy := EnemyScript.new()
	enemy.position = position
	enemy.setup(kind, 1, parent)
	parent.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	enemy.static_visual.flip_h = flip_h
	if moving:
		enemy.velocity = Vector2.RIGHT * 100.0
		enemy._update_static_motion(0.12)
	enemy.queue_redraw()

func _add_floor_tiles(parent: Control) -> void:
	for x in range(0, VIEWPORT_SIZE.x, 80):
		for y in range(0, VIEWPORT_SIZE.y, 80):
			var tile := ColorRect.new()
			tile.position = Vector2(x, y)
			tile.size = Vector2(78, 78)
			var tile_index: int = x / 80 + y / 80
			tile.color = Color("174745") if tile_index % 2 == 0 else Color("153f3e")
			parent.add_child(tile)

func _add_obstacle(parent: Control, rect: Rect2, fill: Color, outline: Color) -> void:
	var shadow := ColorRect.new()
	shadow.position = rect.position + Vector2(5, 7)
	shadow.size = rect.size
	shadow.color = Color(0.0, 0.0, 0.0, 0.28)
	parent.add_child(shadow)
	var body := ColorRect.new()
	body.position = rect.position
	body.size = rect.size
	body.color = outline
	parent.add_child(body)
	var inner := ColorRect.new()
	inner.position = rect.position + Vector2(6, 6)
	inner.size = rect.size - Vector2(12, 12)
	inner.color = fill
	parent.add_child(inner)

func _add_label(parent: Control, value: String, position: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = position
	label.add_theme_color_override("font_color", Color("f3eddc"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
