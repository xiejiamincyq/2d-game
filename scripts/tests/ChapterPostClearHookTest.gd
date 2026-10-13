extends SceneTree
## Diagnostic source contract; the real replay run separately proves gameplay.
const Driver = preload("res://scripts/art/VerifyNurseryChapterFlow.gd")
var checks := 0
var failures := 0
var driver_script: Script = Driver
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: ChapterPostClearHookTest " + label)
func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/art/VerifyNurseryChapterFlow.gd")
	var found := false
	for method: Dictionary in driver_script.get_script_method_list():
		if method.name == "after_ordinary_clear": found = true
	check(found,"awaitable post-clear hook missing")
	check(source.contains("func after_ordinary_clear(_chapter: Node, _report: Dictionary) -> bool:\n\treturn true"),"default hook must preserve ordinary run behavior")
	var hook := source.find("check(await after_ordinary_clear(chapter, report)")
	check(hook>source.find("report.merge(additional_report())"),"hook must follow actual build observations")
	check(hook>=0 and hook<source.find("report.valid = failures == 0"),"hook failures must be in final report verdict")
	check(source.contains("elif failures == 0:\n\t\tcheck(await after_ordinary_clear"),"hook must not run on defeats or chain legs")
	check(source.contains("else: actual_scene()._leave(false, true)"),"replay must shut down current live scene, not freed original chapter")
	if failures==0: print("TEST PASS: ChapterPostClearHookTest %d"%checks)
	quit(1 if failures else 0)
