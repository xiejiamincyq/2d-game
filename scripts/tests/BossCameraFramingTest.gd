extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const CombatView = preload("res://scripts/systems/CombatView.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(2560, 1080)]
const PLAYER_VISUAL_RADIUS := 54.0 # 84px body plus the production weapon envelope.

class FixtureMain extends MainScript:
	func _ready() -> void:
		pass # Never create/read/write a real RunSnapshotStore.

var assertions := 0
var failed := false
var view: SubViewport
var scene: Node
var camera: Camera2D
var boss: Node2D
var previous_paused := false
var previous_time_scale := 1.0

func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	failed = true
	push_error("TEST FAIL: BossCameraFramingTest: " + message)
	return false # Only the common epilogue quits; failure cannot be overwritten.

func _initialize() -> void:
	previous_paused = paused
	previous_time_scale = Engine.time_scale
	# SceneTree initialization must finish before any production make_current().
	await process_frame
	await _run_checks()
	_cleanup()
	await process_frame
	await process_frame
	paused = previous_paused
	Engine.time_scale = previous_time_scale
	if failed:
		quit(1)
		return
	print("TEST PASS: BossCameraFramingTest %d" % assertions)
	quit(0)

func _run_checks() -> void:
	paused = false
	view = SubViewport.new()
	view.size = VIEWPORT_SIZES[0]
	view.disable_3d = true
	root.add_child(view)
	scene = FixtureMain.new()
	scene.audio_enabled = false
	view.add_child(scene)
	await process_frame
	seed(2026100401) # Controlled fixture only: identical terrain for paired edge images.
	scene._build_world()
	scene._begin_run({}) # No _start_run(), no snapshot boundary, no natural input claim.
	_freeze_simulation(scene)
	scene.player.entrance_active = false
	scene.player.entrance_visual_offset = 0.0
	scene.player.modulate = Color.WHITE
	scene.player.velocity = Vector2.ZERO
	scene.run_state = MainScript.RunState.WAVE_INTRO
	paused = false
	camera = scene.player.get_node("PlayerCamera") as Camera2D
	await process_frame
	await process_frame
	camera.make_current()
	camera.reset_smoothing()
	camera.force_update_scroll()
	if not _check(scene.snapshot_store == null and scene.audio.silent_mode, "fixture touched snapshot storage or enabled audio"):
		return
	if not _check(view.get_camera_2d() == camera and camera.is_inside_tree(), "production camera is not current in the real SubViewport"):
		return
	if not _check(_camera_has_normal_defaults(), "ordinary no-Boss camera lost local position zero, zoom one, smoothing true/8.0 or world limits"):
		return
	if not await _check_ordinary_player_framing():
		return

	boss = scene.wave_director._spawn_boss_at(Vector2(0, -240)) as Node2D
	if not _check(boss != null and scene.wave_director.get_active_boss() == boss, "real Director did not create/bind the production Boss"):
		return
	_freeze_simulation(scene)
	if not _check(scene.run_state == MainScript.RunState.BOSS_INTRO and scene.ui.boss_health_bar.visible, "Boss spawn did not reach the real Main handler and UI"):
		return
	boss._physics_process(1.41) # Explicit entrance completion, NOT natural-gameplay evidence.
	_freeze_simulation(scene)
	if not _check(boss.entrance_resolved and boss.visible and is_equal_approx(boss.modulate.a, 1.0) and scene.run_state == MainScript.RunState.PLAYING, "production Boss entrance failed to finish before geometry measurement"):
		return
	paused = false
	scene.ui.set_combo(3)
	scene.ui.set_overdrive_charge(60.0, false)
	await process_frame
	await process_frame
	var rig: Node = scene.get("boss_camera_framing") as Node
	print("FRAMING INTERFACE: boss_camera_framing=%s direction_indicator=%s" % [rig != null, scene.ui.get("boss_direction_indicator") != null])

	# First regression is measured even on the OLD production implementation.
	# Missing proposed fields cannot be the only reason for its RED result.
	for size in VIEWPORT_SIZES:
		view.size = size
		scene.ui.apply_viewport_size(Vector2(size))
		await process_frame
		await process_frame
		var nearby_boss := Vector2(0, -100) if size == Vector2i(960, 540) else Vector2(0, -240)
		if not _check_composition(Vector2.ZERO, nearby_boss, "center/%s" % size):
			return
		if not _check_composition(Vector2(1300, -840), Vector2(1100, -700), "world-edge/%s" % size):
			return
		for pose in [[Vector2(-1300, -840), Vector2(-1100, -700)], [Vector2(1300, 840), Vector2(1100, 700)], [Vector2(-1300, 840), Vector2(-1100, 700)], [Vector2.ZERO, Vector2(100, 0)], [Vector2.ZERO, Vector2(-100, 0)], [Vector2.ZERO, Vector2(0, 100)]]:
			if not _check_composition(pose[0], pose[1], "directions/%s/%s" % [size, pose[1]]):
				return

	# These proposed contracts deliberately follow the real old-camera regression.
	# They become reachable only after the production geometry is corrected.
	if not _check(rig != null and rig.has_method("step_framing") and rig.has_method("reset_framing"), "production framing Node must expose step_framing(delta) and reset_framing()"):
		return
	view.size = Vector2i(1280, 720)
	scene.ui.apply_viewport_size(Vector2(view.size))
	await process_frame
	await process_frame
	if not _check_navigation_isolation(rig):
		return
	# Real traversable edges at the min-zoom fallback, not a guessed inset.
	var physical_bounds: Rect2 = MainScript.WORLD_BOUNDS.grow(-scene.player.get_body_radius())
	var edge_cue: Control = scene.ui.boss_direction_indicator
	for viewport_size in VIEWPORT_SIZES:
		view.size = viewport_size
		scene.ui.apply_viewport_size(Vector2(viewport_size))
		await process_frame
		await process_frame
		for corner in [physical_bounds.position, physical_bounds.end, Vector2(physical_bounds.position.x, physical_bounds.end.y), Vector2(physical_bounds.end.x, physical_bounds.position.y)]:
			scene.player.global_position = corner
			boss.global_position = corner + Vector2(0, 1600)
			_settle_camera()
			if not _check(is_equal_approx(camera.zoom.x, 0.80) and _actor_is_clear(_player_screen_rect(), "physical-edge/player"), "physical edge obscured the player at minimum zoom"):
				return
			if not _check(edge_cue.visible and rig.safe_screen_rect.encloses(_control_screen_rect(edge_cue)), "physical edge lost or clipped its far-Boss cue"):
				return
	# Reference limits must hold immediately on an active window resize.
	view.size = Vector2i(960, 540)
	scene.player.global_position = Vector2(1300, -840)
	_settle_camera()
	view.size = Vector2i(2560, 1080)
	rig.call("step_framing", 1.0 / 60.0)
	if not _check(MainScript.WORLD_BOUNDS.encloses(rig.reference.visible_rect), "live resize left navigation reference outside original world bounds"):
		return
	view.size = Vector2i(1280, 720)
	scene.ui.apply_viewport_size(Vector2(view.size))
	await process_frame
	await process_frame
	scene.player.global_position = Vector2.ZERO
	boss.global_position = Vector2(0, 750)
	_settle_camera()
	var cue: Control = scene.ui.get("boss_direction_indicator") as Control
	var safe_rect: Rect2 = rig.get("safe_screen_rect")
	if not _check(bool(rig.get("active")) and not bool(rig.get("both_fit")), "impossible far-Boss composition must report active=true/both_fit=false"):
		return
	if not _check(cue != null and cue.is_visible_in_tree() and safe_rect.encloses(_control_screen_rect(cue)), "far Boss needs a visible direction indicator wholly inside safe_screen_rect"):
		return
	if not _check(camera.zoom.x >= 0.80 and camera.zoom.y >= 0.80 and _actor_is_clear(_player_screen_rect(), "far/player"), "far Boss over-shrank or obscured the player"):
		return

	# Pause freezes composition and hides the cue; it does not invoke _end_run().
	scene._transition_to(MainScript.RunState.PAUSED)
	var paused_position := camera.position
	var paused_zoom := camera.zoom
	boss.global_position = Vector2(750, 0)
	rig.call("step_framing", 1.0)
	if not _check(camera.position == paused_position and camera.zoom == paused_zoom and not cue.visible, "paused rig changed composition or left the direction cue visible"):
		return
	scene._transition_to(MainScript.RunState.PLAYING)
	_freeze_simulation(scene)
	paused = false
	# CameraEffects retains ownership of offset/rotation; framing must not touch them.
	camera.offset = Vector2(7, -3)
	camera.rotation = 0.17
	_settle_camera()
	if not _check(camera.offset == Vector2(7, -3) and is_equal_approx(camera.rotation, 0.17), "framing overwrote CameraEffects offset or camera rotation"):
		return
	# Actual bounded production shake, not just property ownership.
	camera.rotation = 0.025
	camera.ignore_rotation = false
	camera.offset = Vector2(12, -12)
	if not _check_composition(Vector2.ZERO, Vector2(0, -240), "hit-camera"):
		return
	for frame in range(120):
		scene.player.global_position = Vector2(frame * 1.5, sin(frame * 0.05) * 45.0)
		boss.global_position = scene.player.global_position + Vector2(250, -220).rotated(frame * 0.012)
		rig.call("step_framing", 1.0 / 60.0)
		if not _actor_is_clear(_player_screen_rect(), "dynamic/player/%d" % frame):
			return
	camera.offset = Vector2.ZERO
	camera.rotation = 0.0
	camera.ignore_rotation = true
	scene._transition_to(MainScript.RunState.WAVE_CLEAR)
	rig.call("step_framing", 0.1)
	if not _check(_camera_has_normal_defaults() and not cue.visible and not bool(rig.get("active")), "WAVE_CLEAR did not restore the ordinary camera defaults/cue"):
		return
	scene._transition_to(MainScript.RunState.RESULT)
	rig.call("step_framing", 0.1)
	if not _check(_camera_has_normal_defaults() and not cue.visible, "RESULT did not restore ordinary camera defaults/cue"):
		return
	# Explicit removal, not simulated victory, so no snapshot writes or settlement.
	paused = false
	scene.run_state = MainScript.RunState.WAVE_INTRO
	scene._transition_to(MainScript.RunState.PLAYING)
	_freeze_simulation(scene)
	boss.free()
	boss = null
	_settle_camera()
	if not _check(is_equal_approx(camera.zoom.x, 1.0) and not cue.visible and rig.active and _actor_is_clear(_player_screen_rect(), "removed-Boss/player"), "removed Boss did not hand off to protected ordinary framing"):
		return
	rig.call("reset_framing")
	_check(_camera_has_normal_defaults(), "reset_framing did not preserve ordinary defaults")
	_check(not camera.has_meta(CombatView.REFERENCE_KEY), "reset leaked navigation reference metadata")

func _check_navigation_isolation(rig: Node) -> bool:
	scene.player.global_position = Vector2.ZERO
	boss.global_position = Vector2(0, -240)
	_settle_camera()
	var enemy := EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.SPITTER, 1, scene.projectiles, scene.player)
	enemy.world_bounds = MainScript.WORLD_BOUNDS
	scene.enemies.add_child(enemy)
	_freeze_simulation(enemy)
	var before := [boss.get_combat_safe_rect(), enemy.get_camera_safe_rect(), scene.wave_director.get_camera_safe_rect(), scene.wave_director.get_portal_spawn_distance()]
	camera.position = Vector2(340, 190)
	camera.zoom = Vector2.ONE * 0.80
	camera.force_update_scroll()
	var after := [boss.get_combat_safe_rect(), enemy.get_camera_safe_rect(), scene.wave_director.get_camera_safe_rect(), scene.wave_director.get_portal_spawn_distance()]
	var identical := before == after
	# Negative control proves the assertions can detect the old coupling.
	CombatView.detach(camera)
	var unisolated := [boss.get_combat_safe_rect(), enemy.get_camera_safe_rect(), scene.wave_director.get_camera_safe_rect(), scene.wave_director.get_portal_spawn_distance()]
	CombatView.attach(camera, rig.reference)
	enemy.free()
	if not _check(identical, "presentation camera changed Boss/Enemy/Director navigation or portal distance"):
		return false
	return _check(unisolated != before and unisolated[3] != before[3], "navigation negative control did not detect presentation zoom coupling")

