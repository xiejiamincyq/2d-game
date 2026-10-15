extends SceneTree
## Synthetic recorder inputs test clock/accounting only, NOT actual performance.
const Profile=preload("res://scripts/art/CampaignRuntimeProfile.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: CampaignRuntimeProfileTest "+label)
func _initialize() -> void:
	var stats:={"process_ms":1.0,"physics_ms":0.5,"draw_calls":10,"objects":20}
	var profile:=Profile.new()
	profile.ingest(1000000,1,"COMBAT:0",16,20,stats)
	profile.ingest(2000000,2,"COMBAT:0",16,20,stats)
	profile.ingest(3000000,3,"COMBAT:0",16,20,stats)
	profile.ingest(3034000,4,"COMBAT:0",18,25,stats)
	check(profile.rows.size()==2 and profile.warmup_frames==1,"two second phase warmup and positive samples")
	if profile.rows.size()==2:
		check(profile.rows[0].interval_ms==1000 and profile.rows[1].interval_ms==34,"retain slow frames instead of filtering them")
	profile.ingest(4000000,5,"",0,0,stats)
	profile.ingest(8000000,6,"BOSS:1",1,3,stats)
	profile.ingest(10000000,7,"BOSS:1",1,3,stats)
	check(profile.rows.size()==3 and profile.rows[-1].phase=="BOSS:1" and profile.rows[-1].interval_ms==2000,"pause/modal time cannot contaminate resumed phase; real post-warmup interval retained")
	var report:=profile.finish()
	check(report.has("all") and report.has("dense_at_least_12") and report.has("boss"),"separate actual interval windows")
	if report.has("all"):
		check(report.all.frames==3 and report.all.interval_ms.maximum==2000 and report.dense_at_least_12.frames==2 and report.boss.frames==1,"exact summary and dense membership")
	var bounded:=Profile.new(1)
	bounded.ingest(1000000,1,"COMBAT:0",14,0,stats)
	bounded.ingest(3000000,2,"COMBAT:0",14,0,stats)
	bounded.ingest(3010000,3,"COMBAT:0",14,0,stats)
	check(bounded.rows.size()==1 and bounded.overflow,"overflow is explicit, not silent truncation")
	var invalid:=Profile.new()
	invalid.ingest(1000000,1,"COMBAT:0",14,0,stats)
	invalid.ingest(999999,2,"COMBAT:0",14,0,stats)
	check(invalid.invalid_clock,"nonmonotonic frame clock cannot become good FPS")
	var resumed:=Profile.new()
	resumed.ingest(1000000,1,"COMBAT:0",16,0,stats)
	resumed.ingest(3000000,2,"COMBAT:0",16,0,stats)
	resumed.ingest(4000000,3,"",0,0,stats)
	resumed.ingest(5000000,4,"COMBAT:0",16,0,stats)
	resumed.ingest(7000000,5,"COMBAT:0",16,0,stats)
	check(resumed.rows.size()==2 and resumed.rows[0].window_id!=resumed.rows[1].window_id,"resuming the same encounter starts a new measured window")
	check(resumed.finish().longest_contiguous_dense_seconds==0,"pause gaps cannot count as continuous dense load")
	if failures==0: print("TEST PASS: CampaignRuntimeProfileTest %d"%checks)
	quit(1 if failures else 0)
