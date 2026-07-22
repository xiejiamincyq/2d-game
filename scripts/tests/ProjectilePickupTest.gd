extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const ProjectileScript = preload("res://scripts/components/Projectile.gd")
const CoinPickupScript = preload("res://scripts/pickups/CoinPickup.gd")
const ShieldPickupScript = preload("res://scripts/pickups/ShieldPickup.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: ProjectilePickupTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var scene: Node = MainScript.new()
	root.add_child(scene)
	await process_frame
	scene._start_run()
	await process_frame
	scene.ui.wave_banner.finish_message()
	scene.wave_director.active = false

	var enemy: CharacterBody2D = EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.BRUISER, 1, scene.projectiles)
	enemy.global_position = Vector2(420.0, 180.0)
	scene.enemies.add_child(enemy)
	enemy.died.connect(scene.wave_director._on_enemy_died)
	var expected_enemy_id: int = enemy.get_instance_id()
	var expected_coins: int = enemy.coin_value
	var kill_facts: Array[Dictionary] = []
	scene.wave_director.enemy_killed.connect(func(killed_enemy: Node, source: StringName, coin_value: int) -> void:
		kill_facts.append({"enemy_id": killed_enemy.get_instance_id(), "source": source, "coins": coin_value})
	)
	# A duplicate migration consumer must not create a second kill fact or drops.
	enemy.died.connect(func(killed_enemy: Node, coin_value: int, source: StringName) -> void:
		scene.wave_director._on_enemy_died(killed_enemy, coin_value, source)
	)
	await process_frame
	enemy.health.current_health = 1.0
	enemy.shield_drop_value = 20.0

	var projectile: Area2D = ProjectileScript.new()
	projectile.damage = 2.0
	projectile.global_position = enemy.global_position
	projectile.velocity = Vector2.ZERO
	projectile.world_bounds = scene.get_world_bounds()
	scene.projectiles.add_child(projectile)

	await physics_frame
	await physics_frame
	await process_frame

	var coin_pickups: Array[Node] = []
	var shield_pickups: Array[Node] = []
	for child in scene.pickups.get_children():
		if child.get_script() == CoinPickupScript:
			coin_pickups.append(child)
		elif child.get_script() == ShieldPickupScript:
			shield_pickups.append(child)
	if not _assert_true(coin_pickups.size() == 1, "physical projectile kill created %d coin pickups" % coin_pickups.size()):
		return
	if not _assert_true(shield_pickups.size() == 1, "physical projectile kill created %d shield pickups" % shield_pickups.size()):
		return
	if not _assert_true(kill_facts.size() == 1, "one enemy created %d kill facts" % kill_facts.size()):
		return
	if not _assert_true(kill_facts[0]["enemy_id"] == expected_enemy_id, "kill fact lost the enemy reference"):
		return
	if not _assert_true(kill_facts[0]["source"] == DamageTypes.PROJECTILE, "kill fact source was %s" % kill_facts[0]["source"]):
		return
	if not _assert_true(kill_facts[0]["coins"] == expected_coins, "kill fact changed the coin value"):
		return

	var coins_before: int = scene.upgrade_system.coins
	for pickup in [coin_pickups[0], shield_pickups[0]]:
		var collection_count := [0]
		pickup.collected.connect(func(_value: Variant) -> void: collection_count[0] += 1)
		pickup.global_position = scene.player.global_position
		pickup._physics_process(0.0)
		pickup._on_body_entered(scene.player)
		if not _assert_true(collection_count[0] == 1, "%s emitted collected %d times in one frame" % [pickup.get_class(), collection_count[0]]):
			return
	if not _assert_true(scene.upgrade_system.coins == coins_before + expected_coins, "coin pickup did not increase the run balance exactly once"):
		return

	var shield_before_hostile_projectile: float = scene.player.shield
	scene.player.health.invulnerable_time = 0.0
	var hostile_projectile: Area2D = ProjectileScript.new()
	hostile_projectile.damage = 3.0
	hostile_projectile.target_group = &"player"
	scene.projectiles.add_child(hostile_projectile)
	hostile_projectile._try_hit(scene.player)
	if not _assert_true(
		is_equal_approx(scene.player.shield, shield_before_hostile_projectile - 3.0),
		"hostile projectile did not use the player's compatible damage contract"
	):
		return

	TestSupport.stop_audio(scene.audio)
	await create_timer(0.25).timeout
	scene.queue_free()
	paused = false
	await process_frame
	await process_frame
	print("TEST PASS: ProjectilePickupTest %d" % assertions)
	quit(0)
