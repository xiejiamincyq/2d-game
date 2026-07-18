extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: StateTest: " + message)
	paused = false
	quit(1)
	return false

func _initialize() -> void:
	for path in ["res://scripts/systems/UpgradeSystem.gd", "res://scripts/ui/GameUI.gd"]:
		var source := FileAccess.get_file_as_string(path)
		if not _assert_true(source.find("get_tree().paused =") == -1, "%s still assigns SceneTree.paused" % path):
			return

	var scene: Node = MainScript.new()
	root.add_child(scene)
	await process_frame
	if not _assert_true(scene.get("run_state") == 0, "Main did not start in START state"):
		return
	if not _assert_true(scene._transition_to(4) == false, "illegal START to RESULT transition was accepted"):
		return
	scene._start_run()
	if not _assert_true(scene.get("run_state") == 1 and not paused, "start did not enter PLAYING"):
		return
	if not _assert_true(
		is_instance_valid(scene.combat_feedback)
		and is_instance_valid(scene.combat_vfx)
		and is_instance_valid(scene.camera_effects),
		"run start did not build the combat feedback pipeline"
	):
		return
	scene.wave_director.active = false
	scene.wave_director._spawn_enemy(EnemyScript.EnemyKind.SCRAPPER)
	await process_frame
	var feedback_enemy: Node = scene.wave_director.active_enemies[-1]
	feedback_enemy.set_physics_process(false)
	feedback_enemy.health.set_process(false)
	var sparks_before: int = scene.combat_vfx.get_effect_count(&"spark")
	feedback_enemy.take_damage(1.0, DamageTypes.PROJECTILE, Vector2.RIGHT)
	if not _assert_true(
		scene.combat_vfx.get_effect_count(&"spark") == sparks_before + 1,
		"enemy damage did not reach the combat feedback pipeline"
	):
		return
	scene.combat_vfx.clear_all()
	feedback_enemy.health.current_health = 1.0
	feedback_enemy.take_damage(5.0, DamageTypes.PROJECTILE, Vector2.RIGHT)
	if not _assert_true(scene.kill_count == 1, "lethal damage did not reach the unique kill pipeline"):
		return
	if not _assert_true(
		scene.combat_vfx.get_effect_count(&"spark") >= 4
		and scene.combat_vfx.get_effect_count(&"debris") >= 6
		and scene.combat_vfx.get_effect_count(&"ring") >= 2,
		"a real enemy kill did not produce a clearly readable bounded burst"
	):
		return
	if not _assert_true(scene.camera_effects.trauma >= 0.75, "a real enemy kill did not produce a readable camera impact"):
		return
	scene._reset_combat_feedback()
	var permanent_fire_rate: float = scene.player.fire_rate * 1.5
	var permanent_weapon_damage: float = scene.player.weapon_damage * 1.25
	scene.player.fire_rate = permanent_fire_rate
	scene.player.weapon_damage = permanent_weapon_damage
	scene.player.set_overdrive_active(true)
	scene.player.set_dash_immunity_active(true)
	scene.combat_feedback.request_hit_stop(20.0)
	scene.camera_effects.request_impact(1.0, Vector2.RIGHT)
	scene.camera_effects._process(0.016)
	if not _assert_true(scene._transition_to(2) and paused, "PLAYING to UPGRADE did not pause"):
		return
	if not _assert_true(
		is_equal_approx(Engine.time_scale, 1.0)
		and scene.combat_vfx.get_total_effect_count() == 0
		and scene.player.get_node("PlayerCamera").offset == Vector2.ZERO
		and is_zero_approx(scene.player.get_node("PlayerCamera").rotation),
		"upgrade transition did not reset combat feedback"
	):
		return
	if not _assert_true(
		is_equal_approx(scene.player.get_effective_fire_rate(), permanent_fire_rate),
		"upgrade pause did not clear temporary fire-rate modifiers"
	):
		return
	if not _assert_true(
		is_equal_approx(scene.player.weapon_damage, permanent_weapon_damage),
		"temporary-state cleanup changed permanent weapon damage"
	):
		return
	if not _assert_true(
		is_equal_approx(scene.player.get_effective_damage_multiplier(DamageTypes.PROJECTILE), 1.0),
		"upgrade pause did not clear temporary damage modifiers"
	):
		return
	if not _assert_true(not scene.player.is_damage_immune(), "upgrade pause left temporary immunity active"):
		return
	if not _assert_true(scene._transition_to(1) and not paused, "UPGRADE to PLAYING did not resume"):
		return
	scene.player.set_overdrive_active(true)
	scene.player.set_dash_immunity_active(true)
	scene.combat_vfx.request_effect(&"ring", Vector2.ZERO)
	scene.combat_feedback.request_hit_stop(20.0)
	scene.camera_effects.request_impact(1.0, Vector2.UP)
	scene.camera_effects._process(0.016)
	if not _assert_true(scene._transition_to(3) and paused, "PLAYING to PAUSED did not pause"):
		return
	if not _assert_true(
		is_equal_approx(Engine.time_scale, 1.0)
		and scene.combat_vfx.get_total_effect_count() == 0
		and scene.player.get_node("PlayerCamera").offset == Vector2.ZERO
		and is_zero_approx(scene.player.get_node("PlayerCamera").rotation),
		"manual pause transition did not reset combat feedback"
	):
		return
	if not _assert_true(not scene.player.is_damage_immune(), "manual pause left temporary immunity active"):
		return
	if not _assert_true(scene._transition_to(1) and not paused, "PAUSED to PLAYING did not resume"):
		return
	scene.player.set_overdrive_active(true)
	scene.combat_vfx.request_effect(&"debris", Vector2.ZERO)
	scene.combat_feedback.request_hit_stop(20.0)
	scene.camera_effects.request_impact(1.0, Vector2.LEFT)
	scene.camera_effects._process(0.016)
	if not _assert_true(scene._transition_to(4) and paused, "PLAYING to RESULT did not pause"):
		return
	if not _assert_true(
		is_equal_approx(Engine.time_scale, 1.0)
		and scene.combat_vfx.get_total_effect_count() == 0
		and scene.player.get_node("PlayerCamera").offset == Vector2.ZERO
		and is_zero_approx(scene.player.get_node("PlayerCamera").rotation),
		"result transition did not reset combat feedback"
	):
		return
	if not _assert_true(
		is_equal_approx(scene.player.get_effective_fire_rate(), permanent_fire_rate)
		and is_equal_approx(scene.player.get_effective_damage_multiplier(DamageTypes.PROJECTILE), 1.0)
		and not scene.player.is_damage_immune(),
		"result transition did not restore runtime modifiers"
	):
		return

	TestSupport.stop_audio(scene.audio)
	await create_timer(0.25).timeout
	scene.combat_feedback.request_hit_stop(20.0)
	if not _assert_true(Engine.time_scale < 1.0, "exit cleanup precondition did not activate hit-stop"):
		return
	scene.queue_free()
	paused = false
	await process_frame
	if not _assert_true(is_equal_approx(Engine.time_scale, 1.0), "tree exit did not restore Engine.time_scale"):
		return
	await process_frame
	print("TEST PASS: StateTest %d" % assertions)
	quit(0)
