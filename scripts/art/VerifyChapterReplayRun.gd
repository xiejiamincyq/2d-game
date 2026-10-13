extends "res://scripts/art/VerifyChapterBuildRun.gd"
## Genuine fresh-save clear -> actual replay UI -> bounded ordinary combat.
## No prerequisite save fixture, scene switch, stat/reward or damage injection.
func proof_marker() -> String: return "VerifyChapterReplayRun"

func after_ordinary_clear(chapter: Node, report: Dictionary) -> bool:
	var original_id := chapter.get_instance_id()
	var old_seed: int = chapter.run_seed
	var old_layout: Array = chapter.map.layout.get_obstacle_descriptors().duplicate(true)
	var path := output + "campaign.json"
	var saved := Progress.new()
	check(Store.new(path).load_progress(saved)==Store.LoadResult.LOADED,"replay lacks real saved clear")
	var saved_state := saved.to_state()
	var saved_sha := FileAccess.get_sha256(path)
	var defeated_boss: int = chapter.director.defeated_boss_instance
	check(defeated_boss>0 and saved.has_cleared(1) and saved.is_unlocked(2),"replay parent is not actual defeated Boss")
	await _click(chapter.ui.replay_button)
	var fresh: Node = null
	var deadline := Time.get_ticks_msec()+4000
	while Time.get_ticks_msec()<deadline:
		var candidate := actual_scene()
		if is_instance_valid(candidate) and candidate.get_instance_id()!=original_id and candidate.has_method("_chapter_number"):
			fresh = candidate
			break
		await process_frame
	check(fresh!=null,"actual Replay button did not create a fresh chapter")
	if fresh==null: return false
	check(fresh._chapter_number()==1 and fresh.director.state==fresh.director.State.INTRO,"Replay entered wrong chapter/state")
	check(fresh.run_seed!=old_seed and fresh.map.layout.get_obstacle_descriptors()!=old_layout,"Replay reused actual map")
	check(fresh.progress.to_state()==saved_state and fresh.campaign_store_path==path and FileAccess.get_sha256(path)==saved_sha,"Replay changed permanent unlock or save bytes")
	var fresh_growth: Dictionary = fresh.growth.get_snapshot_state()
	check(fresh.growth.coins==0 and fresh.growth.upgrade_counts.is_empty() and fresh.growth.acquired_evolution_id.is_empty() and fresh.player.active_build_evolutions.is_empty(),"Replay inherited previous run's coins/modules/evolution")
	for level in fresh.growth.family_levels.values(): check(int(level)==1,"Replay inherited family level")
	check(not fresh.clear_saved and fresh.kills==0,"Replay inherited clear/kills")
	var capture_before := await replay_frame(fresh,"replay_intro.png")
	for frame in 360:
		if not fresh.player.is_entrance_active(): break
		await process_frame
	check(not fresh.player.is_entrance_active(),"Replay natural entrance unfinished")
	var starting_shots := actual_shots
	await prepare_layout_capture(fresh)
	await _click(fresh.ui.proceed_button)
	await resume_ordinary_input()
	check(not fresh.player.spawn_input_guard_active,"Replay neutral input did not clear birth guard")
	var moved := 0
	var combat_steps := 0
	var policy := Policy.new(20261009)
	for step in 900:
		_release()
		if fresh.director.state!=fresh.director.State.COMBAT: break
		combat_steps+=1
		var threats: Array[Vector2] = []
		var nearest := INF
		var aim: Vector2 = fresh.player.position+Vector2(300,0)
		for enemy in fresh.director.get_active_enemies():
			if not is_instance_valid(enemy) or enemy.health.current_health<=0: continue
			threats.append(enemy.global_position)
			var distance: float = fresh.player.position.distance_squared_to(enemy.global_position)
			if distance<nearest: nearest=distance; aim=enemy.global_position
		var motion := pilot_motion(fresh,policy,step,threats,null,INF)
		var direction: Vector2 = motion.direction
		for axis in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
			if axis[1]>0: Input.action_press(axis[0],axis[1])
		var view := fresh.get_viewport()
		_inject_mouse(view,(view.get_canvas_transform()*aim_world_point(fresh,aim)).clamp(Vector2.ONE,view.get_visible_rect().size-Vector2.ONE))
		Input.action_press("fire")
		if motion.dash: Input.action_press("dash_melee")
		var before: Vector2 = fresh.player.position
		await physics_frame
		await process_frame
		if fresh.player.position.distance_to(before)>0.01: moved+=1
		check(Clearance.has_body_clearance(fresh.player.position,fresh.map.layout.world_bounds,fresh.map.layout.get_obstacle_descriptors(),fresh.player.get_body_radius()),"Replay movement penetrated terrain")
	_release()
	check(moved>100 and actual_shots-starting_shots>10 and fresh.kills>0,"Replay lacks ordinary movement/fire/real enemy kills")
	check(fresh.director.state in [fresh.director.State.COMBAT,fresh.director.State.COLLECT,fresh.director.State.REWARD],"Replay unexpectedly failed or skipped combat")
	check(FileAccess.get_sha256(path)==saved_sha and fresh.progress.to_state()==saved_state,"Replay combat changed permanent progress")
	check(ChainEvidence.source_bank_matches(build_source_bank),"source changed during Replay proof")
	report["replay"] = {"used_preseed":false,"process_id":OS.get_process_id(),"parent_defeated_boss_instance":defeated_boss,"parent_map_seed":old_seed,"new_map_seed":fresh.run_seed,"saved_state":saved_state,"saved_sha256":saved_sha,"fresh_growth":fresh_growth,"combat_steps":combat_steps,"moved_frames":moved,"shots":actual_shots-starting_shots,"kills":fresh.kills,"health":fresh.player.health.current_health,"state":fresh.director.State.keys()[fresh.director.state],"intro_capture":capture_before,"combat_capture":await replay_frame(fresh,"replay_combat.png"),"scope":"Actual saved first Boss victory and actual Replay pointer button in same process. Fresh map, fresh run growth, unchanged permanent save, bounded first-encounter normal combat. Not a second victory, six-leg chain or human acceptance."}
	return failures==0

func resume_ordinary_input() -> void:
	# Proceed re-arms the production birth guard. Like the base driver's resumed
	# first frame, release inputs across real physics before issuing movement.
	_release()
	await physics_frame
	await process_frame

func replay_frame(chapter: Node, filename: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	var path := output+filename
	check(chapter.get_viewport().get_texture().get_image().save_png(path)==OK,"Replay frame save failed")
	return {"file":path.trim_prefix("res://"),"sha256":FileAccess.get_sha256(path)}
