extends SceneTree
## Real ChapterRun/journal/director and native actors; controlled clocks, not wins.
const Registry=preload("res://scripts/campaign/ChapterSceneRegistry.gd")
const Rules=preload("res://scripts/systems/CampaignLoopRules.gd")
const Journey=preload("res://scripts/systems/CampaignJourney.gd")
const Journal=preload("res://scripts/systems/CampaignJourneyStore.gd")
const Store=preload("res://scripts/systems/CampaignProgressStore.gd")
const Support=preload("TestSupport.gd")
var checks:=0
var failures:=0
var baseline_hp: Dictionary={}
var protected: Dictionary={}
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: CampaignLoopIntegrationTest "+label)
func _hash(path: String) -> String: return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for base in [Store.DEFAULT_PATH,Journal.DEFAULT_PATH]:
		for suffix in ["",".bak",".tmp"]: protected[base+suffix]=_hash(base+suffix)
	for chapter in range(1,7):
		for loop in [1,2]: await chapter_case(chapter,loop)
	for path in protected: check(_hash(path)==protected[path],"default saves unchanged "+path)
	if failures==0: print("TEST PASS: CampaignLoopIntegrationTest %d"%checks)
	quit(1 if failures else 0)
func chapter_case(chapter: int,loop: int) -> void:
	var path:="user://loop_integration_%d_%d_%d_%d.json"%[OS.get_process_id(),Time.get_ticks_usec(),chapter,loop]
	var journal:=Journal.new(path+".journey"); var journey:=Journey.new()
	check(journal.load_journey(journey)==Journal.LoadResult.MISSING,"isolated missing fixture")
	check(journey.restore_state({"version":1,"cleared_stage":(loop-1)*6+chapter-1,"coins":37,"inherited_counts":{}}) and journal.save_journey(journey),"owned loop checkpoint written")
	var run: Node=Registry.instantiate_chapter(chapter)
	run.campaign_store_path=path; run.audio_enabled=false; run.run_seed=521
	root.add_child(run); paused=false
	run.director.set_process(false); run.player.set_physics_process(false)
	check(run.run_loop==loop and run.growth.coins==37,"real coordinator resolves checkpoint loop/coins")
	check(run.director.get("run_loop")==loop,"loop reaches shared combat director")
	check(run.player.health.max_health==90+10*chapter and run.player.shield==20,"loop does not stack chapter base stats")
	for encounter_index in 3:
		run.director._prepare_encounter(encounter_index)
		var native_kinds: Array[int]=run.director._encounter_kinds(run.director.get_encounter())
		var expected:=Rules.compose(native_kinds,chapter,loop); expected.sort()
		var actual: Array=run.director.spawn_queue.duplicate(); actual.sort()
		check(actual==expected,"all encounter queues use bounded loop composition c%d e%d l%d"%[chapter,encounter_index,loop])
		if run.director.has_method("configure_loop"):
			check(not run.director.configure_loop(loop+1),"difficulty immutable after start")
			# One real body per distinct kind, not hundreds of identical copies.
			var distinct: Dictionary={}
			for kind in expected: distinct[kind]=true
			for kind in distinct:
				var actor: Node=run.director._create_enemy_actor(kind)
				check(actor!=null,"actual native actor exists")
				if actor==null: continue
				actor.position=Vector2(0,300); run.director.enemy_parent.add_child(actor); actor.set_physics_process(false)
				var maximum: float=actor.health.max_health
				if kind<Rules.FOREIGN_KIND_BASE:
					var key:="%d_%d_%d"%[chapter,encounter_index,kind]
					if loop==1: baseline_hp[key]=maximum
					else: check(is_equal_approx(maximum,baseline_hp[key]*Rules.health_scale(loop)),"actual ordinary HP scaled once")
				else: check(actor.native_visual!=null and actor.health.current_health==maximum,"visitor owns real native visual/full health")
				check(run.director._register_enemy(actor),"real actor admitted to ownership")
				check(is_equal_approx(actor.health.max_health,maximum),"registration cannot apply HP twice")
				actor.free()
			await process_frame
	if run.director.has_method("configure_loop"):
		run.director.state=run.director.State.BOSS_READY
		check(run.director.begin_boss(),"actual regional Boss begins")
		var boss: Node=run.director.get_active_boss()
		var key:="boss%d"%chapter
		if loop==1: baseline_hp[key]=boss.health.max_health
		else: check(is_equal_approx(boss.health.max_health,baseline_hp[key]*Rules.health_scale(loop)),"actual Boss HP grows, same attack controller")
	paused=false; Support.stop_audio(run.audio); run.free(); await process_frame
	for suffix in ["",".bak",".tmp",".journey",".journey.bak",".journey.tmp"]:
		if FileAccess.file_exists(path+suffix): check(DirAccess.remove_absolute(path+suffix)==OK,"owned fixture cleanup")
