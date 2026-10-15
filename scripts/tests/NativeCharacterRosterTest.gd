extends SceneTree
## Coverage audit, not a chapter-readiness or combat-completion claim.
const EnemySource = preload("res://scripts/actors/Enemy.gd")
const PlayerSource = preload("res://scripts/actors/Player.gd")
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const Catalog = preload("res://scripts/systems/ChapterCatalog.gd")
const WaveSource = preload("res://scripts/tests/fixtures/LegacyWaveDirector.gd")
const BossSource = preload("res://scripts/actors/OverseerBoss.gd")
const NurserySource = preload("res://scripts/actors/NurseryVineBoss.gd")
const FurnaceSource = preload("res://scripts/actors/FoundryFurnaceBoss.gd")
const TideSource = preload("res://scripts/actors/SaltTideBoss.gd")
const ArchiveSource = preload("res://scripts/actors/ArchiveArchivistBoss.gd")
const Motion = preload("res://scripts/components/NativeBossMotion.gd")
const NPCS := [
	["rootling_paper_v3",12,"ordinary"],["sporeling_paper_v1",14,"ordinary"],
	["cinder_runner_paper_v2",15,"ordinary"],["salt_needler_paper_v1",16,"ordinary"],
	["folio_lobber_paper_v1",16,"ordinary"],["stone_carrier_paper_v2",17,"large"],
	["root_commander_paper_v2",23,"large"],["root_commander_paper_v1",23,"large"], # Retain frozen baseline coverage.
	["root_overseer_paper_v1",23,"boss"], # Actual standalone Actor's independent action rig.
	["ember_spark_paper_v1",16,"ordinary"],
	["flanking_crab_paper_v1",20,"ordinary"],["splitting_mote_paper_v1",16,"ordinary"],
	["capsule_planter_paper_v1",20,"ordinary"],["echo_sentinel_paper_v1",20,"ordinary"],
	["circling_shade_paper_v1",18,"ordinary"],["rift_elite_paper_v1",20,"ordinary"],
	["space_cutter_paper_v1",19,"ordinary"],["vine_guard_paper_v2",22,"boss"],
	["furnace_foreman_paper_v2",23,"boss"],["tide_shell_paper_v1",25,"boss"],
	["tide_shell_paper_v2",25,"boss"], # Actual Salt Actor now uses v2; v1 remains audited.
	["spore_archivist_paper_v1",27,"boss"],["spore_archivist_paper_v2",27,"boss"],["bell_priest_paper_v1",26,"boss"],
	["rift_observer_paper_v1",30,"boss"]
]
const KINDS := ["rootling_paper_v3","cinder_runner_paper_v2","sporeling_paper_v1","stone_carrier_paper_v2","salt_needler_paper_v1","folio_lobber_paper_v1","root_commander_paper_v2"]
const ROLES := {"root_pursuer":"rootling_paper_v3","spore_spitter":"sporeling_paper_v1","slag_charger":"cinder_runner_paper_v2","spark_gunner":"ember_spark_paper_v1","flanking_crab":"flanking_crab_paper_v1","salt_needle":"salt_needler_paper_v1","capsule_planter":"capsule_planter_paper_v1","splitting_mote":"splitting_mote_paper_v1","echo_sentinel":"echo_sentinel_paper_v1","circling_shade":"circling_shade_paper_v1","rift_elite":"rift_elite_paper_v1","space_cutter":"space_cutter_paper_v1"}
class PlannedDriver extends CharacterBody2D:
	var entrance_resolved := false
	var entrance_progress := 0.5
