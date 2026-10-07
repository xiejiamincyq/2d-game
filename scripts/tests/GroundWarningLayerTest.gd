extends SceneTree

const Lob = preload("res://scripts/components/LobbedProjectile.gd")
const Tentacle = preload("res://scripts/components/TentacleAttack.gd")
const Pattern = preload("res://scripts/components/BossProjectilePattern.gd")
const Bullet = preload("res://scripts/components/Projectile.gd")
const EnemyActor = preload("res://scripts/actors/Enemy.gd")
const PlayerActor = preload("res://scripts/actors/Player.gd")
const Outline = preload("res://scripts/effects/PlayerOcclusionOutline.gd")
var assertions := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAIL: GroundWarningLayerTest: " + message)

func effective_z(item: CanvasItem) -> int:
	var value := item.z_index
	var relative := item.z_as_relative
	var parent := item.get_parent() as CanvasItem
	while relative and parent != null:
		value += parent.z_index
		relative = parent.z_as_relative
		parent = parent.get_parent() as CanvasItem
	return value

func ground(item: Node, label: String) -> void:
	var visual := item as Node2D
	check(visual != null, label + " must have a real ground visual node")
	if visual != null:
		check(not visual.z_as_relative and effective_z(visual) == -1, label + " must stay absolute -1 above floor -100 and below actors 0")
