extends SceneTree
## Pure diagnostic geometry; not a physics or ordinary-run proof.
const Clearance = preload("res://scripts/art/VerifyNurseryEncounterRun.gd")
var clearance_script: Script = Clearance
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("TEST FAIL: ChapterTerrainWitnessTest "+label)
func _initialize() -> void:
	check(clearance_script.has_method("body_clearance_witness"),"nearest terrain witness missing")
	if failures: quit(1); return
	var bounds:=Rect2(0,0,1000,1000)
	var obstacles: Array[Dictionary]=[{"rect":Rect2(100,100,80,80)}]
	for fixture in [[Vector2(10,50),true,0.0],[Vector2(9.97,50),true,-0.03],[Vector2(9.9,50),false,-0.1],[Vector2(90.03,150),true,-0.03],[Vector2(90.1,150),false,-0.1],[Vector2(97,96),false,-5.0]]:
		var witness: Dictionary=clearance_script.call("body_clearance_witness",fixture[0],bounds,obstacles,10.0)
		check(witness.clear==fixture[1],"witness disagrees with original clearance")
		check(is_equal_approx(float(witness.gap),float(fixture[2])),"wrong signed circle clearance")
		check(witness.point==[fixture[0].x,fixture[0].y] and witness.radius==10.0,"witness lost actual geometry")
	var witness: Dictionary=clearance_script.call("body_clearance_witness",Vector2(90.1,150),bounds,obstacles,10.0)
	check(witness.kind=="obstacle" and witness.index==0 and witness.rect==[100.0,100.0,80.0,80.0],"nearest obstacle not identified")
	check(obstacles[0].rect==Rect2(100,100,80,80),"diagnostic mutated obstacle")
	if failures==0: print("TEST PASS: ChapterTerrainWitnessTest %d"%checks)
	quit(1 if failures else 0)
