extends SceneTree
## Pure diagnostic contract only. Synthetic model states are NOT victories.
const Evidence = preload("res://scripts/art/CampaignEndlessEvidence.gd")
const Journey = preload("res://scripts/systems/CampaignJourney.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: CampaignEndlessEvidenceTest "+label)
func _initialize() -> void:
	var parsed:=Evidence.parse_arguments(PackedStringArray(["leg_01","supply","journey=FRESH"]))
	check(parsed.enabled and parsed.valid and parsed.parent=="FRESH" and parsed.args==PackedStringArray(["leg_01","supply"]),"separate fresh journey argument")
	check(not Evidence.parse_arguments(PackedStringArray(["journey=../../user"])).valid,"reject traversal")
	check(not Evidence.parse_arguments(PackedStringArray(["journey=a","journey=b"])).valid,"reject duplicate parents")
	check(Evidence.parse_arguments(PackedStringArray(["leg","journey_route=risk","journey=FRESH"])).route=="risk","explicit natural risk route")
	check(not Evidence.parse_arguments(PackedStringArray(["journey_route=bad","journey=FRESH"])).valid,"reject invalid route")
	check(Evidence.parse_arguments(PackedStringArray(["leg","journey_profile=1","journey=FRESH"])).profile,"real-clock profile flag")
	check(not Evidence.parse_arguments(PackedStringArray(["journey_profile=yes","journey=FRESH"])).valid,"reject ambiguous profile flag")
	check(not Evidence.parse_arguments(PackedStringArray(["journey_profile=1","journey_profile=0","journey=FRESH"])).valid,"reject duplicate profile flags")
	check(Evidence.parse_arguments(PackedStringArray(["leg","chain=FRESH"])).args==PackedStringArray(["leg","chain=FRESH"]),"preserve explicit historical diagnostics")
	var journey:=Journey.new()
	for stage in 12:
		var before:=journey.to_state()
		var loop:=stage/6+1
		var chapter:=stage%6+1
		var balance:=100+stage
		check(journey.commit_clear(loop,chapter,balance,{},""),"synthetic transition fixture")
		var after:=journey.to_state()
		check(Evidence.validate_transition(before,after,loop,chapter,{},"",balance),"accept exact normal clear transition "+str(stage))
		check(not Evidence.validate_transition(before,before,loop,chapter,{},"",balance),"reject absent advancement")
		check(not Evidence.validate_transition(before,after,loop,chapter,{},"",balance+1),"reject unearned balance")
		check(not Evidence.validate_transition(before,after,loop+1,chapter,{},"",balance),"reject skipped loop")
	check(journey.get_entry()=={"loop":3,"chapter":1},"two model rounds lead to round three")
	var before:=Journey.new()
	var after:=Journey.new()
	check(after.commit_clear(1,1,37,{"damage":1},"damage"),"synthetic inherited card fixture")
	check(Evidence.validate_transition(before.to_state(),after.to_state(),1,1,{"damage":1},"damage",37),"accept exactly one earned ordinary card")
	check(not Evidence.validate_transition(before.to_state(),after.to_state(),1,1,{"damage":1},"",37),"reject unexplained inherited ability")
	var forged:=after.to_state(); forged.inherited_counts.damage=2
	check(not Evidence.validate_transition(before.to_state(),forged,1,1,{"damage":1},"damage",37),"reject duplicate inheritance")
	var from_json: Variant=JSON.parse_string(JSON.stringify(after.to_state()))
	check(Evidence.normalized_state(from_json)==after.to_state(),"canonical saved state survives JSON numeric types")
	check(Evidence.normalized_state({"version":1}).is_empty() and Evidence.normalized_state([1]).is_empty(),"normalization does not accept malformed states")
	var folder:=Evidence.ROOT+"endless_evidence_unit_%d/"%OS.get_process_id()
	check(not DirAccess.dir_exists_absolute(folder) and DirAccess.make_dir_recursive_absolute(folder)==OK,"fresh owned author-only fixture")
	var bank:={"scripts/art/CampaignEndlessEvidence.gd":FileAccess.get_sha256("res://scripts/art/CampaignEndlessEvidence.gd")}
	var prepared:=Evidence.prepare(folder,"FRESH",1,bank)
	check(prepared.valid and prepared.before_state==Journey.new().to_state() and prepared.loop==1,"fresh first leg creates no fake progression")
	check(Evidence.prepare(folder,"FRESH",1,Evidence.source_bank()).valid,"complete current bank includes explicit themes and new verifier/launcher")
	check(not FileAccess.file_exists(folder+"campaign.json.journey") and not FileAccess.file_exists(folder+"campaign.json"),"fresh preparation writes no saves")
	check(not Evidence.prepare(folder,"FRESH",2,bank).valid,"cannot preseed chapter two")
	check(not Evidence.prepare(folder,"missing_previous_natural_run",2,bank).valid,"missing actual predecessor rejected safely")
	check(DirAccess.remove_absolute(folder)==OK,"remove only this owned empty unit folder")
	if failures==0: print("TEST PASS: CampaignEndlessEvidenceTest %d"%checks)
	quit(1 if failures else 0)
