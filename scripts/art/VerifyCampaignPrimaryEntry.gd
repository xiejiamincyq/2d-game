extends SceneTree
## Ordinary engine mouse entry, NOT OS/human play or fresh-save six victories.
const MainScene = preload("res://scenes/Main.tscn")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Snapshot = preload("res://scripts/systems/RunSnapshotStore.gd")
const Support = preload("res://scripts/tests/TestSupport.gd")
var checks := 0
var failures := 0
var folder := ""
var captures: Array[Dictionary] = []
var clicks: Array[Dictionary] = []
var sources := {}
var save_checks: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: VerifyCampaignPrimaryEntry " + label)

func _initialize() -> void: call_deferred("run")

func real_save_hashes() -> Dictionary:
	var hashes := {}
	for path in [Store.DEFAULT_PATH, Snapshot.DEFAULT_PATH]:
		for suffix in ["", ".tmp", ".bak"]:
			hashes[path + suffix] = FileAccess.get_sha256(path + suffix) if FileAccess.file_exists(path + suffix) else "absent"
	return hashes

func click(button: Button) -> void:
	check(button.is_visible_in_tree() and not button.disabled, "unavailable actual input target: " + button.text)
	var view := button.get_viewport()
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	view.push_input(motion, true)
	check(view.get_mouse_position().distance_to(point) < 0.1, "engine pointer differs from target")
	clicks.append({"text": button.text, "point": [point.x, point.y], "frame": Engine.get_physics_frames()})
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		view.push_input(event, true)
	await process_frame
	await process_frame

func capture(view: SubViewport, label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := folder + label + ".png"
	check(view.get_texture().get_image().save_png(path) == OK, "GPU image save")
	captures.append({"path": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path), "width": view.size.x, "height": view.size.y})

func run() -> void:
	var args := OS.get_cmdline_user_args()
	check(args.size() == 1 and args[0].is_valid_identifier(), "fresh identifier required")
	if failures: quit(1); return
	folder = "res://build/diagnostics/campaign-goal/" + args[0] + "/"
	check(not DirAccess.dir_exists_absolute(folder), "refuse existing evidence")
	if failures: quit(1); return
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "fresh evidence directory")
	for source in ["scripts/art/VerifyCampaignPrimaryEntry.gd", "scenes/Main.tscn", "scripts/Main.gd", "scripts/ui/GameUI.gd", "scripts/ui/CampaignStartScreen.gd", "scripts/ui/CampaignMenuTheme.gd", "scripts/ui/CampaignBackdrop.gd", "scripts/ui/CampaignRegionIcon.gd", "scripts/systems/CampaignEntryPolicy.gd", "scripts/systems/CampaignProgress.gd", "scripts/systems/CampaignProgressStore.gd", "scripts/systems/RunSnapshotStore.gd", "scripts/systems/ChapterCatalog.gd", "scripts/campaign/ChapterSceneRegistry.gd", "scripts/campaign/ChapterRun.gd", "scripts/campaign/ChapterRunDefinitions.gd", "scripts/campaign/NurseryChapter.gd", "scripts/campaign/RiftChapter.gd"]:
		sources[source] = FileAccess.get_sha256("res://" + source)
	var real_before := real_save_hashes()
	var index := 0
	for extent in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var prefix := str(extent.x)
		var campaign_path := folder + prefix + "-campaign.json"
		var snapshot_path := folder + prefix + "-legacy.json"
		var progress := Progress.new()
		var clears: int = [0, 5, 6][index]
		for chapter in range(1, clears + 1): progress.record_boss_defeat(chapter)
		if clears: check(Store.new(campaign_path).save_progress(progress), "controlled permanent-progress fixture")
		var campaign_before := FileAccess.get_sha256(campaign_path) if clears else "absent"
		var snapshot := Snapshot.new()
		snapshot.save_path = snapshot_path
		check(snapshot.save_snapshot({"version": 1, "boundary": "wave_intro", "pending_stage": 1, "coins": 0, "family_levels": {"ballistics": 1, "mobility": 1, "automation": 1}, "upgrade_counts": {}, "evolution": "", "settlement": {"wave": 0, "generation": 0, "offers": [], "reward_claimed": false, "closed": true}, "player": {"position": [0, 0], "health": 100.0, "max_health": 100.0, "shield": 0.0, "max_shield": 20.0}, "kills": 0, "elapsed_seconds": 0.0}), "valid isolated old snapshot")
		snapshot.free()
		var snapshot_before := FileAccess.get_sha256(snapshot_path)
		var view := SubViewport.new()
		view.size = extent
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		view.notify_mouse_entered()
		var main = MainScene.instantiate()
		main.audio_enabled = false
		main.campaign_store_path = campaign_path
		view.add_child(main)
		main.snapshot_store.save_path = snapshot_path
		main.ui.set_continue_available(main.snapshot_store.has_valid_snapshot())
		main.ui.apply_viewport_size(Vector2(extent))
		await process_frame
		await process_frame
		var menu = main.ui.start_screen
		for page in range(4):
			if page == 1: await click(menu.regions_button)
			if page == 2: await click(menu.settings_button)
			if page == 3: await click(menu.legacy_button)
			for target in menu.get_active_controls():
				check(Rect2(Vector2.ZERO, Vector2(extent)).encloses(target.get_global_rect()), "actual menu overflow " + str(extent) + " / " + str(page))
				if target is Button: check(target.size.y >= 44 and target.focus_mode == Control.FOCUS_ALL, "actual target size/focus")
			await capture(view, prefix + "-page" + str(page))
			if page > 0: await click(menu.back_button)
		await click(menu.start_button)
		if clears == 6:
			check(menu.page == menu.Page.CHAPTERS and menu.selected_chapter == 6 and not main.run_started, "complete primary did not offer sixth replay")
			await click(menu.launch_button)
		var chapter: Node = null
		for child in view.get_children():
			if child.has_method("_chapter_number"): chapter = child
		check(chapter != null and not is_instance_valid(main), "ordinary click did not replace Main")
		if chapter != null:
			check(chapter._chapter_number() == mini(clears + 1, 6), "actual destination is not frontier/replay")
			await capture(view, prefix + "-actual-chapter")
			Support.stop_audio(chapter.audio)
		view.free()
		paused = false
		await process_frame
		check(FileAccess.get_sha256(snapshot_path) == snapshot_before, "formal input rewrites old snapshot")
		check((FileAccess.get_sha256(campaign_path) if FileAccess.file_exists(campaign_path) else "absent") == campaign_before, "formal input invents permanent progress")
		save_checks.append({"width": extent.x, "preseeded_clears": clears, "legacy_sha256": snapshot_before, "campaign_sha256": campaign_before})
		index += 1
	for source in sources: check(FileAccess.get_sha256("res://" + source) == sources[source], "entry source drift " + source)
	check(real_save_hashes() == real_before, "real user save changed")
	var report := FileAccess.open(folder + "report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures == 0, "checks": checks, "captures": captures, "clicks": clicks, "sources": sources, "save_checks": save_checks, "real_saves_before": real_before, "real_saves_after": real_save_hashes(), "scope": "Actual GPU, four menu pages at three sizes, ordinary engine mouse to first/sixth/replay. Prior5/6 are controlled fixtures; NOT six fresh-save victories or OS/human input."}, "\t"))
	report.close()
	if not failures: print("TEST PASS: VerifyCampaignPrimaryEntry %d" % checks)
	quit(1 if failures else 0)
