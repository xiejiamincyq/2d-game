extends "res://scripts/art/VerifyFoundryChapterFlow.gd"
## Ordinary engine inputs against actual Archive content; no combat-state writes.
var selected_route: StringName = &"supply"
func _initialize() -> void:
	var args := configure_chain_arguments(OS.get_cmdline_user_args())
	if not chain_context.valid or args.size()!=2 or not ChainEvidence.safe_id(args[0]) or args[1] not in ["supply","risk"]: quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	selected_route = StringName(args[1])
	additional_sources = [
		"scripts/art/VerifyArchiveChapterFlow.gd","scripts/art/VerifyFoundryChapterFlow.gd",
		"scripts/campaign/ArchiveChapter.gd","scenes/campaign/archive_chapter.tscn",
		"scripts/systems/ChapterEncounterDirector.gd","scripts/systems/ArchiveEncounterDirector.gd",
		"scripts/campaign/RegionalEnemyFactory.gd","scripts/world/ArchiveMap.gd",
		"scripts/world/ArchiveArenaLayout.gd","scripts/world/ArchiveSporeField.gd",
		"scripts/world/ArchiveSporeNest.gd","scripts/world/ArchivePropArt.gd","scripts/world/ArchiveFloor.gd",
		"scripts/actors/ArchiveArchivistBoss.gd","scripts/actors/SplittingMoteEnemy.gd",
		"scripts/actors/CapsulePlanterEnemy.gd","scripts/components/SporeArchivistAttackDirector.gd",
		"scripts/components/ArchivePageProjectile.gd","scripts/components/ArchiveSealAttack.gd",
		"scripts/components/NativeProjectileOriginSafety.gd","scripts/components/VineSeedProjectile.gd",
		"scripts/effects/EnemyWorldStatus.gd","scripts/effects/PlayerOcclusionOutline.gd",
		"scripts/systems/BossCameraFraming.gd","assets/art/actors/native/spore_archivist_motion_v2.tres",
		"scenes/actors/native/spore_archivist_paper_v2.tscn",
	]
	for path in additional_sources: check(FileAccess.file_exists("res://"+path),"missing proof source "+path)
	if failures: quit(1); return
	call_deferred("_run")
func chapter_number() -> int: return 4
func proof_marker() -> String: return "VerifyArchiveChapterFlow"
func prepare_progress(path: String) -> bool:
	var prerequisite := Progress.new()
	return not FileAccess.file_exists(path) and prerequisite.record_boss_defeat(1) and prerequisite.record_boss_defeat(2) and prerequisite.record_boss_defeat(3) and Store.new(path).save_progress(prerequisite)
func proof_scope() -> String:
	return "Actual Main -> Archive in GPU SubViewport; ordinary engine UI/pointer/movement/fire/dash -> real Boss clear/save/unlock5. Isolated prerequisites1,2,3 prepared before run. No actor stats/direct damage/in-run reward writes. Not OS desktop input, human playtest, performance or six-chapter acceptance."
func _click(button: Button) -> void:
	var chapter = actual_scene()
	if chapter.has_method("_chapter_number") and chapter._chapter_number()==4 and button==chapter.ui.supply_button and selected_route==&"risk": button = chapter.ui.risk_button
	await super._click(button)
func additional_report() -> Dictionary:
	var report := super.additional_report()
	report.prerequisite_fixture = [1,2,3]; report.route = String(selected_route)
	return report
func pilot_motion(chapter: Node,policy: RefCounted,step: int,threats: Array[Vector2],_legacy: Node,danger_distance: float) -> Dictionary:
	var position: Vector2 = chapter.player.position
	var boss = chapter.director.get_active_boss()
	var goal := Vector2.RIGHT.rotated(step/180.0)
	if boss!=null:
		var offset: Vector2 = position-boss.global_position
		goal = offset.normalized().orthogonal()+offset.normalized()*clampf((380-offset.length())/80,-2,2)
	var loot: Node2D = null; var closest := INF
	for item: Node2D in chapter.pickups.get_children():
		if item.is_queued_for_deletion(): continue
		var script: String = item.get_script().resource_path
		var wanted: bool = chapter.director.state==chapter.director.State.COLLECT or (script.ends_with("HeartPickup.gd") and chapter.player.health.current_health<80) or (script.ends_with("ShieldPickup.gd") and chapter.player.shield<chapter.player.max_shield)
		var distance := position.distance_squared_to(item.position)
		if wanted and distance<closest: closest = distance; loot = item
	if loot!=null: goal = chapter.map.layout.get_navigation_direction(position,loot.position,chapter.player.get_body_radius())
	# Actual reusable pressure plates are observed once by the common driver.
	if boss!=null:
		var combat = boss.attack_director
		if combat.action_stage in [combat.Stage.WARNING,combat.Stage.ACTIVE]:
			if combat.action==&"seal":
				for center: Vector2 in combat.seal_attack.centers:
					threats.append(center); danger_distance = minf(danger_distance,position.distance_to(center))
			elif combat.action==&"page":
				var offset: Vector2 = position-combat.locked_origin
				if offset.dot(combat.locked_direction)>0 and absf(offset.dot(combat.locked_direction.orthogonal()))<60:
					goal = combat.locked_direction.orthogonal(); danger_distance = 0
	var direction: Vector2 = policy.choose_direction(position,goal,threats,func(point): return chapter.map.layout.is_position_walkable(point,chapter.player.get_body_radius()))
	return {"direction":direction,"dash":danger_distance<100}
