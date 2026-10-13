extends "res://scripts/art/VerifyNurseryChapterFlow.gd"
## Controlled integration of evidence hooks, NOT ordinary Boss victories.
const Menu = preload("res://scripts/ui/CampaignStartScreen.gd")
var preseed_called := false
var clicked: Array[String] = []
class UIHost extends RefCounted:
	var start_screen: Control
class MainHost extends RefCounted:
	var ui: RefCounted
class UnwonChapter extends Node:
	var clear_saved := false
	var director: Node

func prepare_progress(_path: String) -> bool:
	preseed_called = true
	return true

func _click(button: Button) -> void:
	clicked.append(button.text) # Request selection only, not a mouse input proof.

func _initialize() -> void: call_deferred("contract_checks")

func contract_checks() -> void:
	for method in ["configure_chain_arguments", "prepare_campaign_progress", "launch_campaign_entry", "chain_after_clear"]:
		check(has_method(method), "base flow has no chain boundary: " + method)
	if failures: quit(1); return
	output = "res://build/diagnostics/campaign-goal/chain_flow_test_%d/" % OS.get_process_id()
	check(not DirAccess.dir_exists_absolute(output), "refuse old unit fixture")
	check(DirAccess.make_dir_recursive_absolute(output) == OK, "new owned unit directory")
	var parsed: PackedStringArray = call("configure_chain_arguments", PackedStringArray(["first_stage", "chain=FRESH"]))
	check(parsed == PackedStringArray(["first_stage"]), "chain argument not separated from old driver args")
	check(call("prepare_campaign_progress", output + "campaign.json"), "actual empty evidence boundary rejected")
	check(not preseed_called and not FileAccess.file_exists(output + "campaign.json"), "chain calls fixture preseed or creates false save")
	var menu := Menu.new()
	root.add_child(menu)
	await process_frame
	var ready: Array[int] = [1, 2, 3, 4, 5, 6]
	menu.set_campaign(Progress.new(), ready)
	var ui := UIHost.new()
	ui.start_screen = menu
	var main := MainHost.new()
	main.ui = ui
	await call("launch_campaign_entry", main)
	check(clicked == [menu.start_button.text], "chain does not use the formal primary")
	var unwon := UnwonChapter.new()
	var report := {"valid": true}
	check(not await call("chain_after_clear", unwon, report), "unwon chapter can produce accepted chain receipt")
	check(not report.has("chain"), "unwon hook fabricates chain provenance")
	unwon.free()
	clicked.clear()
	call("configure_chain_arguments", PackedStringArray())
	check(call("prepare_campaign_progress", output + "campaign.json") and preseed_called, "explicit old mode loses its historical preparation")
	await call("launch_campaign_entry", main)
	check(clicked == [menu.regions_button.text, menu.chapter_buttons[0].text, menu.launch_button.text], "old standalone route is silently altered")
	check(not FileAccess.file_exists(output + "campaign.json"), "controlled checks wrote synthetic campaign progress")
	menu.free()
	await process_frame
	check(DirAccess.remove_absolute(output) == OK, "only owned empty folder cleanup")
	if not failures: print("TEST PASS: CampaignChainFlowTest %d" % assertions)
	quit(1 if failures else 0)