var assertions := 0
var failures := 0
func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativeCharacterRosterTest "+message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var player = PlayerSource.new()
	player.position = Vector2(500,500)
	player.projectile_parent = host
	host.add_child(player)
	player.set_physics_process(false)
	check(EnemySource.EnemyKind.size()==KINDS.size(),"new base kind not covered")
	for kind in KINDS.size():
		var actor = EnemySource.new()
		actor.setup(kind,0,host,player)
		host.add_child(actor)
		actor.set_physics_process(false)
		_check_actual(actor,KINDS[kind])
		check(kind==EnemySource.EnemyKind.BRUISER or actor.should_show_health_bar(),"healthy enemy has no persistent bar")
		actor.free()
	var role_count := 0
	for chapter in range(1,Catalog.CHAPTER_COUNT+1):
		for role in Catalog.get_chapter(chapter).enemy_roles:
			role_count += 1
			check(ROLES.has(role),"planned role missing audit "+role)
			var actor = Factory.create_actor(chapter,role,0,host,player)
			check(actor!=null,"factory role not implemented "+role)
			if actor==null: continue
			host.add_child(actor)
			actor.set_physics_process(false)
			_check_actual(actor,ROLES.get(role,""))
			check(actor.should_show_health_bar(),"regional enemy has no healthy bar")
			actor.free()
	check(role_count==12 and ROLES.size()==12,"regional coverage is not six pairs")
	for source in [BossSource,NurserySource,FurnaceSource,TideSource,ArchiveSource]:
		var actor = source.new()
		actor.setup(5,host,player)
		host.add_child(actor)
		actor.set_physics_process(false)
		_check_actual(actor,"root_overseer_paper_v1" if source==BossSource else "vine_guard_paper_v2" if source==NurserySource else "furnace_foreman_paper_v2" if source==FurnaceSource else "tide_shell_paper_v2" if source==TideSource else "spore_archivist_paper_v2")
		actor.free()
	# Exercise the production wave spawner and its real Boss reinforcement path.
	var director = WaveSource.new()
	director.enemy_parent = host
	director.projectile_parent = host
	director.portal_parent = host
	director.player = player
	director.world_bounds = Rect2(-2000,-2000,4000,4000)
	host.add_child(director)
	director.set_process(false)
	director.set_physics_process(false)
	for kind in KINDS.size(): director._spawn_enemy_at(kind,Vector2(kind*90,-300))
	check(director.active_enemies.size()==7,"production wave source lacks all base entries")
	for index in mini(7,director.active_enemies.size()): _check_actual(director.active_enemies[index],KINDS[index])
	director.active_boss = BossSource.new()
	director.active_boss.setup(5,host,player)
	host.add_child(director.active_boss)
	director.active_boss.set_physics_process(false)
	var before: int = director.active_enemies.size()
	director._on_boss_reinforcements_requested(director.active_boss,2)
	check(director.active_portals.size()==2,"reinforcement portals absent")
	for portal in director.active_portals: portal.set_process(false)
	director._process_portal_attack(1.5)
	check(director.active_enemies.size()==before+2,"actual reinforcements not produced")
	for index in range(before,director.active_enemies.size()):
		var actor = director.active_enemies[index]
		_check_actual(actor,KINDS[actor.kind])
	# Real deferred offspring, not a manually instantiated duplicate.
	var mother = Factory.create_actor(4,"splitting_mote",0,host,player)
	mother.position = Vector2(-500,500)
	mother.world_bounds = Rect2(-2000,-2000,4000,4000)
	host.add_child(mother)
	mother.set_physics_process(false)
	var children: Array[CharacterBody2D] = []
	mother.offspring_prepared.connect(func(values): children.assign(values))
	mother.take_damage(1000)
	await process_frame
	await process_frame
	check(children.size()==2,"real split children absent")
	for child in children:
		child.set_physics_process(false)
		_check_actual(child,"splitting_mote_paper_v1")
		check(child.is_fragment and child.get_visual_node().scale.is_equal_approx(Vector2.ONE*0.62),"fragment uses legacy/wrong body")
	check(player.get_visual_node().scene_file_path=="res://scenes/actors/native/player_paper_v1.tscn","actual player body missing")
	player.drone_count = 2
	player._sync_drone_visuals()
	for drone in player.drone_visuals:
		check(drone.get_visual_node().scene_file_path=="res://scenes/actors/native/ranger_drone_paper_v1.tscn","actual companion body missing")
	host.free()
	await process_frame
	# Six planned Boss resources remain separately classed as resources only.
	for entry in NPCS:
		await _check_resource(entry)
	if failures==0: print("TEST PASS: NativeCharacterRosterTest %d; 7 kinds/12 roles/production summons and split/5 actual Bosses/6 chapter Boss resources/player and companion"%assertions)
	quit(1 if failures else 0)
func _check_actual(actor: Node,stem: String) -> void:
	var view = actor.get_visual_node()
	check(view!=null and view.scene_file_path=="res://scenes/actors/native/"+stem+".tscn","production body mismatch "+stem)
	if view==null: return
	check(view.has_node("Facing/Skeleton2D") and view.get_node("Facing/Skin").texture==null,"production raster fallback "+stem)
	var at: Transform2D = actor.global_transform
	view.sample_clip("walk",0.2)
	check(actor.global_transform.is_equal_approx(at),"native motion moves physical root "+stem)
