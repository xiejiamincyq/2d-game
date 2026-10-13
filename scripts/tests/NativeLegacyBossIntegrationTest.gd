extends SceneTree
## Both production actors; explicit clock/damage fixture, not natural input.
## No author-only resource preloads; also runnable against an isolated PCK.
const BossSource = preload("res://scripts/actors/OverseerBoss.gd")
const NurserySource = preload("res://scripts/actors/NurseryVineBoss.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativeLegacyBossIntegrationTest "+label)
func _initialize() -> void:
	await process_frame
	for source in [BossSource,NurserySource]:
		await _check_actor(source)
	if not failures:
		print("TEST PASS: NativeLegacyBossIntegrationTest %d" % checks)
	quit(1 if failures else 0)
func _check_actor(source: Script) -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var shots := Node2D.new()
	arena.add_child(shots)
	var target := Node2D.new()
	target.position = Vector2(350,0)
	arena.add_child(target)
	var boss: CharacterBody2D = source.new()
	boss.setup(5,shots,target)
	boss.position = Vector2(30,40)
	arena.add_child(boss)
	boss.set_physics_process(false)
	var view = boss.get_visual_node()
	check(view!=null and view.has_node("Facing/Skeleton2D"),"actual Boss still uses raster instead of a native skeleton")
	if view==null or not view.has_node("Facing/Skeleton2D"):
		arena.free()
		await process_frame
		return
	var expected_bones := 23 if source==BossSource else 22
	check(view.skeleton.get_bone_count()==expected_bones,"inherited Boss rig drift")
	if source==BossSource:
		var visual_box: Rect2 = view.transform*boss.get_visual_rect()
		check(visual_box.size.y<=180 and is_zero_approx(visual_box.get_center().y),"new Boss silhouette exceeds camera budget or has a drifting vertical anchor")
	var expected_clips := 21 if source==BossSource else 14
	check(view.player.get_animation_list().size()==expected_clips and not view.player.has_animation("attack"),"legacy twenty-one/chapter fourteen motion contract changed")
	if source==BossSource:
		check(view.scene_file_path=="res://scenes/actors/native/root_overseer_paper_v1.tscn","legacy Boss has no independent action resource")
	if source==NurserySource:
		check(view.scene_file_path=="res://scenes/actors/native/vine_guard_paper_v2.tscn" and boss.get_tentacle_attack()==null and boss.get_attack_director().get_script().resource_path=="res://scripts/components/VineGuardAttackDirector.gd","new Boss still uses old actor/controllers")
	var body_at := boss.global_transform
	var view_at: Transform2D = view.transform
	check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1,"entrance modifies physical root/opacity")
	var collision: CircleShape2D
	for child in boss.get_children():
		if child is CollisionShape2D:
			collision = child.shape
	check(collision!=null and collision.radius==56 and boss.health.max_health==10800,"native migration changes health/hitbox")
	var entrance_count := [0]
	var death_count := [0]
	boss.entrance_finished.connect(func(): entrance_count[0]+=1)
	boss.died.connect(func(_actor: Node,_coins: int,_source: StringName): death_count[0]+=1)
	var health_before: float = boss.health.current_health
	boss.take_damage(100)
	check(boss.health.current_health==health_before,"entrance immunity lost")
	var torso_before: Transform2D = view.skeleton.get_bone(0).transform
	boss._physics_process(0.7)
	check(view.player.current_animation=="entrance" and not view.skeleton.get_bone(0).transform.is_equal_approx(torso_before),"entrance lacks articulated movement")
	check(boss.global_transform.is_equal_approx(body_at) and boss.modulate.a==1,"entrance displaces collision or fades entire actor")
	check(entrance_count[0]==0 and shots.get_child_count()==0,"entrance starts combat too early")
	boss._physics_process(0.71)
	check(boss.entrance_resolved and entrance_count[0]==1 and boss.process_mode==Node.PROCESS_MODE_PAUSABLE,"entrance did not finish exactly once")
	check(boss.get_attack_director().get_state_name()=="PHASE_1","native reveal changes director timing")
	body_at = boss.global_transform
	boss.velocity = Vector2(100,0)
	boss._update_boss_motion(0.26)
	check(view.player.current_animation=="walk" and absf(view.skeleton.get_node("Torso/LegR/ShinR").rotation)>0.02,"Boss lacks native shin gait")
	check(boss.global_transform.is_equal_approx(body_at),"gait moves physical root")
	boss._update_visual_facing(boss.global_position+Vector2(-100,0))
	check(view.get_node("Facing").scale.x==-1 and boss.rotation==0,"Boss rotates whole body instead of mirroring")
	check(boss.get_visual_rect().is_equal_approx(view.get_node("Facing").transform*view.body_rect),"camera bounds ignore asymmetric mirrored skin")
	boss.take_damage(1)
	check(view.player.current_animation=="hit" and boss.health.current_health==health_before-1,"actual damage lacks native recoil")
	check(view.get_node("Facing/Skin").material==boss.boss_flash_material,"flash shader not attached to skin")
	boss.velocity = Vector2.ZERO
	boss._update_boss_motion(0.3)
	check(view.player.current_animation=="idle" and view.transform.is_equal_approx(view_at),"recoil does not settle without moving visual anchor")
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(pose),"paused native Boss moves")
	paused = false
	var corpse_at: Transform2D = view.global_transform
	boss.take_damage(20000)
	check(death_count[0]==1 and boss.death_resolved and boss.get_attack_director().get_state_name()=="DEATH","native death changes combat shutdown")
	check(view.get_parent()==arena and view.global_transform.is_equal_approx(corpse_at) and view.player.current_animation=="death","native corpse detachment drifts")
	check(float(boss.boss_flash_material.get_shader_parameter("flash_amount"))==0,"corpse retains lethal white flash")
	boss.take_damage(1)
	check(death_count[0]==1,"native death resolves twice")
	view.player.advance(1.4)
	await process_frame
	check(not is_instance_valid(view) and not is_instance_valid(boss),"native corpse/actor leaks")
	arena.free()
	await process_frame
