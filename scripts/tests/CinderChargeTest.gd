extends SceneTree
## Breaks caught: pursuit instead of charge, homing, delta overrun, wall tunneling,
## duplicate damage, melee stacking, hidden-target and death ghost attacks.
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
class Target extends Node2D:
	var hits: Array[float] = []
	var stealthed := false
	func take_damage(amount: float) -> void:
		hits.append(amount)
	func is_stealthed() -> bool:
		return stealthed
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CinderChargeTest " + label)
func _initialize() -> void:
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	arena.add_child(target)
	target.position = Vector2(150,0)
	var enemy := EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.DASHER,0,arena,target)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	var charge = enemy.get("charge_attack")
	check(charge != null, "ordinary dasher lacks real locked charge")
	if charge == null:
		arena.free()
		quit(1)
		return
	await physics_frame
	charge.cooldown = 0.15
	charge.tick(enemy,target,0.20)
	check(enemy.position == Vector2.ZERO and absf(charge.elapsed-0.05)<0.001, "cooldown expiry borrows time from warning")
	charge.cancel()
	enemy.position = Vector2.ZERO
	charge.cooldown = 0
	enemy._physics_process(0.10)
	check(enemy.position.is_equal_approx(Vector2.ZERO) and enemy.should_show_attack_marker(), "warning moves or lacks head marker")
	check(target.hits.is_empty() and not enemy.is_attacking, "warning damages / stacks melee")
	check(enemy.native_visual.player.current_animation == "charge_warning", "no dedicated native charge warning")
	check(charge.get_attack_strokes(enemy).is_empty(), "warning draws a noisy ground corridor")
	var paused_at: Vector2 = enemy.position
	var paused_pose: Transform2D = enemy.native_visual.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(enemy.position == paused_at and enemy.native_visual.skeleton.get_bone(0).transform.is_equal_approx(paused_pose), "pause moves charge pose/body")
	paused = false
	enemy._physics_process(charge.WARNING-charge.elapsed-0.01)
	check(enemy.position.is_equal_approx(Vector2.ZERO), "charge starts before promised warning")
	enemy._physics_process(0.02)
	check(is_equal_approx(enemy.position.x,4.4) and not enemy.should_show_attack_marker(), "cross-phase step moves more than actual active time")
	target.position = Vector2(0,150)
	enemy._physics_process(0.10)
	check(is_equal_approx(enemy.position.x,48.4) and is_zero_approx(enemy.position.y) and target.hits.is_empty(), "charge homes toward dodging target")
	check(enemy.rotation == 0 and enemy.native_visual.get_node("Facing").scale.x == 1, "charge spins / changes facing")
	check(enemy.native_visual.player.current_animation == "charge", "no dedicated native charge stride")
	var strokes: Array = charge.get_attack_strokes(enemy)
	check(strokes.size()==1 and strokes[0][0].distance_to(strokes[0][1])<=22.01, "charge effect not a single bounded short stroke")
	charge.cancel()
	for hz in [30,60,120]:
		enemy.position = Vector2.ZERO
		target.position = Vector2(150,0)
		target.hits.clear()
		charge.cooldown = 0
		for frame in range(hz):
			# Exercise controller time integration, not pursuit after ownership releases.
			charge.tick(enemy,target,1.0/hz)
		check(absf(enemy.position.x-158.4) < 0.05 and absf(enemy.position.y)<0.01, "frame-rate-dependent distance %dHz" % hz)
		check(target.hits == [18.0], "not exactly one base-damage contact %dHz" % hz)
		check(not charge.is_active() and charge.cooldown > 3.0, "recovery / cooldown fails %dHz" % hz)
		charge.cancel()
	enemy.position = Vector2.ZERO
	target.position = Vector2(150,0)
	target.hits.clear()
	charge.cooldown = 0
	charge.tick(enemy,target,charge.WARNING+charge.ACTIVE+0.01)
	check(absf(enemy.position.x-158.4)<0.05 and target.hits == [18.0], "large delta skips final active hit or overruns motion")
	check(enemy.velocity == Vector2.ZERO, "recovery still moving")
	enemy._update_static_motion(0)
	check(enemy.native_visual.player.current_animation == "charge_recovery" and charge.get_attack_strokes(enemy).is_empty(), "recovery clip missing / effect lingering")
	var recovered_at: Vector2 = enemy.position
	charge.tick(enemy,target,0.10)
	check(enemy.position.is_equal_approx(recovered_at), "recovery not punishable stationary window")
	charge.cancel()
	enemy.position = Vector2.ZERO
	target.position = Vector2(176,70)
	charge.cooldown = 0
	check(not charge.tick(enemy,target,0.01), "charge starts beyond reachable distance")
	target.position = Vector2(25,0)
	check(not charge.tick(enemy,target,0.01), "charge replaces close melee")
	target.position = Vector2(150,0)
	charge.tick(enemy,target,0.1)
	var valid_time: float = charge.elapsed
	var valid_position: Vector2 = enemy.position
	charge.tick(enemy,target,-1)
	charge.tick(enemy,target,NAN)
	check(charge.elapsed == valid_time and enemy.position == valid_position, "invalid delta corrupts movement clock")
	charge.cancel()
	enemy.position = Vector2.ZERO
	target.position = Vector2(150,0)
	target.hits.clear()
	var wall := StaticBody2D.new()
	wall.position = Vector2(70,0)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(12,160)
	collision.shape = rectangle
	wall.add_child(collision)
	arena.add_child(wall)
	await physics_frame
	charge.cooldown = 0
	charge.tick(enemy,target,charge.WARNING+0.32)
	check(enemy.position.x < 51 and target.hits.is_empty(), "charge tunnels / damages through wall")
	check(charge.stage == charge.Stage.RECOVERY and enemy.velocity == Vector2.ZERO, "collision doesn't stop into recovery")
	wall.free()
	charge.cancel()
	enemy.position = Vector2.ZERO
	target.position = Vector2(150,0)
	charge.cooldown = 0
	enemy._physics_process(0.1)
	target.stealthed = true
	enemy._physics_process(0.01)
	check(not charge.is_active() and charge.cooldown >= 3.5 and not enemy.should_show_attack_marker(), "stealth doesn't cancel charge")
	target.stealthed = false
	enemy.position = Vector2.ZERO
	charge.cooldown = 0
	enemy._physics_process(0.1)
	enemy.apply_spawn_impulse(Vector2.ZERO,0.1)
	enemy._physics_process(0.01)
	check(not charge.is_active(), "spawn impulse doesn't cancel charge")
	enemy.spawn_impulse_remaining = 0
	enemy.position = Vector2.ZERO
	charge.cooldown = 0
	enemy.is_attacking = true
	enemy.attack_timer = 0.15
	enemy.attack_anchor_position = Vector2.ZERO
	enemy._physics_process(0.01)
	check(not charge.is_active(), "charge stacks with existing melee")
	enemy.is_attacking = false
	charge.cooldown = 0
	enemy.position = Vector2.ZERO
	enemy.world_bounds = Rect2(-20,-100,100,200)
	target.position = Vector2(150,0)
	charge.tick(enemy,target,charge.WARNING+0.32)
	check(enemy.position.x <= 66.01 and charge.stage == charge.Stage.RECOVERY, "world boundary doesn't stop charge")
	enemy.world_bounds = Rect2()
	charge.cancel()
	var real_player := PlayerScript.new()
	real_player.position = Vector2(150,300)
	arena.add_child(real_player)
	real_player.set_physics_process(false)
	real_player.health.set_process(false)
	real_player.shield = 0
	enemy.position = Vector2(0,300)
	await physics_frame
	charge.cooldown = 0
	var health_before: float = real_player.health.current_health
	charge.tick(enemy,real_player,charge.WARNING+0.32)
	check(absf(real_player.health.current_health-(health_before-18))<0.01, "real player collision stops outside damage reach")
	check(enemy.position.x < 124 and charge.stage == charge.Stage.RECOVERY, "real player doesn't stop charge")
	charge.tick(enemy,real_player,0.05)
	check(absf(real_player.health.current_health-(health_before-18))<0.01, "real player damaged twice")
	charge.cancel()
	enemy.position = Vector2.ZERO
	target.position = Vector2(150,0)
	charge.cooldown = 0
	enemy._physics_process(0.1)
	enemy.take_damage(10000)
	check(not charge.is_active() and enemy.death_resolved, "dead body keeps charge controller active")
	arena.free()
	await process_frame
	if not failures:
		print("TEST PASS: CinderChargeTest %d" % checks)
	quit(1 if failures else 0)
