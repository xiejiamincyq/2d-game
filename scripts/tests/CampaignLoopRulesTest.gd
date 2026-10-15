extends SceneTree
const Rules=preload("res://scripts/systems/CampaignLoopRules.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: CampaignLoopRulesTest "+label)
func _initialize() -> void:
	var base: Array[int]=[0,0,0,2]
	for chapter in range(1,7):
		var original:=base.duplicate()
		check(Rules.compose(base,chapter,1)==original,"first loop unchanged")
		var prior_count:=base.size()
		var prior_species:=0
		for loop in [2,3,4,9,12,1000000]:
			var queue:=Rules.compose(base,chapter,loop)
			check(queue.size()>base.size() and queue.size()>=prior_count and queue.size()<=Rules.MAX_ENCOUNTER_ENEMIES,"growing bounded total")
			check(queue==Rules.compose(base,chapter,loop) and base==original,"deterministic and no caller mutation")
			var species: Dictionary={}
			for kind in queue:
				if kind<Rules.FOREIGN_KIND_BASE:
					check(kind in base,"original kinds stay valid")
				else:
					var role:=Rules.foreign_role(kind)
					check(not role.is_empty() and role.chapter!=chapter,"actual implemented foreign species, never duplicate native identity")
					species[kind]=true
			check(species.size()>=prior_species and species.size()>0,"progressive mixed species")
			if loop<=4: check(species.size()==loop-1,"one additional species each early loop")
			prior_count=queue.size(); prior_species=species.size()
	check(Rules.health_scale(1)==1 and Rules.health_scale(2)>1 and Rules.health_scale(3)>Rules.health_scale(2),"loop HP strictly grows without speeding attacks")
	check(is_finite(Rules.health_scale(Rules.MAX_LOOP)),"extreme legal checkpoint stays finite")
	var empty: Array[int]=[]
	check(Rules.compose(empty,1,2).is_empty(),"no enemies manufactured for empty encounter")
	check(Rules.foreign_role(99).is_empty() and Rules.foreign_role(999).is_empty(),"unknown token rejected")
	for invalid in [[0,1],[7,1],[1,0],[1,Rules.MAX_LOOP+1]]:
		check(Rules.compose(base,invalid[0],invalid[1]).is_empty(),"invalid chapter/loop rejected")
	if failures==0: print("TEST PASS: CampaignLoopRulesTest %d"%checks)
	quit(1 if failures else 0)