func _check_ordinary_player_framing() -> bool:
	var bounds: Rect2 = MainScript.WORLD_BOUNDS.grow(-scene.player.get_body_radius())
	scene.player.global_position = Vector2(0, bounds.position.y)
	scene._transition_to(MainScript.RunState.PLAYING)
	_freeze_simulation(scene)
	paused = false
	var first_entry := _player_screen_rect()
	await _observe_player_frame("ordinary-entry-first-draw")
	if not _actor_is_clear(first_entry, "ordinary-immediate-state-entry"):
		return false
	scene.ui.set_combo(3)
	var rig: Node = scene.boss_camera_framing
	for size in VIEWPORT_SIZES:
		view.size = size
		scene.ui.apply_viewport_size(Vector2(size))
		await process_frame
		await process_frame
		var poses := [Vector2(0, bounds.position.y), bounds.position, Vector2(bounds.end.x, bounds.position.y), Vector2(bounds.position.x, 0), Vector2(bounds.end.x, 0), Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.end.y), Vector2(0, bounds.end.y)]
		for index in range(poses.size()):
			scene.player.global_position = poses[index]
			var original_actor_state: Dictionary = scene.player.get_snapshot_state()
			_settle_camera()
			var label := "ordinary-%dx%d-%02d" % [size.x, size.y, index]
			await _observe_player_frame(label)
			if not _actor_is_clear(_player_screen_rect(), label):
				return false # Actual old-camera geometry fails before new API assertions.
			if not _check(rig.active and is_equal_approx(camera.zoom.x, 1.0) and not scene.ui.boss_direction_indicator.visible, label + ": ordinary framing must be active, full-size and without Boss cue"):
				return false
			if not _check(MainScript.WORLD_BOUNDS.encloses(rig.reference.visible_rect) and rig.reference.visible_rect.size == Vector2(size), label + ": independent 1x navigation reference left original world"):
				return false
			if not _check(scene.player.get_snapshot_state() == original_actor_state, "presentation changed player gameplay snapshot"):
				return false
	# Real process ordering at a live resize, not 240 manually settled steps.
	view.size = Vector2i(960, 540)
	scene.ui.apply_viewport_size(Vector2(view.size))
	scene.ui.show_toast("取景验收：模块提示")
	scene.ui.set_collection_window(2.0, 3.0)
	scene.player.global_position = Vector2(0, bounds.position.y)
	rig.set_process(true)
	await _observe_player_frame("ordinary-live-resize-first-draw")
	rig.set_process(false)
	if not _actor_is_clear(_player_screen_rect(), "ordinary-live-resize-first-draw"):
		return false
	if not _check(MainScript.WORLD_BOUNDS.encloses(rig.reference.visible_rect) and rig.reference.visible_rect.size == Vector2(view.size), "ordinary first resize draw retained stale navigation extent"):
		return false
	scene._transition_to(MainScript.RunState.WAVE_CLEAR)
	scene._transition_to(MainScript.RunState.SETTLEMENT)
	scene._transition_to(MainScript.RunState.PLAYING)
	_freeze_simulation(scene)
	rig.set_process(true)
	await _observe_player_frame("ordinary-resume-first-draw")
	rig.set_process(false)
	if not _actor_is_clear(_player_screen_rect(), "ordinary-resume-first-draw"):
		return false
	scene.ui.set_collection_window(0.0, 3.0)
	scene.ui.toast_panel.hide()
	# After finite presentation pan, Director/Enemy still use the same reference.
	var enemy := EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.SPITTER, 1, scene.projectiles, scene.player)
	scene.enemies.add_child(enemy)
	_freeze_simulation(enemy)
	var before := [enemy.get_camera_safe_rect(), scene.wave_director.get_camera_safe_rect(), scene.wave_director.get_portal_spawn_distance()]
	camera.global_position += Vector2(300, 150)
	camera.zoom = Vector2.ONE * 0.8
	camera.force_update_scroll()
	var after := [enemy.get_camera_safe_rect(), scene.wave_director.get_camera_safe_rect(), scene.wave_director.get_portal_spawn_distance()]
	enemy.free()
	if not _check(before == after, "ordinary presentation fed back into navigation/spawning"):
		return false
	camera.zoom = Vector2.ONE
	camera.ignore_rotation = false
	camera.rotation = 0.025
	camera.offset = Vector2(12, -12)
	for frame in range(120):
		scene.player.global_position = Vector2(sin(frame * 0.2) * 1100.0, bounds.position.y + frame * 1.0)
		rig.step_framing(1.0 / 60.0)
		if not _actor_is_clear(_player_screen_rect(), "ordinary-moving-shake/%d" % frame):
			return false
	camera.ignore_rotation = true
	camera.rotation = 0.0
	camera.offset = Vector2.ZERO
	scene._transition_to(MainScript.RunState.PAUSED)
	var frozen := [camera.position, camera.zoom]
	rig.step_framing(1.0)
	if not _check(frozen == [camera.position, camera.zoom], "ordinary pause moved the camera"):
		return false
	if not _check(scene._transition_to(MainScript.RunState.PLAYING), "ordinary pause could not resume through real Main transition"):
		return false
	_freeze_simulation(scene)
	scene._transition_to(MainScript.RunState.WAVE_CLEAR)
	paused = false
	if not _check(_camera_has_normal_defaults() and not camera.has_meta(CombatView.REFERENCE_KEY), "ordinary clear failed to restore original camera and detach reference"):
		return false
	view.size = VIEWPORT_SIZES[0]
	scene.ui.apply_viewport_size(Vector2(view.size))
	scene.player.global_position = Vector2.ZERO
	scene._transition_to(MainScript.RunState.SETTLEMENT)
	scene._transition_to(MainScript.RunState.PLAYING)
	_freeze_simulation(scene)
	paused = false
	await process_frame
	await process_frame
	return true

