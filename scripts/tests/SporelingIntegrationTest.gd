extends SceneTree
const EnemySource = preload("res://scripts/actors/Enemy.gd")
class Target extends Node2D:
	var stealth_active := false
	func is_stealthed() -> bool:
		return stealth_active
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: SporelingIntegrationTest " + label)
func _initialize() -> void:
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(300,0)
	arena.add_child(target)
	var projectiles := Node2D.new()
	arena.add_child(projectiles)
	var enemy = EnemySource.new()
	enemy.setup(EnemySource.EnemyKind.SPITTER,0,projectiles,target)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	var view = enemy.native_visual
	check(view != null and enemy.static_visual == null, "actual SPITTER still draws old raster")
	if view == null:
		arena.free()
		quit(1)
		return
	check(view.scene_file_path.ends_with("sporeling_paper_v1.tscn") and view.skeleton.get_bone_count() == 14, "wrong native actor")
	check(enemy.body_radius == 14 and enemy.contact_damage == 15 and enemy.speed == enemy.RANGED_ENEMY_SPEED and enemy.health.max_health == 28, "art changed balance")
	check(enemy.should_show_health_bar() and not enemy.should_show_status_marker(), "small enemy bar missing")
	check(enemy.get_health_bar_rect().end.y < -56 and enemy.get_attack_marker_top() + 2 < enemy.get_health_bar_rect().position.y, "bar and exclamation overlap cap")
	enemy.velocity = Vector2(100,0)
	enemy._update_static_motion(0.12)
	check(view.player.current_animation == "walk", "spore gait absent")
	enemy.ranged_is_winding_up = true
	enemy.ranged_windup_remaining = 0.09
	enemy._update_static_motion(0)
	check(view.player.current_animation == "warning" and is_equal_approx(view.player.current_animation_position, 0.09), "short warning not combat-clock bound")
	check(enemy.should_show_attack_marker() and not view.get_node("Warning").visible, "duplicate or missing head marker")
	check(projectiles.get_child_count() == 0, "warning pose emitted projectile")
	enemy.ranged_target_position = target.position
	enemy._update_spitter(0.10,target)
	enemy._update_static_motion(0)
	check(projectiles.get_child_count() == 1 and view.player.current_animation == "attack", "real emission has no spit recoil or duplicated shot")
	var shot = projectiles.get_child(0)
	check(shot.velocity == Vector2(260,0) and shot.damage == 21 and shot.radius == 5 and shot.lifetime == 6, "animation altered projectile contract")
	shot.set_physics_process(false)
	enemy._update_static_motion(0.25)
	check(view.player.current_animation == "walk", "spit recoil never returns to gait")
	enemy.velocity = Vector2.ZERO
	enemy.take_damage(1)
	check(view.player.current_animation == "hit", "real damage has no new hit pose")
	enemy._update_static_motion(0.17)
	check(view.player.current_animation == "idle", "hit pose never returns")
	enemy.ranged_is_winding_up = true
	enemy.ranged_windup_remaining = 0.18
	target.stealth_active = true
	enemy._physics_process(0.02)
	check(view.player.current_animation != "warning" and projectiles.get_child_count() == 1, "hidden target leaves visible attack / emits")
	target.stealth_active = false
	enemy.ranged_is_winding_up = false
	enemy._update_enemy_facing(Vector2(-100,0))
	check(view.get_node("Facing").scale.x == -1 and enemy.rotation == 0, "enemy does not mirror toward player")
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(pose), "paused native body advances")
	paused = false
	var at: Transform2D = view.global_transform
	enemy.take_damage(1000)
	check(enemy.death_resolved and enemy.is_queued_for_deletion() and view.get_parent() == arena and view.global_transform.is_equal_approx(at), "death delays removal or teleports body")
	check(view.player.current_animation == "death" and not view.cancel_action() and not view.is_in_group("enemies"), "dead ghost attacks or revives")
	view.player.advance(0.5)
	await process_frame
	check(not is_instance_valid(view), "new death resource leaks")
	arena.free()
	await process_frame
	if failures == 0:
		print("TEST PASS: SporelingIntegrationTest %d" % checks)
	quit(1 if failures else 0)
