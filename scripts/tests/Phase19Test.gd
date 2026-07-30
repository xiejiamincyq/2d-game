extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const BurnStatusScript = preload("res://scripts/components/BurnStatus.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const WaveDirectorScript = preload("res://scripts/systems/WaveDirector.gd")
const UpgradeSystemScript = preload("res://scripts/systems/UpgradeSystem.gd")
const CombatFeedbackScript = preload("res://scripts/systems/CombatFeedback.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

class DamageTarget extends Node2D:
	var damage_received := 0.0
	func take_damage(amount: float, _source: StringName = &"generic", _direction: Vector2 = Vector2.ZERO) -> bool:
		damage_received += amount
		return true

class StealthTarget extends Node2D:
	func is_stealthed() -> bool:
		return true

class CameraProbe extends Node:
	var impacts := 0
	func request_impact(_intensity: float, _direction: Vector2) -> void:
		impacts += 1

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: Phase19Test: " + message)
	paused = false
	quit(1)
	return false

func _find_card(upgrades: Node, card_id: String) -> Dictionary:
	for card_value in upgrades.upgrade_pool:
		var card: Dictionary = card_value
		if String(card.get("id", "")) == card_id:
			return card
	return {}

func _initialize() -> void:
	var burn: RefCounted = BurnStatusScript.new()
	for stack_index in range(6):
		burn.apply_stack(10.0, 4.0, 0.30)
	if not _assert_true(
		burn.get_stack_count() == 5
		and is_equal_approx(burn.get_damage_per_second(), 30.0)
		and is_equal_approx(burn.get_slow_fraction(), 0.30),
		"burn did not cap at five 60%-base-attack stacks"
	):
		return
	if not _assert_true(
		is_equal_approx(burn.advance(1.0), 30.0) and burn.get_stack_count() == 5,
		"burn did not deal one second of stacked damage"
	):
		return
	if not _assert_true(
		is_equal_approx(burn.advance(3.1), 90.0)
		and burn.get_stack_count() == 0
		and is_zero_approx(burn.get_slow_fraction()),
		"burn stacks did not expire and release their slow after four seconds"
	):
		return
	if not _assert_true(DamageTypes.resolve(DamageTypes.BURN) == DamageTypes.BURN, "burn damage type was not preserved"):
		return

	var camera_probe := CameraProbe.new()
	root.add_child(camera_probe)
	var feedback: Node = CombatFeedbackScript.new()
	root.add_child(feedback)
	feedback.setup(null, camera_probe)
	feedback.on_damage_resolved(null, DamageTypes.SPIKE, 90.0, Vector2.ZERO, Vector2.RIGHT, false)
	feedback.on_damage_resolved(null, DamageTypes.BURN, 90.0, Vector2.ZERO, Vector2.RIGHT, false)
	if not _assert_true(camera_probe.impacts == 0, "spike or burn damage still caused camera impact"):
		return

	var projectiles := Node2D.new()
	root.add_child(projectiles)
	var player: Node = PlayerScript.new()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.projectile_parent = projectiles
	var fired: Array[Node] = []
	player.fired.connect(func(projectile: Node) -> void:
		projectiles.add_child(projectile)
		projectile.set_physics_process(false)
		projectile.set_process(false)
		fired.append(projectile)
	)
	player.velocity = Vector2(100.0, 50.0)
	player._spawn_bullet(Vector2.RIGHT)
	if not _assert_true(fired[-1].velocity.is_equal_approx(Vector2(720.0, 50.0)), "normal bullet did not inherit player velocity"):
		return
	player.activate_build_evolution("orbital_storm")
	player._spawn_bullet(Vector2.RIGHT)
	if not _assert_true(
		is_equal_approx(player.get_effective_fire_rate(), player.fire_rate * 0.20)
		and fired[-1].velocity.is_equal_approx(Vector2(348.0, 50.0)),
		"grenade did not use 20% fire rate, 40% muzzle speed, and player inertia"
	):
		return

	player.activate_build_evolution("rift_overdrive")
	player._activate_assassin_stealth()
	if not _assert_true(is_equal_approx(player.stealth_remaining, 1.2), "assassin stealth was not 1.2 seconds"):
		return
	player._fire()
	if not _assert_true(not player.is_stealthed(), "firing did not break stealth"):
		return
	var children_before_dash := projectiles.get_child_count()
	player.dash_cooldown_remaining = 0.0
	player._start_dash(Vector2.RIGHT)
	player._update_dash(player.dash_duration * 0.5)
	player._update_passives(0.05)
	player._update_dash(player.dash_duration * 0.5)
	player._update_passives(0.05)
	var dash_children := projectiles.get_children().slice(children_before_dash)
	if not _assert_true(
		dash_children.any(func(child: Node) -> bool: return child.get_script() == player.FlameTrailScript)
		and not dash_children.any(func(child: Node) -> bool: return child.get_script() == player.SpikeTrapScript),
		"assassin dash did not leave only purple flame"
	):
		return
	for child in dash_children:
		child.set_physics_process(false)

	var arc_parent := Node2D.new()
	root.add_child(arc_parent)
	player.projectile_parent = arc_parent
	player.arc_pulse_level = 1
	player.global_position = Vector2(25.0, 40.0)
	player._emit_arc_pulse()
	var arc: Node2D = arc_parent.get_child(0)
	var emission_position := arc.global_position
	player.global_position += Vector2(300.0, 120.0)
	arc._process(0.05)
	if not _assert_true(arc.global_position.is_equal_approx(emission_position), "arc center followed the player after emission"):
		return
	arc.set_process(false)

	var upgrades: Node = UpgradeSystemScript.new()
	root.add_child(upgrades)
	upgrades.setup(player)
	var pierce_card := _find_card(upgrades, "drone_pierce")
	if not _assert_true(not pierce_card.is_empty() and not upgrades._is_card_unlocked(pierce_card), "drone piercing card was missing or unlocked too early"):
		return
	upgrades._apply_card("drone")
	if not _assert_true(upgrades._is_card_unlocked(pierce_card), "drone piercing card stayed locked after drone unlock"):
		return
	upgrades._apply_card("drone_pierce")
	if not _assert_true(player.drone_laser_piercing, "drone piercing card did not enable piercing lasers"):
		return
	var inline_target := DamageTarget.new()
	var offset_target := DamageTarget.new()
	var missed_target := DamageTarget.new()
	inline_target.global_position = Vector2(100.0, 0.0)
	offset_target.global_position = Vector2(200.0, 3.0)
	missed_target.global_position = Vector2(200.0, 80.0)
	for target in [inline_target, offset_target, missed_target]:
		root.add_child(target)
	player.set_enemy_provider(func() -> Array[Node]: return [inline_target, offset_target, missed_target])
	player._damage_enemies_on_laser(Vector2.ZERO, Vector2.RIGHT, 300.0, 10.0, 4.0)
	if not _assert_true(
		inline_target.damage_received > 0.0 and offset_target.damage_received > 0.0 and is_zero_approx(missed_target.damage_received),
		"piercing laser did not damage exactly the enemies along its beam"
	):
		return
	for target in [inline_target, offset_target, missed_target]:
		target.queue_free()
	player.set_enemy_provider(Callable())

	var scrapper: Node = EnemyScript.new()
	scrapper.setup(EnemyScript.EnemyKind.SCRAPPER, 5, projectiles)
	if not _assert_true(is_equal_approx(scrapper.speed, PlayerScript.BASE_MOVE_SPEED * 0.90), "Scrapper did not use 90% player speed"):
		return
	scrapper.queue_free()
	var dasher: Node = EnemyScript.new()
	dasher.setup(EnemyScript.EnemyKind.DASHER, 5, projectiles)
	if not _assert_true(is_equal_approx(dasher.speed, PlayerScript.BASE_MOVE_SPEED * 1.10), "pink Dasher did not use 110% player speed"):
		return
	dasher.queue_free()
	for kind in [EnemyScript.EnemyKind.SPITTER, EnemyScript.EnemyKind.MARKSMAN, EnemyScript.EnemyKind.LOBBER]:
		var enemy: Node = EnemyScript.new()
		enemy.setup(kind, 5, projectiles)
		if not _assert_true(is_equal_approx(enemy.speed, PlayerScript.BASE_MOVE_SPEED * 0.60), "ranged enemy kind %d did not use 60%% player speed" % kind):
			return
		enemy.queue_free()
	if not _assert_true(
		WaveDirectorScript.should_drop_heart(0.024999) and not WaveDirectorScript.should_drop_heart(0.025)
		and WaveDirectorScript.should_drop_shield(0.699999) and not WaveDirectorScript.should_drop_shield(0.70),
		"heart or shield drop probability boundary was incorrect"
	):
		return

	var stealth_target := StealthTarget.new()
	root.add_child(stealth_target)
	var dispersing_enemy: CharacterBody2D = EnemyScript.new()
	dispersing_enemy.setup(EnemyScript.EnemyKind.SCRAPPER, 0, projectiles, stealth_target)
	root.add_child(dispersing_enemy)
	await process_frame
	var dispersal_start := dispersing_enemy.global_position
	dispersing_enemy._physics_process(0.1)
	if not _assert_true(dispersing_enemy.velocity.length() > 0.0 and dispersing_enemy.global_position != dispersal_start, "enemy stopped instead of dispersing while player was hidden"):
		return

	var scene: Node = MainScript.new()
	root.add_child(scene)
	await process_frame
	scene._start_run()
	var physical_spawn: Vector2 = scene.player.global_position
	if not _assert_true(
		scene.run_state == scene.RunState.START
		and scene.player.is_entrance_active()
		and not scene.ui.start_panel.visible
		and scene.ui.hud.visible
		and not scene.wave_director.prepared_wave
		and scene.wave_director.active_enemies.is_empty(),
		"new run prepared or spawned enemies before the player entrance"
	):
		return
	scene.player.advance_entrance(scene.player.get_entrance_duration() + 0.01)
	if not _assert_true(
		scene.player.global_position.is_equal_approx(physical_spawn)
		and scene.run_state == scene.RunState.WAVE_INTRO
		and scene.wave_director.prepared_wave,
		"landing moved the physical player or failed to unlock the first wave"
	):
		return

	TestSupport.stop_audio(scene.audio)
	feedback.reset_all()
	scene.queue_free()
	player.queue_free()
	projectiles.queue_free()
	arc_parent.queue_free()
	upgrades.queue_free()
	if is_instance_valid(dispersing_enemy):
		dispersing_enemy.queue_free()
	stealth_target.queue_free()
	feedback.queue_free()
	camera_probe.queue_free()
	paused = false
	await process_frame
	await process_frame
	print("TEST PASS: Phase19Test %d" % assertions)
	quit(0)
