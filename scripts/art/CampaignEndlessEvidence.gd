extends RefCounted
## Author-only journey evidence. A valid model transition is not a real victory.
const Journey = preload("res://scripts/systems/CampaignJourney.gd")
const Journal = preload("res://scripts/systems/CampaignJourneyStore.gd")
const Legacy = preload("res://scripts/art/CampaignChainEvidence.gd")
const ROOT := "res://build/diagnostics/campaign-goal/"
const EXTRA_SOURCES := ["themes/CyberTheme.tres","themes/MintFarmTheme.tres","scripts/tests/run_endless_campaign.ps1","scripts/tests/check_endless_campaign_report.py"]

static func parse_arguments(args: PackedStringArray) -> Dictionary:
	var result := {"enabled":false,"valid":true,"args":PackedStringArray(),"parent":"","route":"supply","profile":false}
	var route_seen:=false
	var profile_seen:=false
	for argument in args:
		if argument.begins_with("journey_profile="):
			if profile_seen: result.valid=false
			profile_seen=true
			var value:=argument.trim_prefix("journey_profile=")
			if value not in ["0","1"]: result.valid=false
			result.profile=value=="1"
		elif argument.begins_with("journey_route="):
			if route_seen: result.valid=false
			route_seen=true
			result.route=argument.trim_prefix("journey_route=")
			if result.route not in ["supply","risk"]: result.valid=false
		elif argument.begins_with("journey="):
			if result.enabled: result.valid=false
			result.enabled=true
			result.parent=argument.trim_prefix("journey=")
			if result.parent!="FRESH" and not Legacy.safe_id(result.parent): result.valid=false
		else: result.args.append(argument)
	return result

static func validate_transition(before: Dictionary,after: Dictionary,loop: int,chapter: int,earned: Dictionary,choice: String,balance: int) -> bool:
	var model:=Journey.new()
	if not model.restore_state(before) or model.get_entry()!={"loop":loop,"chapter":chapter} or not model.get_pending_clear().is_empty(): return false
	if not model.commit_clear(loop,chapter,balance,earned,choice): return false
	var restored:=Journey.new()
	return restored.restore_state(after) and model.to_state()==restored.to_state()

