extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
class Target extends Node2D:
	var stealthed := false
	var hits := 0
	func is_stealthed() -> bool:
		return stealthed
	func take_damage(_amount: float) -> bool:
		hits += 1
		return true

var assertions := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: EnemyNativeIntegrationTest " + label)

func _initialize() -> void:
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(50, 0)
	arena.add_child(target)
	var enemy := EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.SCRAPPER, 0, arena, target)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	var view = enemy.get_node_or_null("NativeVisual")
	check(view != null and enemy.static_visual == null, "scrapper still uses old raster rather than native actor")
	if view == null:
		arena.free()
		quit(1)
		return
	check(view.skeleton.get_bone_count() == 12, "real editable skeleton absent")
	check(view.player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "visual clock races combat")
	check(enemy.body_radius == 14 and enemy.contact_damage == 24 and enemy.speed == enemy.MELEE_ENEMY_SPEED, "native integration changed balance")
	var shape: CollisionShape2D = enemy.find_children("*", "CollisionShape2D", true, false)[0]
	check(shape.shape.radius == 14, "native integration changed collision")
	check(enemy.get_health_bar_rect().end.y <= -58 and enemy.get_attack_marker_top() + 1.5 < enemy.get_health_bar_rect().position.y, "bar/warning intersects tall leaf crest")
	check(not enemy.should_show_status_marker(), "native actor receives placeholder strip")
	enemy.velocity = Vector2(100, 0)
	enemy._update_static_motion(0.1)
	check(view.player.current_animation == "walk", "moving chaser has no native gait")
	var before: float = view.player.current_animation_position
	enemy._update_static_motion(0.1)
	check(view.player.current_animation_position > before, "gait restarts each tick")
	enemy.velocity = Vector2.ZERO
	enemy._update_static_motion(0.01)
	check(view.player.current_animation == "idle", "idle never returns")
	var attack = enemy.basic_attack
	for move in [attack.Move.CLAW, attack.Move.POUNCE]:
		check(attack.begin(enemy, target, move), "native strike rejected")
		attack.advance(attack.get_warning_duration() * 0.5)
		enemy._update_static_motion(0.02)
		check(view.player.current_animation == "warning" and enemy.should_show_attack_marker(), "authoritative warning not represented")
		check(not view.get_node("Warning").visible, "two separate head exclamation markers")
		check(is_equal_approx(view.player.current_animation_position, view.player.get_animation("warning").length * 0.5), "warning visual uses independent duration")
		check(target.hits == 0, "sampling warning deals damage")
		attack.advance(attack.get_warning_duration() * 0.5 + 0.001)
		enemy._update_static_motion(0.01)
		check(view.player.current_animation == "attack" and not enemy.should_show_attack_marker(), "active state looks like warning")
		attack.advance(attack.get_active_duration())
		enemy._update_static_motion(0.01)
		check(view.player.current_animation == "attack" and view.player.current_animation_position > 0.24, "recovery not mapped to pose return")
		attack.cancel()
		enemy.velocity = Vector2.ZERO
		enemy._update_static_motion(0)
		check(view.player.current_animation == "idle" and not enemy.should_show_attack_marker(), "cancel leaves stale attack/marker")
	enemy._update_enemy_facing(Vector2(-100, 0))
	check(view.get_node("Facing").scale.x == -1 and view.rotation == 0, "native actor rotates/orbits rather than mirrors")
	var hp: float = enemy.health.current_health
	enemy.take_damage(1)
	check(enemy.health.current_health == hp - 1 and view.player.current_animation == "hit", "accepted damage lacks native recoil")
	var hit_pose: float = view.player.current_animation_position
	enemy.take_damage(0)
	check(view.player.current_animation_position == hit_pose, "rejected damage restarts pose")
	enemy._update_static_motion(0.17)
	check(view.player.current_animation == "idle", "hit pose fails to expire")
	attack.begin(enemy, target, attack.Move.CLAW)
	target.stealthed = true
	enemy._physics_process(0)
	check(not attack.is_active() and view.player.current_animation != "warning", "hidden target leaves native warning active")
	enemy.take_damage(1)
	enemy._physics_process(0.081)
	check(is_zero_approx(enemy.flash_timer) and is_zero_approx(float(enemy.static_flash_material.get_shader_parameter("flash_amount"))), "hidden target traps native hit flash")
	var pause_pose: float = view.player.current_animation_position
	paused = true
	for frame in 3:
		await process_frame
	check(view.player.current_animation_position == pause_pose, "native pose advances while paused")
	paused = false
	var died := [0]
	enemy.died.connect(func(_actor: Node, _coins: int, _source: StringName): died[0] += 1)
	var at: Transform2D = view.global_transform
	enemy.take_damage(enemy.health.current_health)
	check(died[0] == 1 and enemy.death_resolved and enemy.is_queued_for_deletion(), "death delays gameplay removal")
	check(view.get_parent() == arena and view.global_transform.is_equal_approx(at), "death pose missing or jumps on detach")
	check(view.player.current_animation == "death" and not view.is_in_group("enemies"), "dead visual remains an enemy")
	check(view.find_children("*", "CollisionObject2D", true, false).is_empty(), "dead visual blocks/shoots")
	check(not view.get_node("Warning").visible, "death keeps head warning")
	paused = true
	for frame in 3:
		await process_frame
	check(is_instance_valid(view) and view.player.current_animation_position == 0, "death visual ignores pause")
	paused = false
	view.player.advance(0.43)
	await process_frame
	check(not is_instance_valid(enemy) and not is_instance_valid(view), "completed death visual leaks")
	arena.free()
	await process_frame
	if not failures:
		print("TEST PASS: EnemyNativeIntegrationTest %d" % assertions)
	quit(0 if not failures else 1)