func _observe_player_frame(_label: String) -> void:
	# process_frame emits before Node._process; two yields allow one real pass.
	await process_frame
	await process_frame # Native subclass instead observes the first post-draw.

func _freeze_simulation(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_freeze_simulation(child)

func _settle_camera() -> void:
	var rig: Node = scene.get("boss_camera_framing") as Node
	if rig != null and rig.has_method("step_framing"):
		for _step in range(240):
			rig.call("step_framing", 1.0 / 60.0)
			camera.reset_smoothing()
			camera.force_update_scroll()
	# Observe a true steady camera projection, not the first smoothing frame.
	camera.reset_smoothing()
	camera.force_update_scroll()

func _check_composition(player_position: Vector2, boss_position: Vector2, label: String) -> bool:
	scene.player.global_position = player_position
	boss.global_position = boss_position
	scene.player.velocity = Vector2.ZERO
	boss.velocity = Vector2.ZERO
	_settle_camera()
	var projected_boss := _sprite_screen_rect(boss.boss_visual)
	var projected_player := _player_screen_rect()
	print("FRAMING %s camera_local=%s zoom=%s player=%s boss=%s" % [label, camera.position, camera.zoom, projected_player, projected_boss])
	if not _check(camera.zoom.x >= 0.80 and camera.zoom.y >= 0.80 and camera.zoom.is_equal_approx(Vector2.ONE * camera.zoom.x), label + ": limited uniform zoom must be >=0.80"):
		return false
	if not _actor_is_clear(projected_boss, label + "/Boss"):
		return false
	if not _actor_is_clear(projected_player, label + "/player"):
		return false
	var rig: Node = scene.get("boss_camera_framing") as Node
	if rig != null:
		var safe: Rect2 = rig.get("safe_screen_rect")
		if not _check(bool(rig.get("active")) and bool(rig.get("both_fit")) and safe.encloses(projected_boss) and safe.encloses(projected_player), label + ": feasible bodies must fit the actual safe_screen_rect"):
			return false
	return true

func _actor_is_clear(rect: Rect2, label: String) -> bool:
	if not _check(Rect2(Vector2.ZERO, Vector2(view.size)).encloses(rect), "%s clipped by viewport: %s viewport=%s" % [label, rect, view.size]):
		return false
	var blockers: Array[Control] = [scene.ui.hud.grid, scene.ui.boss_health_bar, scene.ui.combo_panel, scene.ui.hud.overdrive_panel, scene.ui.hud.collection_panel, scene.ui.toast_panel]
	for control in blockers:
		if not control.is_visible_in_tree() or control.modulate.a <= 0.0:
			continue
		var ui_rect := _control_screen_rect(control)
		if not _check(not rect.intersects(ui_rect), "%s obscured by actual visible %s: actor=%s UI=%s overlap=%s" % [label, control.name, rect, ui_rect, rect.intersection(ui_rect)]):
			return false
	return true

func _project_rect(transform: Transform2D, rect: Rect2) -> Rect2:
	var corners := [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]
	var result := Rect2(transform * corners[0], Vector2.ZERO)
	for corner in corners:
		result = result.expand(transform * corner)
	return result

func _sprite_screen_rect(sprite: Sprite2D) -> Rect2:
	# Full conservative texture rectangle, including transparent padding and all
	# production Sprite2D scale/rotation/parent transforms, not a guessed radius.
	return _project_rect(sprite.get_global_transform_with_canvas(), sprite.get_rect())

func _player_screen_rect() -> Rect2:
	return _project_rect(scene.player.get_global_transform_with_canvas(), Rect2(Vector2.ONE * -PLAYER_VISUAL_RADIUS, Vector2.ONE * PLAYER_VISUAL_RADIUS * 2.0))

func _control_screen_rect(control: Control) -> Rect2:
	return _project_rect(control.get_global_transform_with_canvas(), Rect2(Vector2.ZERO, control.size))

func _camera_has_normal_defaults() -> bool:
	return camera.position.is_equal_approx(Vector2.ZERO) and camera.zoom.is_equal_approx(Vector2.ONE) and camera.position_smoothing_enabled and is_equal_approx(camera.position_smoothing_speed, 8.0) and camera.limit_left == -1400 and camera.limit_top == -900 and camera.limit_right == 1400 and camera.limit_bottom == 900

func _cleanup() -> void:
	paused = false
	if is_instance_valid(scene):
		TestSupport.stop_audio(scene.audio)
	if is_instance_valid(view):
		view.free()
	view = null
	scene = null
	camera = null
	boss = null
