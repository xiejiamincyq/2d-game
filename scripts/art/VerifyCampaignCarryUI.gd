extends SceneTree
## GPU proof of the shared settlement component only, not a real Boss victory.
const Interface = preload("res://scripts/ui/ChapterRunUI.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const JourneyStore = preload("res://scripts/systems/CampaignJourneyStore.gd")
const OUTPUT := "res://build/diagnostics/campaign-endless-v1/carry-ui-gpu-v2"
var assertions := 0
var failures := 0
var captures: Array[Dictionary] = []
var sources: Dictionary = {}

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyCampaignCarryUI " + message)

func _initialize() -> void:
	call_deferred("run")

func capture(view: SubViewport, ui: Node, label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	var file := OUTPUT.path_join("%s-%dx%d.png" % [label, view.size.x, view.size.y])
	check(image != null and image.get_size() == view.size and image.save_png(file) == OK, "GPU capture " + label)
	var bounds := Rect2(Vector2(8, 8), Vector2(view.size) - Vector2(16, 16))
	check(bounds.encloses(ui.flow_panel.get_global_rect()), "settlement frame outside viewport")
	for control in [ui.carry_selector, ui.next_button, ui.replay_button, ui.return_button]:
		if control.is_visible_in_tree():
			check(bounds.encloses(control.get_global_rect()), "required control outside viewport")
	captures.append({"file": file, "sha256": FileAccess.get_sha256(file), "size": [view.size.x, view.size.y], "state": label})

func run() -> void:
	if DisplayServer.get_name() == "headless":
		check(false, "GPU capture requires real renderer")
		quit(1)
		return
	check(not DirAccess.dir_exists_absolute(OUTPUT), "do not overwrite earlier capture evidence")
	if failures:
		quit(1)
		return
	check(DirAccess.make_dir_recursive_absolute(OUTPUT) == OK, "new evidence directory")
	for path in ["scripts/ui/ChapterRunUI.gd", "scripts/ui/GameUI.gd", "scripts/ui/CampaignMenuTheme.gd", "scripts/art/VerifyCampaignCarryUI.gd"]:
		sources[path] = FileAccess.get_sha256("res://" + path)
	var saved_before: Dictionary = {}
	for path in [Store.DEFAULT_PATH, JourneyStore.DEFAULT_PATH]:
		saved_before[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	var choices: Array[Dictionary] = [{"id": "damage", "label": "超频弹芯 · 继承一级", "description": "子弹伤害 +14%"}, {"id": "mine", "label": "静滞地刺 · 继承一级", "description": "解锁地刺；下次开局自动部署，终极进化不继承。"}]
	for extent in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var view := SubViewport.new()
		view.size = extent
		view.world_2d = World2D.new()
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var ui := Interface.new()
		view.add_child(ui)
		ui.present_chapter_clear(1, choices, 57, false)
		await capture(view, ui, "first-pending")
		ui.carry_selector.select(2)
		ui.carry_selector.item_selected.emit(2)
		await capture(view, ui, "first-selected")
		ui.present_chapter_clear(6, choices, 57, true)
		check(not ui.next_button.visible, "sixth shows next chapter button")
		await capture(view, ui, "sixth-replay")
		view.free()
		await process_frame
	for path in saved_before:
		check(saved_before[path] == (FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"), "user checkpoint altered")
	for path in sources:
		check(FileAccess.get_sha256("res://" + path) == sources[path], "source drift during captures")
	var report := {"schema": "campaign-carry-ui-gpu-v2", "valid": failures == 0, "assertions": assertions, "renderer": RenderingServer.get_video_adapter_name(), "sources": sources, "captures": captures, "limits": ["Component preview with explicit choices, not a Boss clear.", "No gold/ability save or chapter navigation executed."]}
	var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	check(file != null, "report writer")
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	if failures == 0:
		print("TEST PASS: VerifyCampaignCarryUI %d" % assertions)
	quit(0 if failures == 0 else 1)
