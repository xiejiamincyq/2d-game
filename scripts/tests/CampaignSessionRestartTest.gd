extends SceneTree
## Real independent Godot processes; synthetic receipt is a persistence fixture,
## not evidence of Boss victory. Default player journals are never used.
const Session = preload("res://scripts/systems/CampaignSession.gd")
const Journal = preload("res://scripts/systems/CampaignJourneyStore.gd")
const Legacy = preload("res://scripts/systems/CampaignProgressStore.gd")
var assertions := 0
var failures := 0

func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignSessionRestartTest "+message)

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size()==2:
		var path: String = arguments[1]
		check(path.begins_with("user://restart_session_") and not path.trim_prefix("user://").contains("/"),"child path not isolated")
		if failures: quit(1); return
		var session := Session.new(path)
		check(session.load(),"independent session load")
		if arguments[0]=="prepare":
			check(session.journey.get_entry()=={"loop":1,"chapter":1},"fresh fixture frontier")
			check(session.record_defeat(1,1,72,{"damage":1,"orbital_storm":1}),"receipt write")
		elif arguments[0]=="resume":
			check(session.has_pending_clear() and session.journey.get_build().coins==72,"pending reward survived actual process exit")
			check(session.claim_pending("damage"),"restarted ordinary choice")
		elif arguments[0]=="verify":
			check(not session.has_pending_clear() and session.journey.get_entry()=={"loop":1,"chapter":2},"claim advanced once across restart")
			check(session.journey.get_build()=={"coins":72,"inherited_counts":{"damage":1}},"gold and single ability survived another exit")
			check(not session.claim_pending("damage"),"duplicate restart claim")
		else: check(false,"unknown child phase")
		if not failures: print("RESTART CHILD PASS: "+arguments[0])
		quit(1 if failures else 0)
		return
	var owned := "user://restart_session_%d_%d.json"%[OS.get_process_id(),Time.get_ticks_usec()]
	var protected: Dictionary = {}
	for base in [Journal.DEFAULT_PATH,Legacy.DEFAULT_PATH]:
		for suffix in ["",".bak",".tmp"]:
			protected[base+suffix] = _hash(base+suffix)
	check(_hash(owned+".journey")=="MISSING","unique isolated journal")
	for phase in ["prepare","resume","verify"]:
		var output: Array = []
		var result := OS.execute(OS.get_executable_path(),["--headless","--audio-driver","Dummy","--path",ProjectSettings.globalize_path("res://"),"--script","res://scripts/tests/CampaignSessionRestartTest.gd","--quit-after","240","--",phase,owned],output,true)
		var diagnostic: String = "\n".join(output)
		check(result==0 and diagnostic.count("RESTART CHILD PASS: "+phase)==1,"actual subprocess failed "+phase+": "+diagnostic)
		check(not diagnostic.contains("ERROR") and not diagnostic.contains("leaked"),"subprocess error or leak")
	for path in protected: check(_hash(path)==protected[path],"default player file mutated")
	for suffix in [".journey",".journey.bak",".journey.tmp"]:
		if FileAccess.file_exists(owned+suffix):
			check(DirAccess.remove_absolute(owned+suffix)==OK,"owned journal cleanup")
	if not failures: print("TEST PASS: CampaignSessionRestartTest %d"%assertions)
	quit(1 if failures else 0)

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"
