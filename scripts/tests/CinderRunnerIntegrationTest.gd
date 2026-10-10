extends SceneTree
const EnemySource = preload("res://scripts/actors/Enemy.gd")
class Target extends Node2D:
	var stealth_active := false
	var hits := 0
	var received := 0.0
	func is_stealthed() -> bool:
		return stealth_active
	func take_damage(amount: float) -> void:
		hits += 1
		received += amount
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CinderRunnerIntegrationTest " + label)
func _initialize() -> void:
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(300,0)
	arena.add_child(target)
	var enemy = EnemySource.new()
	enemy.setup(EnemySource.EnemyKind.DASHER,0,arena,target)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	var view = enemy.native_visual
	check(view != null and enemy.static_visual == null, "actual DASHER still raster")
	if view == null:
		arena.free()
		quit(1)
		return
	check(view.scene_file_path.ends_with("cinder_runner_paper_v1.tscn") and view.skeleton.get_bone_count() == 15, "incorrect resource")
	check(enemy.health.max_health == 22 and enemy.contact_damage == 18 and enemy.body_radius == 14 and enemy.speed == enemy.DASHER_ENEMY_SPEED, "art alters gameplay stats")
	check(enemy.should_show_health_bar() and not enemy.should_show_status_marker(), "missing bar / placeholder")
	check(enemy.get_health_bar_rect().end.y < -43 and enemy.get_attack_marker_top()+2 < enemy.get_health_bar_rect().position.y, "bar/marker overlaps mask")
	enemy.velocity = Vector2(120,0)
	var root_at: Transform2D = enemy.transform
	enemy._update_static_motion(0.12)
	check(view.player.current_animation == "walk" and view.skeleton.get_node("Torso/LegL/ShinL").rotation != 0, "no real spring-shin stride")
	check(view.position == Vector2.ZERO and enemy.transform.is_equal_approx(root_at), "visual shifts collision root")
	target.position = Vector2(28,0)
	enemy._update_melee_attack(0.09,target,28)
	enemy._update_static_motion(0)
	check(enemy.should_show_attack_marker() and not view.get_node("Warning").visible, "not one short head marker")
	check(view.player.current_animation == "warning" and is_equal_approx(view.player.current_animation_position,0.09), "warning not melee-clock bound")
	check(target.hits == 0, "warning already damages")
	enemy._update_melee_attack(0.10,target,28)
	enemy._update_static_motion(0)
	check(view.player.current_animation == "attack" and target.hits == 1 and target.received == 18, "real melee not bound / changed damage")
	enemy._update_melee_attack(0.05,target,28)
	enemy._update_static_motion(0)
	check(target.hits == 1, "visual doubles damage")
	enemy._update_melee_attack(0.15,target,28)
	enemy._update_static_motion(0)
	check(not enemy.is_attacking and view.player.current_animation == "walk", "no recovery to gait")
	enemy.velocity = Vector2.ZERO
	enemy.take_damage(1)
	check(view.player.current_animation == "hit", "no real new hit motion")
	enemy._update_static_motion(0.17)
	check(view.player.current_animation == "idle", "hit never releases")
	enemy.is_attacking = true
	enemy.attack_timer = 0.1
	target.stealth_active = true
	enemy._update_static_motion(0)
	check(view.player.current_animation != "warning" and not enemy.should_show_attack_marker(), "hidden target leaves attack pose")
	target.stealth_active = false
	enemy.is_attacking = false
	enemy.spawn_impulse_remaining = 0.1
	enemy._update_static_motion(0)
	check(view.player.current_animation not in ["warning","attack"], "spawn impulse leaves attack pose")
	enemy.spawn_impulse_remaining = 0
	enemy._update_enemy_facing(Vector2(-100,0))
	check(view.get_node("Facing").scale.x == -1 and enemy.rotation == 0, "wrong mirror / spinning root")
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(pose), "pause moves bones")
	paused = false
	var at: Transform2D = view.global_transform
	enemy.take_damage(1000)
	check(enemy.death_resolved and enemy.is_queued_for_deletion() and view.get_parent() == arena and view.global_transform.is_equal_approx(at), "death delays damage / teleports")
	check(view.player.current_animation == "death" and not view.cancel_action(), "death body resumes attack")
	view.player.advance(0.6)
	await process_frame
	check(not is_instance_valid(view), "death leaks")
	arena.free()
	await process_frame
	if not failures:
		print("TEST PASS: CinderRunnerIntegrationTest %d" % checks)
	quit(1 if failures else 0)
