extends "ArchiveBossBroodLifecycleTest.gd"
## Actual environmental ownership failure, with a genuine in-flight page.
func run() -> void:
	var f := boss_fixture(); var combat = f.combat
	var clears := [0]; var kills := [0]; var failures_seen := [0]
	f.director.chapter_cleared.connect(func(_chapter): clears[0] += 1)
	f.director.enemy_killed.connect(func(_actor,_source,_coins): kills[0] += 1)
	f.director.run_failed.connect(func(_reason):
		failures_seen[0] += 1
		check(not combat.start_action(&"page"),"failed callback can restart living Boss attack"))
	check(combat.start_action(&"page"),"real page unavailable")
	step(combat,combat.DURATIONS[&"page"][0])
	check(combat.owned_projectiles.size()==1,"real in-flight page missing")
	var field = f.map.spore_field; f.map.remove_child(field)
	check(f.director.state==f.director.State.FAILED and failures_seen[0]==1,"owner exit not unique failure")
	check(not combat.is_attacking() and combat.get_state_name()=="DEATH" and combat.owned_projectiles.is_empty(),"failed world leaves live Boss attack/projectile")
	await process_frame; await process_frame
	check(clears[0]==0 and kills[0]==0 and f.boss.health.current_health>0 and not f.boss.death_resolved,"failure cancellation fabricates death/win/reward")
	check(f.boss.projectile_parent.get_child_count()==0 and f.director.get_attack_targets().is_empty(),"failed world continues hostile weapons")
	field.free(); f.host.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveBossFailureCancellationTest %d"%checks)
	quit(1 if failures else 0)
