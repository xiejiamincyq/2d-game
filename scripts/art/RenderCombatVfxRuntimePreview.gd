extends SceneTree

const CombatVfxScript = preload("res://scripts/effects/CombatVfx.gd")
const ProjectileScript = preload("res://scripts/components/Projectile.gd")
const ArcPulseVisualScript = preload("res://scripts/components/ArcPulseVisual.gd")

const OUTPUT_PATH := "res://docs/art/previews/characters-combat/combat-vfx-runtime-v1.png"
const VIEWPORT_SIZE := Vector2i(1536, 900)

func _initialize() -> void:
	print("RENDER START: Combat VFX runtime preview")
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var background := ColorRect.new()
	background.size = Vector2(VIEWPORT_SIZE)
	background.color = Color("071018")
	viewport.add_child(background)
	_add_grid(background)
	_add_label(background, "COMBAT VFX — BOUNDED RUNTIME LANGUAGE", Vector2(42, 24), 28)
	_add_label(background, "No per-effect nodes · cyan direction · magenta energy · orange impact", Vector2(42, 60), 16)

	var vfx := CombatVfxScript.new()
	viewport.add_child(vfx)
	await process_frame
	_spawn_hit_sparks(vfx, Vector2(210, 290))
	_spawn_kill_burst(vfx, Vector2(520, 290))
	vfx.request_effect(CombatVfxScript.RING, Vector2(830, 290), Vector2(1, -0.35), 1.8)
	vfx.request_effect(CombatVfxScript.BLAST, Vector2(1140, 290), Vector2.UP, 1.35)
	_spawn_afterimages(vfx, Vector2(260, 650))
	_spawn_overdrive_projectiles(viewport, Vector2(790, 650))
	_spawn_arc_pulse(viewport, Vector2(1260, 650))
	vfx._process(0.055)
	vfx.set_process(false)
	vfx.queue_redraw()

	_add_label(background, "HIT SPARK", Vector2(145, 155), 17)
	_add_label(background, "KILL BURST", Vector2(452, 155), 17)
	_add_label(background, "HEAVY RING", Vector2(758, 155), 17)
	_add_label(background, "BLAST", Vector2(1098, 155), 17)
	_add_label(background, "DASH AFTERIMAGE", Vector2(150, 515), 17)
	_add_label(background, "OVERDRIVE PROJECTILE — 0 GPU EMITTERS", Vector2(700, 515), 17)
	_add_label(background, "ARC PULSE — 2 DRAW CALLS", Vector2(1140, 515), 17)
	_add_label(background, "Caps: sparks 96 · debris 48 · rings 16 · afterimages 24", Vector2(42, 846), 15)

	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.get_size() != VIEWPORT_SIZE:
		push_error("Combat VFX runtime capture is empty or incorrectly sized")
		quit(1)
		return
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if capture.save_png(absolute_path) != OK:
		push_error("Could not save combat VFX runtime capture: " + OUTPUT_PATH)
		quit(1)
		return
	viewport.queue_free()
	await create_timer(0.25).timeout
	await process_frame
	print("RENDER PASS: Combat VFX runtime preview %dx%d -> %s" % [capture.get_width(), capture.get_height(), OUTPUT_PATH])
	quit(0)

func _spawn_hit_sparks(vfx: Node2D, center: Vector2) -> void:
	for index in range(7):
		var direction := Vector2.RIGHT.rotated(-0.7 + float(index) * 0.22)
		vfx.request_effect(CombatVfxScript.SPARK, center, direction, 1.1)

func _spawn_kill_burst(vfx: Node2D, center: Vector2) -> void:
	for index in range(6):
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 6.0)
		vfx.request_effect(CombatVfxScript.DEBRIS, center, direction, 1.25)
	for index in range(4):
		var direction := Vector2.RIGHT.rotated(TAU * (float(index) + 0.5) / 4.0)
		vfx.request_effect(CombatVfxScript.SPARK, center, direction, 1.25)
	vfx.request_effect(CombatVfxScript.RING, center, Vector2.RIGHT, 1.5)

func _spawn_afterimages(vfx: Node2D, origin: Vector2) -> void:
	var direction := Vector2(1.0, -0.22).normalized()
	for index in range(6):
		vfx.request_effect(CombatVfxScript.AFTERIMAGE, origin + direction * float(index) * 46.0, direction, 1.25 - float(index) * 0.08)

func _spawn_overdrive_projectiles(parent: Node, origin: Vector2) -> void:
	for index in range(3):
		var direction := Vector2.RIGHT.rotated(-0.35 + float(index) * 0.35)
		var projectile := ProjectileScript.new()
		projectile.position = origin + Vector2(0.0, float(index - 1) * 82.0)
		projectile.velocity = direction * 620.0
		projectile.tint = Color("b45cff")
		projectile.overdrive_visual = true
		projectile.process_mode = Node.PROCESS_MODE_DISABLED
		parent.add_child(projectile)

func _spawn_arc_pulse(parent: Node, position: Vector2) -> void:
	var pulse := ArcPulseVisualScript.new()
	pulse.position = position
	pulse.setup(160.0)
	pulse.age = 0.22
	pulse.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(pulse)
	pulse.queue_redraw()

func _add_label(parent: Control, value: String, position: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = position
	label.add_theme_color_override("font_color", Color("d7ffff"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)

func _add_grid(parent: Control) -> void:
	for x in range(0, VIEWPORT_SIZE.x, 64):
		var vertical := ColorRect.new()
		vertical.position = Vector2(x, 0)
		vertical.size = Vector2(1, VIEWPORT_SIZE.y)
		vertical.color = Color(0.08, 0.22, 0.26, 0.42)
		parent.add_child(vertical)
	for y in range(0, VIEWPORT_SIZE.y, 64):
		var horizontal := ColorRect.new()
		horizontal.position = Vector2(0, y)
		horizontal.size = Vector2(VIEWPORT_SIZE.x, 1)
		horizontal.color = Color(0.08, 0.22, 0.26, 0.42)
		parent.add_child(horizontal)
