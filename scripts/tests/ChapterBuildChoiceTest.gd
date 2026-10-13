extends SceneTree
## Diagnostic driver choice policy only; not production or gameplay proof.
const Driver = preload("res://scripts/art/VerifyChapterBuildRun.gd")
var assertions := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("TEST FAIL: ChapterBuildChoiceTest "+label)
func _initialize() -> void:
	var offers: Array = [
		{"id":"damage","family":"ballistics","kind":"core","free_available":true,"affordable":false},
		{"id":"dash_impact","family":"mobility","kind":"core","free_available":true,"affordable":true},
		{"id":"mine","family":"mobility","kind":"core","free_available":true,"affordable":true},
		{"id":"arc","family":"automation","kind":"core","free_available":true,"affordable":false},
		{"id":"drone","family":"automation","kind":"core","free_available":true,"affordable":true},
	]
	check(Driver.choose_offer_index(offers,"ballistics",false,{})==0,"free focused fire choice")
	check(Driver.choose_offer_index(offers,"mobility",false,{})==2,"missing mine must take priority")
	check(Driver.choose_offer_index(offers,"automation",false,{})==4,"missing drone first")
	check(Driver.choose_offer_index(offers,"automation",false,{"drone":1})==3,"missing arc after real drone acquisition")
	check(Driver.choose_offer_index(offers,"automation",true,{"drone":1})==4,"paid mode must not buy unavailable arc")
	check(Driver.choose_offer_index(offers,"ballistics",true,{})==-1,"do not buy unaffordable fire card or unrelated family")
	offers.append({"id":"orbital_storm","family":"ballistics","kind":"evolution","free_available":true,"affordable":true})
	check(Driver.choose_offer_index(offers,"ballistics",false,{})==5,"actual eligible evolution must take priority")
	offers[5].free_available=false
	offers[5].affordable=false
	check(Driver.choose_offer_index(offers,"ballistics",false,{})==0,"sold evolution must not be selected")
	check(Driver.choose_offer_index([],"mobility",false,{})==-1,"empty UI has no choice")
	check(Driver.choose_offer_index(offers,"unknown",false,{})==-1,"invalid family")
	if failures==0: print("TEST PASS: ChapterBuildChoiceTest %d"%assertions)
	quit(1 if failures>0 else 0)
