extends "res://scripts/art/VerifyNativePlayerChapter.gd"
## Fresh first chapter, ordinary production UI/movement/fire and real loot.
## Initial RNG seed is recorded separately from the actual generated map seed.
var family := "ballistics"
var build_route: StringName = &"supply"
var initial_rng_seed := 0
var reward_decisions: Array[Dictionary] = []
var finale_captured := false
var build_source_bank := {}
var aim_mode := "direct"
var compensated_frames := 0
var build_view: SubViewport
var pointer_injections := 0
var last_pointer := Vector2.ZERO
var shot_observations: Array[Dictionary] = []
var explosion_observations: Array[Dictionary] = []
var actual_shots := 0
var actual_grenades := 0
var actual_explosions := 0
var maximum_pointer_error := 0.0
const AimPolicy = preload("res://scripts/art/DiagnosticProjectileAim.gd")
const PlayerContract = preload("res://scripts/actors/Player.gd")
const GrenadeContract = preload("res://scripts/components/GrenadeProjectile.gd")
const EVOLUTION_IDS := {"ballistics":"orbital_storm","mobility":"rift_overdrive","automation":"thunder_matrix"}

static func choose_offer_index(offers: Array, selected_family: String, claimed: bool, counts: Dictionary) -> int:
	var selected := -1
	var best_score := -1
	for index in offers.size():
		var offer: Dictionary = offers[index]
		if offer.get("family", "") != selected_family or not offer.get("affordable" if claimed else "free_available", false):
			continue
		var id := String(offer.get("id", ""))
		var score := 10
		if id == String(EVOLUTION_IDS.get(selected_family, "")):
			score = 200
		elif id in ["mine", "drone", "arc"] and int(counts.get(id, 0)) == 0:
			score = 100 if id in ["mine", "drone"] else 90
		if score > best_score:
			selected = index
			best_score = score
	return selected

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() not in [4,5] or not ChainEvidence.safe_id(args[0]) or args[1] not in EVOLUTION_IDS or args[2] not in ["supply","risk"] or not args[3].is_valid_int():
		quit(1); return
	if args.size() == 5:
		if args[4] not in ["direct","compensated"]: quit(1); return
		aim_mode = args[4]
	initial_rng_seed = int(args[3])
	if initial_rng_seed < 0 or initial_rng_seed > 2147483647: quit(1); return
	family = args[1]
	build_route = StringName(args[2])
	output = ChainEvidence.EVIDENCE_ROOT + args[0] + "/"
	chain_context = ChainEvidence.parse_arguments(PackedStringArray(),1)
	additional_sources = ["scripts/art/VerifyChapterBuildRun.gd","scripts/art/DiagnosticProjectileAim.gd","scripts/art/VerifyNativePlayerChapter.gd","scripts/ui/SettlementScreen.gd","scripts/systems/ChapterEncounterDirector.gd"]
	call_deferred("_run")

func prepare_campaign_progress(path: String) -> bool:
	build_source_bank = ChainEvidence.build_source_bank()
	return not build_source_bank.is_empty() and not FileAccess.file_exists(path)

func prepare_scene_host() -> void:
	# Same production scene/physics, isolated engine pointer coordinates. Reuses
	# the existing Foundry driver's host pattern, not OS focus or actor aim writes.
	build_view = SubViewport.new()
	build_view.size = Vector2i(1280,720)
	build_view.world_2d = World2D.new()
	build_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(build_view)
	current_scene = build_view
	var display := TextureRect.new()
	display.texture = build_view.get_texture()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(display)

func scene_host() -> Node: return build_view
func actual_scene() -> Node: return build_view.get_child(0) if build_view != null and build_view.get_child_count() > 0 else null

func _inject_mouse(view: Viewport, point: Vector2) -> void:
	super._inject_mouse(view,point)
	last_pointer = point
	pointer_injections += 1
	check(view == build_view and view.get_mouse_position().distance_to(point)<0.001,"actual build viewport cursor differs from pointer input")

func prepare_layout_capture(chapter: Node) -> void:
	chapter.player.fired.connect(func(shot: Node) -> void: _observe_build_shot(chapter,shot))

static func vector_xy(value: Vector2) -> Array: return [value.x,value.y]

func _observe_build_shot(chapter: Node, shot: Node) -> void:
	# The production fired signal has already attached the actual projectile.
	# Only read actual coordinates/velocity; never adjust a shot after firing.
	actual_shots += 1
	var grenade := shot is GrenadeContract
	actual_grenades += 1 if grenade else 0
	var pointer_error: float = chapter.get_viewport().get_mouse_position().distance_to(last_pointer)
	maximum_pointer_error = maxf(maximum_pointer_error,pointer_error)
	check(pointer_error<0.001,"actual shot read a different viewport cursor than requested")
	if (grenade and actual_grenades<=120) or (not grenade and actual_shots<=30):
		var boss: Node2D = chapter.director.get_active_boss()
		shot_observations.append({"frame":Engine.get_physics_frames(),"grenade":grenade,"planned_screen":vector_xy(last_pointer),"pointer_error":pointer_error,"mouse_world":vector_xy(chapter.player.get_global_mouse_position()),"origin":vector_xy(shot.global_position),"velocity":vector_xy(shot.velocity),"player_velocity":vector_xy(chapter.player.velocity),"gun_angle":chapter.player.gun_angle,"facing":chapter.player.get_visual_node().facing,"boss_position":vector_xy(boss.global_position) if boss!=null else [],"boss_health":boss.health.current_health if boss!=null else null})
	if grenade:
		shot.exploded.connect(func(position: Vector2,radius: float) -> void:
			actual_explosions += 1
			if explosion_observations.size()<120:
				var boss: Node2D = chapter.director.get_active_boss()
				explosion_observations.append({"frame":Engine.get_physics_frames(),"position":vector_xy(position),"radius":radius,"boss_position":vector_xy(boss.global_position) if boss!=null else [],"boss_health_after":boss.health.current_health if boss!=null else null})
		)

