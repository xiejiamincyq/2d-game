extends "res://scripts/art/VerifyFoundryChapterFlow.gd"
## Reuse GPU-host/input/layout observations, not Foundry steering or actors.
var selected_route: StringName = &"supply"
func _initialize() -> void:
	var args := configure_chain_arguments(OS.get_cmdline_user_args())
	if not chain_context.valid or args.size()!=2 or not ChainEvidence.safe_id(args[0]) or args[1] not in ["supply","risk"]: quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	selected_route = StringName(args[1])
	additional_sources = [
		"scripts/art/VerifySaltChapterFlow.gd","scripts/art/VerifyFoundryChapterFlow.gd",
		"scripts/campaign/SaltChapter.gd","scenes/campaign/salt_chapter.tscn",
		"scripts/systems/ChapterEncounterDirector.gd","scripts/systems/SaltEncounterDirector.gd",
		"scripts/campaign/RegionalEnemyFactory.gd","scripts/world/SaltMap.gd",
		"scripts/world/SaltArenaLayout.gd","scripts/world/SaltTidalField.gd",
		"scripts/world/SaltTidalBand.gd","scripts/world/SaltPropArt.gd","scripts/world/SaltFloor.gd",
		"scripts/actors/FlankingCrabEnemy.gd","scripts/components/CrabPincerAttack.gd",
		"scripts/actors/SaltTideBoss.gd","scripts/components/TideShellAttackDirector.gd",
		"scripts/components/NativeTideShellMotion.gd","scripts/components/TideSaltProjectile.gd",
		"scripts/components/TideShellWaveGeometry.gd","scripts/components/NativeProjectileOriginSafety.gd",
		"scripts/components/VineSeedProjectile.gd","scripts/components/RiftShardProjectile.gd",
		"scripts/effects/EnemyWorldStatus.gd","scripts/effects/PlayerOcclusionOutline.gd",
		"scripts/systems/BossCameraFraming.gd","assets/art/actors/native/tide_shell_motion_v2.tres",
		"scenes/actors/native/tide_shell_paper_v2.tscn",
	]
	for path in additional_sources:
		check(FileAccess.file_exists("res://"+path),"missing proof source "+path)
	if failures: quit(1); return
	call_deferred("_run")
func chapter_number() -> int: return 3
func proof_marker() -> String: return "VerifySaltChapterFlow"
func prepare_progress(path: String) -> bool:
	var prerequisite := Progress.new()
	return not FileAccess.file_exists(path) and prerequisite.record_boss_defeat(1) and prerequisite.record_boss_defeat(2) and Store.new(path).save_progress(prerequisite)
func proof_scope() -> String:
	return "Actual Main -> Salt chapter in GPU SubViewport; standard engine pointer/UI/direction/fire/dash -> actual Boss clear/save/unlock4. Only isolated prerequisite clears1,2 prepared. No actor stat/direct damage/in-run reward writes. Not OS desktop mouse, human playtest, performance or six-chapter completion."
func _click(button: Button) -> void:
	var chapter = actual_scene()
	if chapter.has_method("_chapter_number") and chapter._chapter_number()==3 and button==chapter.ui.supply_button and selected_route==&"risk": button = chapter.ui.risk_button
	await super._click(button)
func additional_report() -> Dictionary:
	var report := super.additional_report()
	report.prerequisite_fixture = [1,2]; report.route = String(selected_route)
	return report
func pilot_motion(chapter: Node,policy: RefCounted,step: int,threats: Array[Vector2],_legacy: Node,danger_distance: float) -> Dictionary:
	var position: Vector2 = chapter.player.position
	var boss = chapter.director.get_active_boss()
	var goal := Vector2.RIGHT.rotated(step/180.0)
	if boss!=null:
		var offset: Vector2 = position-boss.global_position
		goal = offset.normalized().orthogonal()+offset.normalized()*clampf((410-offset.length())/80,-2,2)
	# Visible loot, never injected health/currency. Navigation avoids real pools.
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
			var offset: Vector2 = position-combat.locked_origin
			match combat.action:
				&"ripple":
					if offset.length()<100:
						goal = Vector2.ZERO; threats = threats.filter(func(point): return point.distance_to(boss.global_position)>1)
					elif offset.length()<390: goal = offset.normalized(); danger_distance = minf(danger_distance,absf(offset.length()-combat.ring_radius(combat.action_elapsed)))
				&"pincer":
					for tip: Vector2 in boss.get_claw_origins(): threats.append(tip); danger_distance = minf(danger_distance,position.distance_to(tip))
				&"salt":
					if offset.dot(combat.locked_direction)>0 and absf(offset.dot(combat.locked_direction.orthogonal()))<80:
						goal = combat.locked_direction.orthogonal(); danger_distance = 0
	var direction: Vector2 = policy.choose_direction(position,goal,threats,func(point): return chapter.map.layout.is_position_walkable(point,chapter.player.get_body_radius()))
	return {"direction":direction,"dash":danger_distance<100}
