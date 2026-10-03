extends "res://scripts/art/VerifyNaturalRunRendered.gd"

const Recorder = preload("res://scripts/art/VerifyNaturalRunRendered.gd")
const MainScript = preload("res://scripts/Main.gd")
const BossScript = preload("res://scripts/actors/OverseerBoss.gd")
const UIScript = preload("res://scripts/ui/GameUI.gd")
class FixtureMain extends MainScript:
	func _ready() -> void:
		pass # No real snapshot store, audio or natural-run initialization.
class FixtureDirector extends Node:
	var boss: Node
	func get_active_boss() -> Node:
		return boss
var assertions := 0

func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: NaturalRunRenderedTest: " + message)
	valid = false
	if is_instance_valid(view):
		view.free()
	quit(1)
	return false

func _initialize() -> void:
	var info := {"state": "PLAYING", "wave": 1, "step": 30, "visible_live": 20, "dash": true, "warning_overlap": true, "boss_active": true}
	if not _check(Recorder.eligible_tags(info) == ["opening", "crowd", "dash", "overlap", "boss"], "natural conditions did not select their captures"):
		return
	info = {"state": "PLAYING", "wave": 2, "step": 1, "visible_live": 19, "dash": false, "warning_overlap": false, "boss_active": false}
	if not _check(Recorder.eligible_tags(info).is_empty(), "missing conditions were invented"):
		return
	info["live"] = 100
	info.visible_live = 0
	if not _check(Recorder.eligible_tags(info).is_empty(), "offscreen enemies counted as visual crowd"):
		return
	info.state = "SETTLEMENT"
	info["shop_ready"] = true
	if not _check(Recorder.eligible_tags(info) == ["shop"], "shop not selected"):
		return
	info.state = "PAUSED"
	info.dash = true
	info.boss_active = true
	if not _check(Recorder.eligible_tags(info).is_empty(), "paused fixture mislabeled as combat"):
		return
	var measure := Callable(Recorder, "measure_boss_view")
	if not _check(measure.is_valid(), "native recorder cannot distinguish HUD overlap from screen clipping"):
		return
	var metrics: Dictionary = measure.call(Rect2(100, 80, 160, 160), Rect2(0, 0, 1280, 720), [Rect2(0, 12, 1280, 112), Rect2(180, 126, 920, 34)])
	if not _check(is_equal_approx(metrics.offscreen_area, 0.0) and is_equal_approx(metrics.ui_overlap_areas[0], 7040.0) and is_equal_approx(metrics.ui_overlap_areas[1], 2720.0), "onscreen Boss hidden by HUD was mislabeled as offscreen"):
		return
	metrics = measure.call(Rect2(-40, 300, 160, 160), Rect2(0, 0, 1280, 720), [])
	if not _check(is_equal_approx(metrics.offscreen_area, 6400.0) and metrics.ui_overlap_areas.is_empty(), "screen-edge clipping was not separated from HUD"):
		return
	metrics = measure.call(Rect2(500, 250, 160, 160), Rect2(0, 0, 1280, 720), [Rect2(0, 12, 1280, 112)])
	if not _check(is_zero_approx(metrics.offscreen_area) and is_zero_approx(metrics.ui_overlap_areas[0]), "clear Boss frame counted as obstructed"):
		return
	await _check_recording_path()
	if valid:
		print("TEST PASS: NaturalRunRenderedTest %d" % assertions)
		quit(0)