func _check_resource(entry: Array) -> void:
	var scene: String = "res://scenes/actors/native/"+entry[0]+".tscn"
	check(ResourceLoader.exists(scene),"required resource missing "+scene)
	if not ResourceLoader.exists(scene): return
	var packed := load(scene) as PackedScene
	var view = packed.instantiate()
	root.add_child(view)
	var rig: Skeleton2D = view.get_node("Facing/Skeleton2D")
	var skin: Polygon2D = view.get_node("Facing/Skin")
	check(rig.get_bone_count()==entry[1] and skin.get_bone_count()==entry[1],"resource bone coverage "+entry[0])
	check(skin.texture==null and skin.get_script()==null and view.get_script().resource_path=="res://scripts/components/NativeActorView.gd","author/raster dependency "+entry[0])
	var clips: Array = ["idle","walk","warning","attack","hit","death"] if entry[2]=="ordinary" else ["idle","walk","hit","entrance","death"]
	if entry[0]=="stone_carrier_paper_v2":
		clips.append_array(["slam_warning","slam_attack","slam_recovery"])
	if entry[0]=="root_commander_paper_v2":
		clips.append_array(["melee_warning","melee_attack","melee_recovery","burst_warning","burst_attack","command"])
	if entry[0]=="root_overseer_paper_v1":
		for action in ["sweep","slam","aimed_fan","twin_spiral","broken_ring"]:
			for stage in ["warning","attack","recovery"]: clips.append(action+"_"+stage)
		clips.append("phase_transition")
	if entry[0]=="vine_guard_paper_v2":
		clips.append_array(["lash_warning","lash_attack","lash_recovery","roots_warning","roots_attack","roots_recovery","seeds_warning","seeds_attack","seeds_recovery"])
	if entry[0]=="furnace_foreman_paper_v2":
		clips.append_array(["jet_warning","jet_attack","jet_recovery","ram_warning","ram_attack","ram_recovery","vents_warning","vents_attack","vents_recovery"])
	if entry[0]=="tide_shell_paper_v2":
		clips.append_array(["ripple_warning","ripple_attack","ripple_recovery","pincer_warning","pincer_attack","pincer_recovery","salt_warning","salt_attack","salt_recovery"])
	if entry[0]=="spore_archivist_paper_v2":
		clips.append_array(["page_warning","page_attack","page_recovery","seal_warning","seal_attack","seal_recovery","brood_warning","brood_attack","brood_recovery"])
	check(view.player.get_animation_library("").resource_path.begins_with("res://assets/art/actors/native/"),"external motion absent "+entry[0])
	for clip in clips:
		check(view.player.has_animation(clip),"required clip absent "+entry[0]+"/"+clip)
		if not view.player.has_animation(clip): continue
		var sample = packed.instantiate()
		root.add_child(sample)
		var skeleton: Skeleton2D = sample.get_node("Facing/Skeleton2D")
		sample.sample_clip(clip,0)
		var poses: Array[Transform2D] = []
		for index in skeleton.get_bone_count(): poses.append(skeleton.get_bone(index).transform)
		sample.sample_clip(clip,sample.player.get_animation(clip).length*0.3)
		var changed := 0
		for index in skeleton.get_bone_count(): changed += 1 if not poses[index].is_equal_approx(skeleton.get_bone(index).transform) else 0
		check(changed>=2,"motion is only whole-body wobble "+entry[0]+"/"+clip)
		sample.free()
	if entry[2] in ["large","boss"]:
		check(not view.player.has_animation("attack") and not view.player.has_animation("warning"),"new large attack exists before audit "+entry[0])
		var driver := PlannedDriver.new()
		root.add_child(driver)
		view.reparent(driver)
		var motion := Motion.new(view)
		motion.update(driver,0)
		check(view.player.current_animation=="entrance","production adapter rejects planned resource "+entry[0])
		driver.entrance_resolved = true
		driver.velocity = Vector2(80,0)
		motion.update(driver,0.2)
		check(view.player.current_animation=="walk","planned resource has no production gait "+entry[0])
		driver.free()
	else: view.free()
	await process_frame
