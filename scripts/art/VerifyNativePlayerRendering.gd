extends SceneTree
## Controlled GPU component gate; separate from the ordinary-input chapter run.
const PlayerSource = preload("res://scripts/actors/Player.gd")
const EnemySource = preload("res://scripts/actors/Enemy.gd")
const OutlineSource = preload("res://scripts/effects/PlayerOcclusionOutline.gd")
const OUT := "res://build/diagnostics/campaign-goal/native-player-render-v4/"
class BodyOnly extends PlayerSource:
	# Exclude old friendly ground effects without detaching a live skinned body.
	func _draw() -> void:
		pass
var failures := 0
var checks := 0
var poses: Array[Dictionary] = []
var contours: Array[Dictionary] = []

func source_hashes() -> Dictionary:
	var hashes := {}
	var paths := ["scripts/art/VerifyNativePlayerRendering.gd", "scripts/actors/Player.gd", "scripts/actors/Enemy.gd", "scripts/components/NativePlayerMotion.gd", "scripts/components/NativePlayerView.gd", "scripts/effects/PlayerOcclusionOutline.gd", "assets/art/shaders/player_native_outline.gdshader", "scenes/actors/native/player_paper_v1.tscn"]
	for facing in ["front", "back", "left", "right"]:
		paths.append("assets/art/actors/native/player_%s_motion_v1.tres" % facing)
	for path in paths:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NATIVE PLAYER GPU FAIL: " + message)

func pixels(bitmap: Image) -> Dictionary:
	var opaque := 0
	var partial := 0
	var edge := 0
	for y in bitmap.get_height():
		for x in bitmap.get_width():
			var alpha := bitmap.get_pixel(x, y).a
			opaque += 1 if alpha > 0.99 else 0
			partial += 1 if alpha > 0.01 and alpha < 0.99 else 0
			edge += 1 if alpha > 0 and (x == 0 or x == bitmap.get_width() - 1 or y == 0 or y == bitmap.get_height() - 1) else 0
	return {"opaque": opaque, "partial": partial, "edge": edge}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(DisplayServer.get_name() != "headless", "real renderer required")
	check(not DirAccess.dir_exists_absolute(OUT), "existing proof must not be overwritten")
	if failures:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var sources := source_hashes()
	var view := SubViewport.new()
	view.size = Vector2i(256, 256)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		var actor = BodyOnly.new()
		actor.position = Vector2(128, 148)
		view.add_child(actor)
		actor.set_physics_process(false)
		var body: Node2D = actor.get_visual_node()
		body.set_aim(direction)
		for action in ["idle", "walk", "shoot", "dash", "hit", "entrance", "death"]:
			for phase in [0.0, 0.5, 1.0]:
				var animator: AnimationPlayer = body.get_node(body.facing + "/AnimationPlayer")
				check(body.sample_clip(action, animator.get_animation(action).length * phase), "pose sampling rejected")
				for tint in [Color.WHITE, Color(1, 0.62, 0.62)]:
					body.modulate = tint
					await process_frame
					await RenderingServer.frame_post_draw
					var bitmap := view.get_texture().get_image()
					var counts := pixels(bitmap)
					check(counts.opaque > 500 and counts.partial == 0 and counts.edge == 0, "body translucent/clipped: %s %s %s" % [body.facing, action, counts])
					poses.append({"facing": body.facing, "clip": action, "phase": phase, "hit_tint": tint != Color.WHITE, "pixels": counts})
					if action == "walk" and phase == 0.5 and tint == Color.WHITE:
						check(bitmap.save_png(OUT + body.facing + "-walk.png") == OK, "pose image write failed")
		actor.free()
	# Render the exact pose-copy contour as a separate viewport so body pixels
	# cannot hide an empty outline or give a false positive alpha count.
	var actor = PlayerSource.new()
	actor.position = Vector2(128, 148)
	view.add_child(actor)
	actor.set_physics_process(false)
	var enemies := Node2D.new()
	var obstacles := Node2D.new()
	view.add_child(enemies)
	view.add_child(obstacles)
	var enemy = EnemySource.new()
	enemy.setup(EnemySource.EnemyKind.OVERSEER, 1, view, actor)
	enemies.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position = actor.position + Vector2(0, 24)
	var contour_view := SubViewport.new()
	contour_view.size = Vector2i(256, 256)
	contour_view.transparent_bg = true
	contour_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(contour_view)
	var outline = OutlineSource.new()
	contour_view.add_child(outline)
	outline.setup(actor, enemies, obstacles)
	outline.set_process(false)
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		actor.gun_angle = direction.angle()
		actor.velocity = Vector2(100, 0)
		actor._update_visual_animation(0.13)
		outline._process(0)
		outline.position += actor.position # Standalone diagnostic canvas placement.
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var bitmap := contour_view.get_texture().get_image()
		var counts := pixels(bitmap)
		var mask: Image = outline.mask_viewport.get_texture().get_image()
		var mask_counts := pixels(mask)
		var outside_mask := 0
		var origin: Vector2i = Vector2i(outline.position + outline.offset) - mask.get_size() / 2
		for y in 256:
			for x in 256:
				if bitmap.get_pixel(x, y).a > 0.99:
					var point := Vector2i(x, y) - origin
					outside_mask += 1 if not Rect2i(Vector2i.ZERO, mask.get_size()).has_point(point) or mask.get_pixelv(point).a < 0.99 else 0
		check(outline.visible and counts.opaque > 50 and counts.partial == 0 and counts.edge == 0, "native contour empty/translucent/clipped: " + str(counts))
		check(mask_counts.opaque > 500 and mask_counts.partial == 0 and mask_counts.edge == 0, "mask empty/translucent/clipped: " + str(mask_counts))
		check(outside_mask == 0, "contour detached from its native body silhouette")
		check(bitmap.save_png(OUT + actor.native_visual.facing + "-contour.png") == OK, "contour image write failed")
		contours.append({"facing": actor.native_visual.facing, "pixels": counts, "mask_pixels": mask_counts, "outside_mask_pixels": outside_mask})
	# Terminal motion must advance automatically with the real SceneTree paused.
	var before: Vector2 = actor.position
	actor.died.connect(func() -> void: paused = true)
	actor.health.damage(10000, true)
	await create_timer(0.65, true).timeout
	check(paused and actor.native_visual.clip == "death" and is_equal_approx(actor.native_motion.death_seconds, 0.55), "automatic paused terminal clip did not finish")
	check(actor.position == before and actor.health.current_health == 0 and not actor._can_fire_primary(), "paused death advanced combat")
	paused = false
	contour_view.free()
	view.free()
	await process_frame
	check(source_hashes() == sources, "sources changed during GPU proof")
	var report := {"passed": failures == 0, "checks": checks, "poses": poses, "contours": contours,
		"scope": "Controlled inherited Player-created body (only procedural _draw excluded), seven clips, three phases, four views and normal/hit RGB tint; native mask/outline actual GPU pixels; automatic death under pause. Not continuous alpha, ordinary-input gameplay or human acceptance.",
		"adapter": RenderingServer.get_video_adapter_name(), "sources": sources}
	var file := FileAccess.open(OUT + "report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("NATIVE PLAYER GPU %s: %d checks, %d poses, %d contours" % ["PASS" if failures == 0 else "FAIL", checks, poses.size(), contours.size()])
	quit(0 if failures == 0 else 1)
