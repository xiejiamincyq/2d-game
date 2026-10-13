extends "ArchiveBossSealTest.gd"
## Authoritative automatic actions; controlled clock, not ordinary chapter input.
func finish_action(f: Dictionary,expected: StringName) -> void:
	var combat = f.combat
	check(combat.action==expected and combat.action_stage==combat.Stage.WARNING,"finite automatic action begins with visible warning "+String(expected))
	step(combat,combat.DURATIONS[expected][0])
	var page: Node2D
	if expected==&"page":
		check(f.shots.get_child_count()==1 and combat.owned_projectiles.size()==1,"automatic page has actual owned projectile")
		if f.shots.get_child_count()==1:
			page = f.shots.get_child(0); page.set_physics_process(false)
	step(combat,combat.DURATIONS[expected][1]); step(combat,combat.DURATIONS[expected][2])
	check(not combat.is_attacking(),"finite automatic recovery ends "+String(expected))
	if expected==&"page" and is_instance_valid(page):
		# Director-only stepping does not advance an independently owned projectile.
		# Exercise that exact remaining-flight gap before letting the next cue begin.
		var next_primary: StringName = combat.next_primary
		combat.advance(100)
		check(not combat.is_attacking() and combat.next_primary==next_primary and combat.owned_projectiles.size()==1 and not page.is_queued_for_deletion(),"automatic action overlaps still-live prior page")
		for kind in [&"page",&"seal",&"brood"]:
			check(not combat.start_action(kind),"direct attack bypasses live-page overlap gate "+String(kind))
		# Move the controlled target off the locked ray; no HP/immune/stat edits.
		# Drive the real projectile clock through its lifetime, not a fabricated free.
		var target_at: Vector2 = f.target.position
		f.target.position += combat.locked_direction.orthogonal()*200
		await physics_frame # Synchronize the real body transform before swept queries.
		var samples := 0
		while is_instance_valid(page) and not page.is_queued_for_deletion() and samples<180:
			page._physics_process(1.0/120); samples += 1
		check(samples>0 and samples<=180 and page.is_queued_for_deletion(),"actual finite page flight never expires")
		await process_frame
		f.target.position = target_at
		check(f.shots.get_child_count()==0,"expired prior projectile survives deferred cleanup")
func run() -> void:
	var f := fixture(); var combat = f.combat
	f.boss.world_bounds = Rect2(-1000,-1000,2000,2000)
	combat.attack_gap = 0; combat.advance(100)
	check(combat.action==&"page" and combat.action_stage==combat.Stage.WARNING,"automatic opening page absent")
	await finish_action(f,&"page"); combat.advance(100)
	check(combat.action==&"seal" and combat.action_stage==combat.Stage.WARNING,"automatic loop never uses actual seal")
	if failures: f.host.free(); await process_frame; quit(1); return
	await finish_action(f,&"seal"); combat.advance(100)
	check(combat.action==&"page","page/seal alternation missing")
	combat.set_health_phase(2); step(combat,0.65); combat.advance(100)
	check(combat.action==&"brood" and combat.action_stage==combat.Stage.WARNING,"phase2 automatic brood absent")
	await finish_action(f,&"brood"); combat.advance(100)
	check(combat.action==&"page","phase2 brood cannot return to combat")
	combat.set_health_phase(3); step(combat,0.65); combat.advance(100)
	check(combat.action==&"brood","phase3 finite automatic brood absent")
	await finish_action(f,&"brood")
	for expected in [&"page",&"seal",&"page",&"seal"]:
		combat.advance(100)
		check(combat.action==expected and combat.action_stage==combat.Stage.WARNING,"third-phase loop repeats brood/skips short warning")
		await finish_action(f,expected)
	check(combat.brood_released_phases==[2,3],"automatic requests reset finite budget")
	f.host.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveBossCycleTest %d" % checks)
	quit(1 if failures else 0)
