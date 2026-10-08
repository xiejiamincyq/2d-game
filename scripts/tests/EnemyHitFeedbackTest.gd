extends SceneTree

const Enemy = preload("res://scripts/actors/Enemy.gd")
const Boss = preload("res://scripts/actors/OverseerBoss.gd")
const Damage = preload("res://scripts/components/DamageTypes.gd")
var assertions := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAIL: EnemyHitFeedbackTest: " + message)

func _initialize() -> void:
	var stage := Node2D.new()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(stage)
	for kind in range(7):
		var actor := Enemy.new()
		actor.setup(kind, 1, null)
		stage.add_child(actor)
		await process_frame
		check(actor.get_node_or_null("HitFeedback") != null, "enemy missing actor-local outlined impact")
		var effect := actor.get_node_or_null("HitFeedback")
		if effect == null:
			actor.free()
			continue
		var hp: float = actor.health.current_health
		actor.take_damage(1.0, Damage.PROJECTILE, Vector2.LEFT)
		check(actor.health.current_health == hp - 1.0, "visual changed accepted damage")
		check(effect.life > 0.0 and effect.anchor.x > 0.0 and is_zero_approx(effect.anchor.y), "incoming-left contact not on right edge")
		check(effect.z_as_relative and effect.z_index == 1 and actor.modulate.a == 1.0, "local layering or body opacity changed")
		check(effect.radius <= 12.0 and effect.life <= 0.16, "impact exceeds size/lifetime budget")
		var saved_anchor: Vector2 = effect.anchor
		var saved_life: float = effect.life
		actor.take_damage(0.0, Damage.PROJECTILE, Vector2.RIGHT)
		check(effect.anchor == saved_anchor and effect.life == saved_life, "rejected damage changed impact")
		for index in range(1000):
			effect.request_hit(Vector2.RIGHT, actor.body_radius, 1.0)
		check(effect.anchor == saved_anchor and effect.life == saved_life, "same-frame damage flood bypassed local temporal cap")
		actor.position = Vector2(200, 100)
		check(effect.to_global(effect.anchor).is_equal_approx(actor.position + saved_anchor), "impact detached from moving actor")
		effect._process(0.20)
		check(is_zero_approx(effect.life) and not effect.is_processing(), "idle feedback did not expire and stop processing")
		effect.request_hit(Vector2.DOWN, actor.body_radius, 90.0)
		check(effect.anchor.y < 0.0 and effect.radius <= 12.0, "heavy hit edge or footprint wrong")
		effect._process(0.20)
		effect.request_hit(Vector2.ZERO, actor.body_radius, 1.0)
		check(effect.anchor == Vector2.ZERO, "undirected damage invented a contact edge")
		actor.free()
	var boss := Boss.new()
	boss.setup(5, stage)
	stage.add_child(boss)
	await process_frame
	var boss_effect := boss.get_node_or_null("HitFeedback")
	check(boss_effect != null, "Boss missing shared local impact")
	if boss_effect != null:
		boss.take_damage(1, Damage.LASER, Vector2.LEFT)
		check(is_zero_approx(boss_effect.life), "invulnerable entrance emitted impact")
		boss.entrance_resolved = true
		boss.modulate.a = 1.0
		boss.take_damage(1, Damage.LASER, Vector2.LEFT)
		check(boss_effect.life > 0 and boss_effect.anchor.x > 0, "accepted Boss hit missing edge impact")
		check(is_equal_approx(float(boss.boss_flash_material.get_shader_parameter("flash_amount")), 0.35), "Boss whiteout protection changed")
	stage.free()
	await process_frame
	print("TEST %s: EnemyHitFeedbackTest %d" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(0 if failures == 0 else 1)
