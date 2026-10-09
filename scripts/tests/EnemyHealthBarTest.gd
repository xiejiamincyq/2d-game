extends SceneTree

const Enemy = preload("res://scripts/actors/Enemy.gd")
var assertions := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: EnemyHealthBarTest " + label)

func _initialize() -> void:
	await process_frame
	for kind in range(7):
		var enemy := Enemy.new()
		enemy.setup(kind, 0, root)
		root.add_child(enemy)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		check(enemy.should_show_health_bar() == (kind != Enemy.EnemyKind.BRUISER), "full health visibility kind=%d" % kind)
		check(is_equal_approx(enemy.get_health_ratio(), 1.0), "full health ratio")
		enemy.take_damage(enemy.health.max_health * 0.5)
		check(enemy.should_show_health_bar(), "damaged bar visibility kind=%d" % kind)
		check(is_equal_approx(enemy.get_health_ratio(), 0.5), "bar must follow actual damage")
		check(enemy.has_method("get_health_bar_rect") and enemy.has_method("get_attack_marker_top"), "missing shared bar/marker layout")
		if enemy.has_method("get_health_bar_rect") and enemy.has_method("get_attack_marker_top"):
			var bar: Rect2 = enemy.get_health_bar_rect()
			check(is_equal_approx(bar.size.x, enemy.body_radius * 1.6) and is_equal_approx(bar.size.y, 6.0), "existing compact bar geometry changed")
			check(bar.end.y < -enemy.static_visual_half_height, "bar overlaps sprite canvas")
			# Head warning's outlined dot extends 1.5px below its top anchor.
			check(enemy.get_attack_marker_top() + 1.5 <= bar.position.y - 4.0, "head warning overlaps bar")
			enemy.health.current_health = enemy.health.max_health
			check(enemy.should_show_health_bar() == (kind != Enemy.EnemyKind.BRUISER), "restored bar policy")
			enemy.health.current_health = 0.0
			check(not enemy.should_show_health_bar(), "dead bar visible")
			enemy.health.current_health = enemy.health.max_health
			# Placeholder fallback remains valid without a texture.
			enemy.static_visual.free()
			enemy.static_visual = null
			bar = enemy.get_health_bar_rect()
			check(bar.end.y < -enemy.body_radius, "placeholder bar overlaps body")
		var health_node = enemy.health
		enemy.health = null
		check(not enemy.should_show_health_bar(), "uninitialized bar visible")
		enemy.health = health_node
		enemy.free()
	await process_frame
	if failures == 0:
		print("TEST PASS: EnemyHealthBarTest %d" % assertions)
	quit(0 if failures == 0 else 1)
