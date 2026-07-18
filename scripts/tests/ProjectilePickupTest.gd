extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const ProjectileScript = preload("res://scripts/components/Projectile.gd")
const ExperienceShardScript = preload("res://scripts/pickups/ExperienceShard.gd")
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
	scene.wave_director.active = false

	var enemy: CharacterBody2D = EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.BRUISER, 1, scene.projectiles)
	enemy.global_position = Vector2(420.0, 180.0)
	scene.enemies.add_child(enemy)
	enemy.died.connect(scene.wave_director._on_enemy_died)
	var expected_enemy_id: int = enemy.get_instance_id()
	var expected_xp: int = enemy.xp_value
	var kill_facts: Array[Dictionary] = []
	scene.wave_director.enemy_killed.connect(func(killed_enemy: Node, source: StringName, xp_value: int) -> void:
		kill_facts.append({"enemy_id": killed_enemy.get_instance_id(), "source": source, "xp": xp_value})
	)
	# A duplicate migration consumer must not create a second kill fact or drops.
	enemy.died.connect(func(killed_enemy: Node, xp_value: int, source: StringName) -> void:
		scene.wave_director._on_enemy_died(killed_enemy, xp_value, source)
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

	var xp_pickups: Array[Node] = []
	var shield_pickups: Array[Node] = []
	for child in scene.pickups.get_children():
		if child.get_script() == ExperienceShardScript:
			xp_pickups.append(child)
		elif child.get_script() == ShieldPickupScript:
			shield_pickups.append(child)
	if not _assert_true(xp_pickups.size() == 1, "physical projectile kill created %d XP pickups" % xp_pickups.size()):
		return
	if not _assert_true(shield_pickups.size() == 1, "physical projectile kill created %d shield pickups" % shield_pickups.size()):
		return
	if not _assert_true(kill_facts.size() == 1, "one enemy created %d kill facts" % kill_facts.size()):
		return
	if not _assert_true(kill_facts[0]["enemy_id"] == expected_enemy_id, "kill fact lost the enemy reference"):
		return
	if not _assert_true(kill_facts[0]["source"] == DamageTypes.PROJECTILE, "kill fact source was %s" % kill_facts[0]["source"]):
		return
	if not _assert_true(kill_facts[0]["xp"] == expected_xp, "kill fact changed the XP value"):
		return

	for pickup in [xp_pickups[0], shield_pickups[0]]:
		var collection_count := [0]
		pickup.collected.connect(func(_value: Variant) -> void: collection_count[0] += 1)
		pickup.global_position = scene.player.global_position
		pickup._physics_process(0.0)
		pickup._on_body_entered(scene.player)
		if not _assert_true(collection_count[0] == 1, "%s emitted collected %d times in one frame" % [pickup.get_class(), collection_count[0]]):
			return

	TestSupport.stop_audio(scene.audio)
	await create_timer(0.25).timeout
	scene.queue_free()
	paused = false
	await process_frame
	await process_frame
	print("TEST PASS: ProjectilePickupTest %d" % assertions)
	quit(0)
