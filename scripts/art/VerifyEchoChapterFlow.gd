extends "res://scripts/art/VerifyFoundryChapterFlow.gd"
## Actual fifth chapter with ordinary input only; never writes combat state.
var selected_route: StringName = &"supply"
var boss_phases := {}
var boss_actions := {}
var expected_kills := 0
func _initialize() -> void:
	var args := configure_chain_arguments(OS.get_cmdline_user_args())
	if not chain_context.valid or args.size()!=2 or not ChainEvidence.safe_id(args[0]) or args[1] not in ["supply","risk"]: quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	selected_route = StringName(args[1])
	additional_sources = [
		"scripts/art/VerifyEchoChapterFlow.gd","scripts/art/VerifyFoundryChapterFlow.gd",
		"scripts/campaign/EchoChapter.gd","scenes/campaign/echo_chapter.tscn",
		"scripts/systems/ChapterEncounterDirector.gd","scripts/systems/EchoEncounterDirector.gd",
		"scripts/campaign/RegionalEnemyFactory.gd","scripts/world/EchoMap.gd",
		"scripts/world/EchoArenaLayout.gd","scripts/world/EchoField.gd","scripts/world/EchoBeat.gd",
		"scripts/world/EchoPropArt.gd","scripts/world/EchoFloor.gd","scenes/world/echo_court.tscn",
		"scripts/actors/EchoBellPriestBoss.gd","scripts/actors/EchoSentinelEnemy.gd","scripts/actors/CirclingShadeEnemy.gd",
		"scripts/components/BellPriestAttackDirector.gd","scripts/components/BellPriestStrike.gd",
		"scripts/components/BellPriestPendantProjectile.gd","scripts/components/BellPriestCrownProjectile.gd",
		"scripts/components/NativeBellPriestMotion.gd","scripts/components/NativeProjectileOriginSafety.gd",
		"scripts/components/ArchivePageProjectile.gd","scripts/components/VineSeedProjectile.gd",
		"scripts/effects/EnemyWorldStatus.gd","scripts/effects/PlayerOcclusionOutline.gd",
		"scripts/systems/BossCameraFraming.gd","assets/art/actors/native/bell_priest_motion_v2.tres",
		"scenes/actors/native/bell_priest_paper_v2.tscn",
	]
	for path in additional_sources: check(FileAccess.file_exists("res://"+path),"missing proof source "+path)
	if failures: quit(1); return
	call_deferred("_run")
func chapter_number() -> int: return 5
func proof_marker() -> String: return "VerifyEchoChapterFlow"
func prepare_progress(path: String) -> bool:
	var prerequisite := Progress.new()
	for chapter in range(1,5):
		if not prerequisite.record_boss_defeat(chapter): return false
	return not FileAccess.file_exists(path) and Store.new(path).save_progress(prerequisite)
func proof_scope() -> String:
	return "Actual Main -> Echo in GPU SubViewport; ordinary UI/pointer/movement/fire/dash -> real fifth Boss clear/save/unlock6. Isolated prerequisites1..4 prepared before run. No actor stats/direct damage/in-run reward writes. Not OS desktop input, human playtest, performance or six-chapter acceptance."
func _click(button: Button) -> void:
	var chapter = actual_scene()
	if chapter.has_method("_chapter_number") and chapter._chapter_number()==5 and button==chapter.ui.supply_button and selected_route==&"risk": button = chapter.ui.risk_button
	await super._click(button)
func minimum_victory_kills(chapter: Node) -> int:
	# The regional policy has fewer, more dangerous actors than the nursery.
	# Require the ACTUAL seeded mandatory/selected risk debts plus real Boss.
	expected_kills = 1
	for index in (3 if selected_route==&"risk" else 2):
		var encounter: Dictionary = chapter.director.encounters[index]
		expected_kills += encounter.sentinel+encounter.shade
	return expected_kills
func additional_report() -> Dictionary:
	var report := super.additional_report()
	report.prerequisite_fixture = [1,2,3,4]; report.route = String(selected_route)
	report.expected_actual_kills = expected_kills; report.boss_phases = boss_phases; report.boss_actions = boss_actions
	return report
func pilot_motion(chapter: Node,policy: RefCounted,step: int,threats: Array[Vector2],_legacy: Node,danger_distance: float) -> Dictionary:
	var position: Vector2 = chapter.player.position
	var boss = chapter.director.get_active_boss()
	var goal := Vector2.RIGHT.rotated(step/180.0)
	if boss!=null:
		var offset: Vector2 = position-boss.global_position
		goal = offset.normalized().orthogonal()+offset.normalized()*clampf((320-offset.length())/80,-2,2)
	var loot: Node2D = null; var closest := INF
	for item: Node2D in chapter.pickups.get_children():
		if item.is_queued_for_deletion(): continue
		var script: String = item.get_script().resource_path
		var wanted: bool = chapter.director.state==chapter.director.State.COLLECT or (script.ends_with("HeartPickup.gd") and chapter.player.health.current_health<80) or (script.ends_with("ShieldPickup.gd") and chapter.player.shield<chapter.player.max_shield)
		var distance := position.distance_squared_to(item.position)
		if wanted and distance<closest: closest = distance; loot = item
	if loot!=null: goal = chapter.map.layout.get_navigation_direction(position,loot.position,chapter.player.get_body_radius())
	for beat in chapter.map.echo_field.get_children():
		if beat.state in [beat.State.WARNING_FIRST,beat.State.PULSE_FIRST,beat.State.WARNING_SECOND,beat.State.PULSE_SECOND]:
			var at: Vector2 = beat.get_current_center()
			threats.append(at); danger_distance = minf(danger_distance,position.distance_to(at))
	if boss!=null:
		var combat = boss.attack_director
		boss_phases[str(combat.current_phase)] = true
		if combat.is_attacking(): boss_actions[String(combat.action)] = true
		if combat.action_stage in [combat.Stage.WARNING,combat.Stage.ACTIVE]:
			var offset: Vector2 = position-combat.locked_origin
			var along: float = offset.dot(combat.locked_direction)
			var cross: float = absf(offset.dot(combat.locked_direction.orthogonal()))
			if (combat.action==&"bell" and along>-30 and along<170 and cross<45) or (combat.action==&"crown" and along>0 and cross<60):
				goal = combat.locked_direction.orthogonal(); danger_distance = 0
	for shot in chapter.projectiles.get_children():
		if shot.get_script()==preload("res://scripts/components/BellPriestPendantProjectile.gd") and not shot.is_queued_for_deletion():
			var future: Vector2 = shot.global_position+shot.direction*shot.SPEED*0.12*(-1 if shot.returning else 1)
			threats.append(shot.global_position); threats.append(future)
			danger_distance = minf(danger_distance,position.distance_to(future))
	var direction: Vector2 = policy.choose_direction(position,goal,threats,func(point): return chapter.map.layout.is_position_walkable(point,chapter.player.get_body_radius()))
	return {"direction":direction,"dash":danger_distance<100}