static func normalized_state(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var journey:=Journey.new()
	return journey.to_state() if journey.restore_state(value) else {}

static func read_report(path: String) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>32*1024*1024: return {}
	var parser:=JSON.new()
	var value:=file.get_as_text(); file.close()
	return parser.data if parser.parse(value)==OK and parser.data is Dictionary else {}

static func real_save_hashes() -> Dictionary:
	var result: Dictionary={}
	for path in ["user://five_minute_overdrive_campaign_v1.json","user://five_minute_overdrive_run_v1.json",Journal.DEFAULT_PATH]:
		for suffix in ["",".bak",".tmp"]:
			result[path+suffix]=FileAccess.get_sha256(path+suffix) if FileAccess.file_exists(path+suffix) else "absent"
	return result

static func source_bank() -> Dictionary:
	var bank:=Legacy.build_source_bank()
	for path in EXTRA_SOURCES:
		if FileAccess.file_exists("res://"+path): bank[path]=FileAccess.get_sha256("res://"+path)
	return bank

static func source_bank_matches(bank: Dictionary) -> bool:
	var original:=bank.duplicate()
	for path in EXTRA_SOURCES:
		if not original.has(path): continue
		if not Legacy.is_sha(original[path]) or not FileAccess.file_exists("res://"+path) or FileAccess.get_sha256("res://"+path)!=original[path]: return false
		original.erase(path)
	return Legacy.source_bank_matches(original)

static func prepare(folder: String,parent: String,chapter: int,bank: Dictionary) -> Dictionary:
	var rejected: Dictionary={"valid":false}
	if not Legacy.evidence_path(folder+"report.json","report.json") or not DirAccess.dir_exists_absolute(folder): return rejected
	var destination:=folder+"campaign.json.journey"
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(destination+suffix) or DirAccess.dir_exists_absolute(destination+suffix): return rejected
	if not source_bank_matches(bank): return rejected
	if parent=="FRESH":
		return {"valid":true,"loop":1,"before_state":Journey.new().to_state(),"parent_report_sha256":"","parent_saved_sha256":"","previous_process_id":0} if chapter==1 else rejected
	if not Legacy.safe_id(parent): return rejected
	var previous:=ROOT+parent+"/"
	if previous==folder: return rejected
	var report:=read_report(previous+"report.json")
	var receipt:=Legacy.read_dictionary(previous+"exit-report.json")
	if not Legacy.flag(report,"valid",true) or not report.get("endless") is Dictionary: return rejected
	if not Legacy.count_at_least(report.get("chapter"),1) or report.chapter>6 or not Legacy.count_at_least(report.endless.get("process_id"),1): return rejected
	if not Legacy.count_at_least(receipt.get("actual_exit"),0) or receipt.actual_exit!=0 or receipt.get("report_sha256")!=FileAccess.get_sha256(previous+"report.json") or receipt.get("log_sha256")!=FileAccess.get_sha256(previous+"driver.log"): return rejected
	if receipt.get("engine_process_id")!=report.endless.get("process_id") or not Legacy.count_at_least(receipt.get("launcher_process_id"),1) or receipt.engine_process_id==OS.get_process_id(): return rejected
	if not receipt.get("observed_engine_process_ids") is Array or not receipt.observed_engine_process_ids.has(receipt.engine_process_id) or not receipt.observed_engine_process_ids.has(receipt.launcher_process_id): return rejected
	if report.endless.get("source_bank")!=bank or not Legacy.flag(report.endless,"returned_to_main",true) or not Legacy.flag(report.endless,"used_preseed",false): return rejected
	if not Legacy.count_at_least(report.get("moves"),501) or not Legacy.count_at_least(report.get("shots"),51) or not Legacy.count_at_least(report.endless.get("defeated_boss_instance"),1): return rejected
	var saved:=Journey.new()
	var previous_save:=previous+"campaign.json.journey"
	# JSON parses numeric values as floats. Compare validated canonical states,
	# not strict Dictionary equality between JSON floats and journal integers.
	if Journal.new(previous_save).load_journey(saved)!=Journal.LoadResult.LOADED or saved.to_state()!=normalized_state(report.endless.get("saved_state")) or FileAccess.get_sha256(previous_save)!=report.endless.get("saved_sha256"): return rejected
	if not saved.get_pending_clear().is_empty() or saved.get_entry().chapter!=chapter or int(saved.to_state().cleared_stage)<1 or int(saved.to_state().cleared_stage)>=12: return rejected
	var cleared_stage:=int(saved.to_state().cleared_stage)
	if int(report.chapter)!=(cleared_stage-1)%6+1 or report.endless.get("loop")!=(cleared_stage-1)/6+1: return rejected
	if not report.endless.get("before_state") is Dictionary or not report.endless.get("earned_counts") is Dictionary or not report.endless.get("choice") is String: return rejected
	if not validate_transition(report.endless.before_state,saved.to_state(),int(report.endless.loop),int(report.chapter),report.endless.earned_counts,report.endless.choice,int(saved.to_state().coins)): return rejected
	var log:=FileAccess.get_file_as_string(previous+"driver.log")
	if RegEx.create_from_string(Legacy.FORBIDDEN).search(log)!=null or RegEx.create_from_string("(?m)^TEST PASS: "+Legacy.MARKERS[int(report.chapter)-1]+" [1-9][0-9]*\\r?$").search_all(log).size()!=1: return rejected
	# Copy exact bytes from a VERIFIED previous natural clear, never synthesize
	# prerequisite flags or rewrite the parent's journal/backup.
	var bytes:=FileAccess.get_file_as_bytes(previous_save)
	var target:=FileAccess.open(destination,FileAccess.WRITE)
	if target==null: return rejected
	target.store_buffer(bytes); target.close()
	if FileAccess.get_sha256(destination)!=FileAccess.get_sha256(previous_save): return rejected
	return {"valid":true,"loop":saved.get_entry().loop,"before_state":saved.to_state(),"parent_report_sha256":FileAccess.get_sha256(previous+"report.json"),"parent_saved_sha256":FileAccess.get_sha256(previous_save),"previous_process_id":report.endless.process_id}