func launch_campaign_entry(main: Variant) -> void:
	# Seed only RNG before normal Main pointer launch. Never alter live actors,
	# map layouts, rewards, balances or the actual newly generated chapter seed.
	seed(initial_rng_seed)
	await _click(main.ui.start_screen.start_button)

func _pick_offer(chapter: Node) -> Button:
	var screen: Control = chapter.ui.settlement_screen
	var index := choose_offer_index(screen.current_offers,family,bool(chapter.growth.get_settlement_state().reward_claimed),chapter.growth.upgrade_counts)
	return screen.offer_buttons[index] if index >= 0 else null

func aim_world_point(chapter: Node, direct_point: Vector2) -> Vector2:
	if aim_mode != "compensated":
		return direct_point
	var grenade: bool = chapter.player.active_build_evolutions.has("orbital_storm")
	# The production primary bullet inherits full velocity; grenade inherits 30%.
	# Compare builds with the same kinematic input policy, not grenade-only lead.
	var inheritance: float = PlayerContract.GRENADE_VELOCITY_INHERITANCE if grenade else 1.0
	var base_speed: float = chapter.player.projectile_speed * (PlayerContract.GRENADE_SPEED_MULTIPLIER if grenade else 1.0)
	# Read the attached muzzle only. prepare_shot would mutate production pose.
	var muzzle: Vector2 = chapter.player.get_visual_node().get_muzzle_position()
	for enemy in chapter.director.get_active_enemies():
		if not is_instance_valid(enemy) or enemy.global_position.distance_to(direct_point) > 0.1: continue
		var target_velocity: Vector2 = enemy.velocity if enemy is CharacterBody2D else Vector2.ZERO
		var r: Vector2 = direct_point - muzzle
		var relative_velocity: Vector2 = target_velocity - chapter.player.velocity * inheritance
		var solution := AimPolicy.intercept(r, relative_velocity, base_speed)
		if solution.solved:
			compensated_frames += 1
			return muzzle + solution.direction * maxf(r.length(), 100.0)
		break
	return direct_point

func _click(button: Button) -> void:
	var live: Node = actual_scene()
	var selection: Dictionary = {}
	if live != null and live.has_method("_chapter_number"):
		if button == live.ui.supply_button and build_route == &"risk": button = live.ui.risk_button
		var screen: Control = live.ui.settlement_screen
		if live.director.state == live.director.State.REWARD:
			var before: Dictionary = live.growth.get_settlement_state()
			if before.get("stage_kind") == "boss_prep" and not finale_captured:
				finale_captured = true
				await _capture(live,Engine.get_physics_frames(),"actual-boss-prep")
			var index: int = screen.offer_buttons.find(button)
			if index >= 0:
				selection = {"before":before.duplicate(true),"offer":screen.current_offers[index].duplicate(true),"was_free":not before.reward_claimed,"physics_frame":Engine.get_physics_frames()}
			if screen.offer_buttons.has(button) or button == screen.close_button:
				screen.chapter_scroll.ensure_control_visible(button)
				await process_frame
	await super._click(button)
	if not selection.is_empty():
		selection["after"] = live.growth.get_snapshot_state()
		selection["actual_player_evolutions"] = live.player.active_build_evolutions.duplicate(true)
		reward_decisions.append(selection)

func additional_report() -> Dictionary:
	var report := super.additional_report()
	var live: Node = actual_scene()
	var obtained: String = live.growth.acquired_evolution_id
	check(obtained == EVOLUTION_IDS[family] and live.player.active_build_evolutions.has(obtained),"ordinary UI choices did not acquire the intended actual evolution")
	check(ChainEvidence.source_bank_matches(build_source_bank),"source changed during ordinary build proof")
	report["build"] = {"family":family,"route":String(build_route),"initial_rng_seed":initial_rng_seed,"actual_map_seed":live.run_seed,"acquired_evolution":obtained,"qualified":obtained==EVOLUTION_IDS[family],"decisions":reward_decisions,"final_growth":live.growth.get_snapshot_state(),"source_bank":build_source_bank,"scope":"No precursor permanent-save fixture. Only initial RNG seeding before actual primary Main launch, ordinary movement/fire/dash, pickup and real pointer reward choices. No stat/gold/upgrade/health/direct-damage injection. Not human playtest or final balance; actual map seed and all offers are recorded separately."}
	report["aim"] = {"mode":aim_mode,"compensated_frames":compensated_frames,"scope":"Diagnostic pointer lead uses actual primary weapon kinematics: full inherited velocity for ordinary bullets, 30 percent and 0.48 base speed for evolved grenades, plus observed target velocity. No projectile or actor mutation. Direct mode preserves baseline. Compensation is not human aim or human balance proof."}
	report["pointer"] = {"host":"GPU SubViewport","injections":pointer_injections,"scope":"Same production Main/Chapter/physics in an isolated engine pointer host, not desktop Window mouse/focus acceptance."}
	report["projectile_observations"] = {"shots":actual_shots,"grenades":actual_grenades,"explosions":actual_explosions,"maximum_pointer_error":maximum_pointer_error,"shot_samples":shot_observations,"explosion_samples":explosion_observations,"scope":"Read-only production fired/exploded signals. Bounded first 30 ordinary shots and first 120 grenades/explosions; observed explosion geometry is not independent damage attribution or a human aim test."}
	return report

func proof_marker() -> String: return "VerifyChapterBuildRun"