func _initialize() -> void:
	# Layer tests cannot prove which draw commands moved: a rendered overlap probe is also required.
	for settings in [[0, 22, true], [7, 50, true], [7, 50, false]]:
		var ancestor := Node2D.new()
		ancestor.z_index = settings[0]
		ancestor.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(ancestor)
		var shots := Node2D.new()
		shots.z_index = settings[1]
		shots.z_as_relative = settings[2]
		shots.position = Vector2(73, -41)
		ancestor.add_child(shots)
		var player := PlayerActor.new()
		ancestor.add_child(player)
		player.global_position = Vector2(240, 80)
		await process_frame
		var lob := Lob.new()
		shots.add_child(lob)
		lob.configure(Vector2(100, 40), player.global_position, player)
		ground(lob.get_node_or_null("LandingFill"), "lob landing rim/fill")
		check(effective_z(lob) == effective_z(shots) and effective_z(lob) > Outline.OUTLINE_Z_INDEX, "flying lob core must remain foreground")
		check(lob.splash_radius == 72 and lob.flight_duration == 0.85 and lob.damage == 14, "lob combat defaults changed")
		lob._physics_process(0.425)
		check(lob.global_position.is_equal_approx(Vector2(170, 60)) and lob.target_position == Vector2(240, 80), "lob flight interpolation/locked target changed")
		var landing := lob.get_node_or_null("LandingFill") as Node2D
		check(landing != null and landing.global_position.is_equal_approx(lob.target_position), "ground landing marker must retain world destination during flight")
		lob._explode()
		var impact := shots.get_node_or_null("LobImpact")
		ground(impact, "lob impact rim")
		check(impact != null and impact.radius == 72 and impact.DURATION == 0.20 and impact.global_position == Vector2(240, 80), "impact radius/duration/destination changed")
		check(player.health.current_health == 86, "lob splash must still damage real player for 14")
		if impact != null:
			impact._process(0.10)
			check(not impact.is_queued_for_deletion(), "impact ended before 0.20 seconds")
			impact._process(0.10)
			check(impact.is_queued_for_deletion(), "impact must end at 0.20 seconds")
		for kind in range(7):
			var enemy := EnemyActor.new()
			enemy.setup(kind, 1, shots, player)
			shots.add_child(enemy)
			enemy.ranged_is_winding_up = true
			enemy.ranged_target_position = player.global_position
			enemy.is_attacking = true
			ground(enemy.get_node_or_null("GroundWarning"), "enemy %d aim/melee cue" % kind)
			check(effective_z(enemy.static_visual) == effective_z(enemy), "enemy %d sprite must not be grounded with its warnings" % kind)
		var boss := EnemyActor.new()
		shots.add_child(boss)
		boss.global_position = Vector2(100, 40)
		var attack := Tentacle.new()
		boss.add_child(attack)
		attack.configure(boss, player, shots)
		ground(attack.get_node_or_null("GroundFill"), "tentacle sweep/slam/hose")
		check(attack.start_sweep(player.global_position), "valid sweep start rejected")
		attack.advance_attack(0.99)
		check(attack.attack_stage == Tentacle.AttackStage.WARNING and player.health.current_health == 86, "sweep warning timing changed")
		player.health.invulnerable_time = 0
		attack.advance_attack(0.02)
		check(attack.attack_stage == Tentacle.AttackStage.ACTIVE and player.health.current_health == 68, "active sweep must still hit once for 18")
		attack.cancel_attack()
		var targets: Array[Vector2] = attack.make_slam_targets(player.global_position)
		check(attack.start_slam(targets) and attack.get_slam_targets() == targets and attack.SLAM_RADIUS == 45 and attack.SLAM_WARNING_SECONDS == 1.1, "slam target lock/radius/timing changed")
		attack.cancel_attack()
		var pattern := Pattern.new()
		boss.add_child(pattern)
		pattern.configure(shots, Rect2(-1000, -1000, 2000, 2000), player, boss.get_instance_id(), 42)
		ground(pattern, "Boss aimed-fan visual")
		check(pattern.start_pattern(Pattern.AIMED_FAN), "valid aimed-fan rejected")
		var plan := pattern.get_active_plan()
		check(plan.size() in [10, 12, 14] and plan[0].time == 0.45 and plan[plan.size() - 1].time == 1.0, "seeded fan count/round timing changed")
		var reference_rng := RandomNumberGenerator.new()
		reference_rng.seed = 42
		check(plan.size() == reference_rng.randi_range(5, 7) * 2, "fan seeded projectile count changed")
		for event in plan:
			check(event.speed == reference_rng.randf_range(220, 280), "fan seeded velocity/RNG consumption changed")
		check(pattern._rng.state == reference_rng.state, "visual layer setup consumed pattern RNG")
		pattern.advance(0.449)
		check(pattern.get_total_spawned() == 0, "fan spawned before warning elapsed")
		pattern.advance(0.002)
		check(pattern.get_total_spawned() == plan.size() / 2, "fan first round count changed")
		for shot in pattern._spawned_projectiles:
			check(effective_z(shot) == effective_z(shots) and shot.damage == 9 and shot.radius == 5, "Boss live bullet must retain foreground/damage/collision radius")
		for mode in ["ordinary", "overdrive", "hostile"]:
			var bullet := Bullet.new()
			bullet.overdrive_visual = mode == "overdrive"
			bullet.target_group = &"player" if mode == "hostile" else &"enemies"
			bullet.velocity = Vector2(620, 0)
			shots.add_child(bullet)
			if mode == "overdrive":
				ground(bullet.get_node_or_null("OverdriveTrail"), "non-colliding overdrive trail")
			check(effective_z(bullet) == effective_z(shots) and effective_z(bullet) > Outline.OUTLINE_Z_INDEX, mode + " live bullet must remain foreground")
			var collisions := bullet.get_children().filter(func(child: Node) -> bool: return child is CollisionShape2D)
			check(collisions.size() == 1 and collisions[0].shape.radius == 4 and bullet.damage == 1 and bullet.lifetime == 6 and bullet.velocity == Vector2(620, 0), mode + " bullet collision/motion/damage defaults changed")
		player._start_dash(Vector2.RIGHT)
		var before: Vector2 = player.global_position
		player._update_dash(0.16)
		check(not player.dash_active and player.global_position.distance_to(before + Vector2(165, 0)) <= 0.01, "visual layering must not change real open-space dash")
		ancestor.free()
		await process_frame
	print("TEST %s: GroundWarningLayerTest %d" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(0 if failures == 0 else 1)
