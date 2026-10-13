extends SceneTree
## Structural compatibility before adding chapter-specific policy.
const Support = preload("TestSupport.gd")
var assertions := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: SharedChapterRunTest " + message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var base_path := "res://scripts/campaign/ChapterRun.gd"
	var ui_path := "res://scripts/ui/ChapterRunUI.gd"
	check(ResourceLoader.exists(base_path), "shared chapter coordinator absent")
	check(ResourceLoader.exists(ui_path), "shared chapter interface absent")
	if failures > 0:
		quit(1)
		return
	var chapter = load("res://scenes/campaign/nursery_chapter.tscn").instantiate()
	chapter.audio_enabled = false
	chapter.campaign_store_path = "user://shared_chapter_%d.json" % OS.get_process_id()
	chapter.run_seed = 521
	root.add_child(chapter)
	check(chapter.get_script().get_base_script() == load(base_path), "first chapter duplicates its coordinator")
	check(chapter.ui.get_script().get_base_script() == load(ui_path), "first chapter duplicates its interface")
	check(chapter.map.map_seed == 521, "extraction changed seeded map")
	check(chapter.director.get_encounter().id == &"root_outskirts", "extraction changed first encounter")
	check(chapter.ui.flow_description.text.contains("雾苔苗圃"), "extraction changed intro")
	check(chapter.ui.wave_label.text.contains("第1关") and not chapter.ui.wave_label.text.contains("波次"), "intro HUD still uses old wave placeholders")
	check(chapter.player != null and chapter.framing != null and chapter.feedback != null, "shared combat services lost")
	check(chapter.player.enemy_provider == chapter.director.get_attack_targets, "actual chapter binds clearance-only weapon targets")
	check(not chapter.save_clear(1), "extraction permits forged clear")
	check(not FileAccess.file_exists(chapter.campaign_store_path), "extraction wrote save on entry")
	paused = false
	Support.stop_audio(chapter.audio)
	chapter.free()
	await process_frame
	if failures == 0: print("TEST PASS: SharedChapterRunTest %d" % assertions)
	quit(1 if failures > 0 else 0)
