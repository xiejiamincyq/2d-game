extends SceneTree
## Product tent lifecycle, separate from the retired wave-mode fixture tests.
const Main=preload("res://scripts/Main.gd")
const Support=preload("TestSupport.gd")
class Probe extends Main:
	signal release_drain
	var hold_drain:=true
	var fail_drain:=false
	var drains:=0
	var finishes: Array[int]=[]
	func _drain_audio_for_scene_exit() -> bool:
		drains+=1
		if hold_drain: await release_drain
		var result: bool=await super._drain_audio_for_scene_exit()
		return result and not fail_drain
	func _finish_close(code: int) -> void: finishes.append(code)
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: CampaignHubLifecycleTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for mode in ["close","launch_then_close","launch_audio_failure"]:
		paused=false
		var tent:=Probe.new(); tent.audio_enabled=false
		tent.campaign_store_path="user://hub_lifecycle_missing_%d_%d.json"%[OS.get_process_id(),Time.get_ticks_usec()]
		root.add_child(tent)
		check(not FileAccess.file_exists(tent.campaign_store_path) and not FileAccess.file_exists(tent.campaign_store_path+".journey"),"isolated fixture starts without writes")
		check(not auto_accept_quit,"window close bypasses application audio drain")
		if mode=="close":
			tent.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
			tent.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
			check(tent.closing and paused and tent.drains==1 and tent.finishes.is_empty(),"close is single-flight and freezes launch")
			tent._start_primary_campaign(); tent._start_campaign_chapter(1)
			check(not tent.restarting and tent.drains==1,"close accepted late gameplay request")
		elif mode=="launch_then_close":
			tent._start_campaign_chapter(1); tent._start_primary_campaign()
			check(tent.restarting and tent.drains==1 and paused,"duplicate launch was admitted")
			tent._request_close(); tent._request_close()
			check(tent.closing and tent.drains==2,"close cannot take authority from pending launch")
		else:
			tent.fail_drain=true; tent._start_primary_campaign()
			check(tent.restarting and tent.drains==1,"real primary did not reserve launch")
		check(root.get_children().filter(func(child): return child.has_method("_chapter_number")).is_empty(),"chapter entered before successful drain")
		tent.release_drain.emit()
		await process_frame; await process_frame
		check(tent.finishes==[1 if mode=="launch_audio_failure" else 0],"close/failure did not finish once with correct status")
		check(tent.audio.is_shutdown_complete(),"actual tent audio drain incomplete")
		check(root.get_children().filter(func(child): return child.has_method("_chapter_number")).is_empty(),"cancelled destination leaked into tree")
		check(not FileAccess.file_exists(tent.campaign_store_path) and not FileAccess.file_exists(tent.campaign_store_path+".journey"),"cancelled startup wrote progress")
		Support.stop_audio(tent.audio); tent.free(); paused=false; await process_frame
	if failures==0: print("TEST PASS: CampaignHubLifecycleTest %d"%checks)
	quit(1 if failures else 0)
