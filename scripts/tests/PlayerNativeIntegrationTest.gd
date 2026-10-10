extends SceneTree

const PlayerSource = preload("res://scripts/actors/Player.gd")
var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: PlayerNativeIntegrationTest " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var detached = PlayerSource.new()
	detached._ready()
	check(not detached.native_visual.is_inside_tree(), "detached construction fixture unexpectedly entered a tree")
	detached.free()
	var fixture := Node2D.new()
	root.add_child(fixture)
	var actor = PlayerSource.new()
	fixture.add_child(actor)
	actor.set_physics_process(false)
	check(actor.has_method("get_visual_node"), "actual Player has no native visual integration")
	if failures:
		fixture.free()
		quit(1)
		return
	var view = actor.get_visual_node()
	check(view != null and view.scene_file_path.ends_with("player_paper_v1.tscn"), "actual Player still renders old atlas")
	check(actor.player_body_texture == null and actor.player_weapon_texture == null, "legacy player textures still loaded")
	var start: Transform2D = actor.global_transform
	var radius: float = actor.player_collision.shape.radius
	var shots: Array[Node] = []
	actor.fired.connect(func(shot: Node) -> void: shots.append(shot))
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		actor.gun_angle = direction.angle()
		actor.velocity = Vector2(123, 45)
		actor._update_visual_animation(0.11)
		var rig: Skeleton2D = view.get_node(view.facing + "/Skeleton2D")
		var leg: Bone2D = rig.get_node("Torso/LegL")
		var gait := leg.transform
		actor._spawn_bullet(direction)
		check(shots[-1].global_position.is_equal_approx(view.get_muzzle_position()), "real bullet not emitted at attached gun muzzle")
		check(shots[-1].velocity.is_equal_approx(actor.velocity + direction * 620), "ordinary bullet velocity changed")
		actor._update_visual_animation(0.02)
		check(view.clip == "shoot" and not leg.transform.is_equal_approx(leg.rest) and not leg.transform.is_equal_approx(gait), "shooting erased/froze actual gait")
		shots[-1].free()
	actor.activate_build_evolution("orbital_storm")
	actor._spawn_bullet(Vector2.RIGHT)
	check(shots[-1].global_position.is_equal_approx(view.get_muzzle_position()), "grenade missed hand muzzle")
	check(shots[-1].velocity.is_equal_approx(actor.velocity * 0.30 + Vector2.RIGHT * 620 * 0.48), "grenade 30 percent inheritance / boosted base speed changed")
	shots[-1].free()
	var aiming_viewport := SubViewport.new()
	aiming_viewport.size = Vector2i(512, 512)
	aiming_viewport.world_2d = World2D.new()
	root.add_child(aiming_viewport)
	var aiming_actor = PlayerSource.new()
	aiming_actor.position = Vector2(256, 256)
	aiming_viewport.add_child(aiming_actor)
	aiming_actor.set_physics_process(false)
	var aiming_shots: Array[Node] = []
	aiming_actor.fired.connect(func(shot: Node) -> void: aiming_shots.append(shot))
	for degrees in range(0, 360, 45):
		var point: Vector2 = aiming_actor.position + Vector2.RIGHT.rotated(deg_to_rad(degrees)) * 200
		var cursor := InputEventMouseMotion.new()
		cursor.position = point
		aiming_viewport.push_input(cursor, true)
		check(aiming_actor.get_global_mouse_position().is_equal_approx(point), "viewport cursor fixture failed")
		aiming_actor.gun_angle = deg_to_rad(degrees)
		aiming_actor._update_visual_animation(0)
		aiming_actor._fire()
		var projectile = aiming_shots[-1]
		check(absf((point - projectile.position).cross(projectile.velocity.normalized())) < 0.01, "stationary native muzzle ray misses actual cursor")
		projectile.free()
	for distance in [20.0, 200.0, 900.0]:
		for degrees in range(0, 360, 5):
			var point: Vector2 = aiming_actor.position + Vector2.RIGHT.rotated(deg_to_rad(degrees)) * distance
			var cursor := InputEventMouseMotion.new()
			cursor.position = point
			aiming_viewport.push_input(cursor, true)
			aiming_actor.gun_angle = (point - aiming_actor.position).angle()
			aiming_actor._update_visual_animation(0.02)
			var facing: String = aiming_actor.native_visual.facing
			aiming_actor._fire()
			var projectile = aiming_shots[-1]
			var weapon: Bone2D = aiming_actor.native_visual.get_node(facing + "/Skeleton2D/Torso/ArmR/ForearmR/HandR/Weapon")
			check(absf((point - projectile.position).cross(projectile.velocity.normalized())) < 0.01 and (point - projectile.position).dot(projectile.velocity) > 0, "five-degree near/far muzzle ray misses cursor")
			check(aiming_actor.native_visual.facing == facing and absf(weapon.rotation - weapon.rest.get_rotation()) <= PI / 4 + 0.0001, "muzzle correction changed body view or wrist limit: degrees=%d distance=%.0f before=%s after=%s residual=%.4f" % [degrees, distance, facing, aiming_actor.native_visual.facing, weapon.rotation - weapon.rest.get_rotation()])
			check(is_equal_approx(projectile.velocity.length(), 620), "aim correction changed base bullet speed")
			projectile.free()
	var volley_cursor := InputEventMouseMotion.new()
	volley_cursor.position = Vector2(456, 256)
	aiming_viewport.push_input(volley_cursor, true)
	aiming_actor.weapon_lines = 3
	var first_index := aiming_shots.size()
	aiming_actor._fire()
	check(aiming_shots.size() - first_index == 3, "native volley line count changed")
	var muzzle: Vector2 = aiming_shots[first_index].position
	for line in 3:
		var projectile = aiming_shots[first_index + line]
		var expected := (volley_cursor.position - muzzle).normalized().rotated(deg_to_rad((line - 1) * 7.5)) * 620
		check(projectile.position.is_equal_approx(muzzle) and projectile.velocity.is_equal_approx(expected), "volley did not share muzzle / exact angular spread")
		projectile.free()
	var before_invalid: Vector2 = aiming_actor.native_visual.get_muzzle_position()
	check(not aiming_actor.native_visual.aim_hand_at(Vector2.INF) and aiming_actor.native_visual.get_muzzle_position().is_equal_approx(before_invalid), "nonfinite aim changed rig")
	aiming_actor.weapon_lines = 1
	aiming_actor.velocity = Vector2(100, 50)
	aiming_actor.activate_build_evolution("orbital_storm")
	aiming_actor._fire()
	var grenade = aiming_shots[-1]
	var expected_grenade: Vector2 = aiming_actor.velocity * 0.30 + (volley_cursor.position - grenade.position).normalized() * 620 * 0.48
	check(grenade.velocity.is_equal_approx(expected_grenade), "real cursor grenade lost inherited / base-speed formula")
	grenade.free()
	aiming_viewport.free()
	actor.dash_active = true
	actor.dash_timer = actor.dash_duration * 0.5
	actor._update_visual_animation(0.01)
	check(view.clip == "dash", "actual dash state not bound")
	actor.dash_active = false
	check(actor.take_damage(5), "real hit fixture refused")
	actor._update_visual_animation(0.02)
	check(view.clip == "hit" and view.modulate.a == 1, "hit does not drive opaque native pose")
	actor.begin_entrance()
	actor.advance_entrance(0.2)
	check(view.clip == "entrance" and is_equal_approx(view.position.y, actor.entrance_visual_offset), "entrance body detached from real fall")
	actor.advance_entrance(2)
	actor._activate_assassin_stealth()
	actor._update_visual_animation(0.01)
	check(view.modulate.a < 1, "stealth only faded old parent drawing")
	actor.clear_runtime_modifiers()
	check(view.modulate.a == 1, "pause/clear modifiers left translucent body")
	check(actor.global_transform == start and is_equal_approx(radius, 16.9) and actor.player_collision.shape.radius == radius, "bone motion altered body transform/collision")
	actor.died.connect(func() -> void: paused = true)
	actor.health.damage(10000, true)
	check(paused and view.clip == "death", "death did not start before game-over pause")
	var health_after: float = actor.health.current_health
	actor.native_motion._process(0.3)
	var rig: Skeleton2D = view.get_node(view.facing + "/Skeleton2D")
	check(absf(rig.get_node("Torso").rotation) > 0.4 and actor.health.current_health == health_after and actor.global_transform == start, "paused death failed or advanced combat")
	check(not actor._can_fire_primary() and not view.cancel_action(), "dead player can fire/revive")
	check(not view.aim_hand_at(Vector2(300, 300)), "dead player wrist still rotates")
	paused = false
	fixture.free()
	await process_frame
	if failures == 0:
		print("TEST PASS: PlayerNativeIntegrationTest %d" % assertions)
	quit(1 if failures else 0)
