extends "res://scripts/art/VerifyFoundryChapterFlow.gd"
## Actual sixth chapter, ordinary engine inputs only. Prerequisites are isolated
## fixtures, not evidence of a complete six-chapter campaign playthrough.
var selected_route: StringName = &"supply"
var boss_phases := {}
var boss_actions := {}
var expected_kills := 0

func _initialize() -> void:
	var args := configure_chain_arguments(OS.get_cmdline_user_args())
	if not chain_context.valid or args.size()!=2 or not ChainEvidence.safe_id(args[0]) or args[1] not in ["supply","risk"]:
		quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	selected_route = StringName(args[1])
	additional_sources = [
		"scripts/art/VerifyRiftChapterFlow.gd", "scripts/art/VerifyFoundryChapterFlow.gd",
		"scripts/campaign/RiftChapter.gd", "scenes/campaign/rift_chapter.tscn",
		"scripts/systems/ChapterEncounterDirector.gd", "scripts/systems/RiftEncounterDirector.gd",
		"scripts/campaign/RegionalEnemyFactory.gd", "scenes/world/rift_observatory.tscn",
		"scripts/world/RiftMap.gd", "scripts/world/RiftArenaLayout.gd", "scripts/world/RiftField.gd",
		"scripts/world/RiftFault.gd", "scripts/world/RiftFloor.gd", "scripts/world/RiftPropArt.gd",
		"scripts/world/RiftObstacle.gd", "scripts/world/TerrainSweep.gd",
		"scripts/actors/RiftObserverBoss.gd", "scripts/actors/SpaceCutterEnemy.gd", "scripts/actors/RiftEliteEnemy.gd",
		"scripts/components/RiftObserverAttackDirector.gd", "scripts/components/NativeRiftObserverMotion.gd",
		"scripts/components/RiftObserverBeam.gd", "scripts/components/RiftObserverProbe.gd",
		"scripts/components/RiftObserverCircleFlight.gd", "scripts/components/RiftObserverFragment.gd",
		"scripts/components/RiftObserverRefractVolley.gd", "scripts/components/NativeProjectileOriginSafety.gd",
		"scripts/components/SpaceCutAttack.gd", "scripts/components/EliteHybridAttack.gd",
		"scripts/components/RiftShardProjectile.gd", "scripts/components/NativeRiftEliteMotion.gd",
		"scripts/components/NativeScrapperMotion.gd", "scripts/effects/EnemyWorldStatus.gd",
		"scripts/effects/PlayerOcclusionOutline.gd", "scripts/systems/BossCameraFraming.gd",
		"scenes/actors/native/rift_observer_paper_v2.tscn", "assets/art/actors/native/rift_observer_motion_v2.tres",
		"scenes/actors/native/space_cutter_paper_v1.tscn", "assets/art/actors/native/space_cutter_motion_v1.tres",
		"scenes/actors/native/rift_elite_paper_v1.tscn", "assets/art/actors/native/rift_elite_motion_v1.tres",
	]
	for path in additional_sources:
		check(FileAccess.file_exists("res://"+path), "missing proof source "+path)
	if failures: quit(1); return
	call_deferred("_run")

func chapter_number() -> int: return 6
func proof_marker() -> String: return "VerifyRiftChapterFlow"
func prepare_progress(path: String) -> bool:
	var prerequisite := Progress.new()
	for chapter in range(1,6):
		if not prerequisite.record_boss_defeat(chapter): return false
	return not FileAccess.file_exists(path) and Store.new(path).save_progress(prerequisite)
func proof_scope() -> String:
	return "Actual Main -> Rift in GPU SubViewport; ordinary UI/pointer/movement/fire/dash -> real sixth Boss defeat, saved campaign complete and no chapter7. Prerequisites1..5 prepared in a fresh isolated evidence save. No actor stats/direct damage/in-run reward writes. Not OS desktop input, human playtest, performance or full fresh-save six-chapter acceptance."
func _click(button: Button) -> void:
	var chapter = actual_scene()
	if chapter.has_method("_chapter_number") and chapter._chapter_number()==6 and button==chapter.ui.supply_button and selected_route==&"risk":
		button = chapter.ui.risk_button
	await super._click(button)
func minimum_victory_kills(chapter: Node) -> int:
	expected_kills = 1
	for index in (3 if selected_route==&"risk" else 2):
		var encounter: Dictionary = chapter.director.encounters[index]
		expected_kills += encounter.cutter+encounter.elite
	return expected_kills
func additional_report() -> Dictionary:
	var report := super.additional_report()
	report.prerequisite_fixture = [1,2,3,4,5]
	report.route = String(selected_route)
	report.expected_actual_kills = expected_kills
	report.boss_phases = boss_phases; report.boss_actions = boss_actions
	return report

func pilot_motion(chapter: Node, policy: RefCounted, step: int, threats: Array[Vector2], _legacy: Node, danger_distance: float) -> Dictionary:
	var position: Vector2 = chapter.player.position
	var boss = chapter.director.get_active_boss()
	var goal := Vector2.RIGHT.rotated(step/180.0)
	if boss!=null:
		var offset: Vector2 = position-boss.global_position
		goal = offset.normalized().orthogonal()+offset.normalized()*clampf((280-offset.length())/80,-2,2)
	var loot: Node2D = null
	var closest := INF
	for item: Node2D in chapter.pickups.get_children():
		if item.is_queued_for_deletion(): continue
		var script: String = item.get_script().resource_path
		var wanted: bool = chapter.director.state==chapter.director.State.COLLECT or (script.ends_with("HeartPickup.gd") and chapter.player.health.current_health<80) or (script.ends_with("ShieldPickup.gd") and chapter.player.shield<chapter.player.max_shield)
		var distance := position.distance_squared_to(item.position)
		if wanted and distance<closest: closest = distance; loot = item
	if loot!=null:
		goal = chapter.map.layout.get_navigation_direction(position,loot.position,chapter.player.get_body_radius())
	for fault in chapter.map.rift_field.get_children():
		if fault.state in [fault.State.WARNING,fault.State.ACTIVE]:
			var at: Vector2 = fault.get_current_center()
			threats.append(at)
			danger_distance = minf(danger_distance,position.distance_to(at))
	if boss!=null:
		var combat = boss.attack_director
		boss_phases[str(combat.current_phase)] = true
		if combat.is_attacking(): boss_actions[String(combat.action)] = true
		# Do not react to a newly born warning before an ordinary 150ms delay.
		if combat.action_stage==combat.Stage.ACTIVE or (combat.action_stage==combat.Stage.WARNING and combat.action_elapsed>=0.15):
			if combat.action in [&"beam",&"refract"]:
				var offset: Vector2 = position-combat.locked_origin
				var along := offset.dot(combat.locked_direction)
				var cross := absf(offset.dot(combat.locked_direction.orthogonal()))
				if along>-30 and along<360 and cross<60:
					goal = combat.locked_direction.orthogonal(); danger_distance = 0
			elif combat.action==&"probes":
				for landing: Vector2 in combat.probe_landings:
					threats.append(landing)
					danger_distance = minf(danger_distance,position.distance_to(landing))
		for flight in combat.probes+combat.refract.fragments:
			if flight.armed:
				threats.append(flight.position)
				danger_distance = minf(danger_distance,position.distance_to(flight.position))
	var direction: Vector2 = policy.choose_direction(position,goal,threats,func(point):
		return chapter.map.layout.is_position_walkable(point,chapter.player.get_body_radius())
	)
	return {"direction":direction,"dash":danger_distance<100}