func _check_recording_path() -> void:
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	root.add_child(view)
	scene = FixtureMain.new()
	scene.set_process(false)
	view.add_child(scene)
	scene.player = Node2D.new()
	scene.add_child(scene.player)
	var camera := Camera2D.new()
	camera.position = Vector2(200, -100)
	camera.zoom = Vector2(0.8, 0.8)
	camera.offset = Vector2(7, -3)
	camera.ignore_rotation = false
	camera.rotation = 0.1
	scene.add_child(camera)
	scene.ui = UIScript.new()
	scene.add_child(scene.ui)
	scene.ui.transform = Transform2D(0.15, Vector2(31, 23)).scaled_local(Vector2(1.25, 1.25))
	var shots := Node2D.new()
	scene.add_child(shots)
	var boss: Node = BossScript.new()
	boss.set_physics_process(false)
	boss.setup(6, shots)
	scene.add_child(boss)
	boss.entrance_resolved = true
	boss.scale = Vector2.ONE
	boss.rotation = 0.0
	boss.modulate.a = 1.0
	boss.position = Vector2(-150, -120)
	scene.wave_director = FixtureDirector.new()
	scene.wave_director.boss = boss
	scene.add_child(scene.wave_director)
	await process_frame
	await process_frame
	camera.make_current()
	camera.force_update_scroll()
	scene.ui.hide_start_screen()
	scene.boss_camera_framing = preload("res://scripts/systems/BossCameraFraming.gd").new()
	scene.add_child(scene.boss_camera_framing)
	scene.boss_camera_framing.setup(camera, scene.player, scene.ui, Rect2(-1400, -900, 2800, 1800))
	scene.boss_camera_framing.set_process(false)
	scene.ui.boss_health_bar.visible = true
	scene.ui.hud.set_combo(3)
	scene.ui.hud.toast_overlay.visible = true
	scene.ui.hud.collection_panel.visible = true
	scene.run_state = scene.RunState.PLAYING
	started = Time.get_ticks_usec()
	last_capture_frame = Engine.get_physics_frames() # Clip throttle must NOT throttle Boss records.
	_capture()
	if not _check(boss_view_samples.size() == 1, "actual capture path skipped Boss geometry at the clip throttle"):
		return
	var row := boss_view_samples[0]
	if not _check(row.has("player_rect") and row.player_ui_overlap_areas.size() == 6 and is_equal_approx(row.camera_zoom, 0.8) and row.framing_active == false and row.direction_cue_visible == false, "actual recording omitted or invented framing/player/cue geometry"):
		return
	if not _check(row.ui_names.size() == 6 and str(scene.ui.hud.combo_panel.get_path()) in row.ui_names and str(scene.ui.hud.toast_overlay.get_path()) in row.ui_names and str(scene.ui.hud.collection_panel.get_path()) in row.ui_names, "actual recording omitted visible combat HUD panels"):
		return
	var sprite_rect: Rect2 = view.canvas_transform * boss.boss_visual.global_transform * boss.boss_visual.get_rect()
	if not _check(Rect2(row.sprite_rect[0], row.sprite_rect[1], row.sprite_rect[2], row.sprite_rect[3]).is_equal_approx(sprite_rect), "Boss geometry was not transformed to viewport coordinates"):
		return
	var ui_index: int = row.ui_names.find(str(scene.ui.hud.combo_panel.get_path()))
	var ui_rect: Rect2 = scene.ui.transform * scene.ui.hud.combo_panel.get_global_rect()
	var observed: Array = row.ui_rects[ui_index]
	if not _check(Rect2(observed[0], observed[1], observed[2], observed[3]).is_equal_approx(ui_rect), "transformed CanvasLayer UI used canvas rather than viewport coordinates"):
		return
	scene.ui.hud.combo_panel.hide()
	_capture()
	if not _check(boss_view_samples.size() == 2 and boss_view_samples[-1].ui_names.size() == 5 and str(scene.ui.hud.combo_panel.get_path()) not in boss_view_samples[-1].ui_names, "hidden UI retained a Boss obstruction"):
		return
	boss.hide()
	_capture()
	if not _check(boss_view_samples.size() == 2, "invisible Boss was recorded as a drawn body"):
		return
	boss.show()
	scene.run_state = scene.RunState.BOSS_INTRO
	_capture()
	if not _check(boss_view_samples.size() == 2, "entrance overlay mislabeled as combat view"):
		return
	scene.run_state = scene.RunState.PLAYING
	boss.entrance_resolved = false
	_capture()
	if not _check(boss_view_samples.size() == 2, "unresolved Boss entrance was recorded"):
		return
	boss.entrance_resolved = true
	var hashes := _source_hashes()
	if not _check(hashes.has("themes/MintFarmTheme.tres") and hashes.has("scenes/ui/HUD.tscn") and hashes.has("scripts/effects/CameraEffects.gd"), "view evidence omitted layout or camera dependencies"):
		return
	if not _check(hashes.has("scripts/systems/CombatView.gd") and hashes.has("scripts/systems/BossCameraFraming.gd") and hashes.has("scripts/ui/BossDirectionIndicator.gd"), "view evidence omitted framing/navigation/cue dependencies"):
		return
	boss_view_samples.resize(60000)
	_capture()
	if not _check(boss_view_samples.size() == 60000 and boss_view_truncated and not valid, "recording capacity limit remained a valid observation"):
		return
	valid = true # Test passes by rejecting that synthetic overflow, not by accepting it.
	view.free()
	await process_frame
