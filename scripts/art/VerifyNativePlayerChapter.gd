extends "res://scripts/art/VerifyNurseryChapterFlow.gd"
## Observe ordinary production input and native views; never pose the real player.
var native_observations: Array[Dictionary] = []
var health_events: Array[Dictionary] = []
var health_connected := false

func _initialize() -> void:
	output = "res://build/diagnostics/campaign-goal/native-player-chapter-v4/"
	additional_sources = ["scripts/art/VerifyNativePlayerChapter.gd", "scripts/components/NativePlayerMotion.gd", "scripts/components/NativePlayerView.gd", "scripts/effects/PlayerOcclusionOutline.gd", "assets/art/shaders/player_native_outline.gdshader", "scenes/actors/native/player_paper_v1.tscn"]
	for facing in ["front", "back", "left", "right"]:
		additional_sources.append("assets/art/actors/native/player_%s_motion_v1.tres" % facing)
	for item in ["Coin", "Heart", "Shield"]:
		additional_sources.append("scripts/pickups/%sPickup.gd" % item)
	super._initialize()

func _capture(chapter: Node, step: int, label: String) -> void:
	await super._capture(chapter, step, label)
	var actor: Node2D = chapter.player
	if not health_connected:
		health_connected = true
		actor.health_changed.connect(func(health: float, maximum: float) -> void:
			health_events.append({"frame": Engine.get_physics_frames(), "health": health, "maximum": maximum,
				"position": [actor.position.x, actor.position.y], "encounter_state": chapter.director.state})
			print("NATIVE PLAYER HEALTH frame=%d HP=%.1f" % [Engine.get_physics_frames(), health])
		)
	var body: Node2D = actor.get_visual_node()
	check(body.scene_file_path.ends_with("player_paper_v1.tscn"), "ordinary chapter uses legacy player")
	check(actor.player_body_texture == null and actor.player_weapon_texture == null, "ordinary chapter loaded legacy player atlases")
	check(is_equal_approx(body.modulate.a, 0.42 if actor.is_stealthed() else 1.0), "native body opacity disagrees with actual stealth")
	native_observations.append({"step": step, "label": label, "facing": body.facing, "clip": body.clip,
		"alpha": body.modulate.a, "radius": actor.get_body_radius(), "velocity": [actor.velocity.x, actor.velocity.y],
		"muzzle": [body.get_muzzle_position().x, body.get_muzzle_position().y],
		"leg_rotation": body.get_node(body.facing + "/Skeleton2D/Torso/LegL").rotation})

func additional_report() -> Dictionary:
	return {"native_player": native_observations, "health_events": health_events, "native_scope": "Actual four-view player observed in independently seeded first chapter; source-bound GPU screenshots, not isolated body alpha or human acceptance; Boss remains transitional"}

func pilot_motion(chapter: Node, policy: RefCounted, step: int, threats: Array[Vector2], telegraph: Node, danger_distance: float) -> Dictionary:
	var position: Vector2 = chapter.player.position
	var goal := Vector2.RIGHT.rotated(step / 180.0)
	var boss = chapter.director.get_active_boss()
	if boss != null:
		var offset: Vector2 = position - boss.global_position
		goal = offset.normalized().orthogonal() + offset.normalized() * clampf((350 - offset.length()) / 80, -2, 2)
	# Use visible loot via normal navigation/collection, never credit rewards or HP.
	var loot: Node2D = null
	var closest := INF
	for item: Node2D in chapter.pickups.get_children():
		if item.is_queued_for_deletion():
			continue
		var script: String = item.get_script().resource_path
		var wanted: bool = chapter.director.state == chapter.director.State.COLLECT or (script.ends_with("HeartPickup.gd") and chapter.player.health.current_health < 80) or (script.ends_with("ShieldPickup.gd") and chapter.player.shield < chapter.player.max_shield)
		var distance := position.distance_squared_to(item.position)
		if wanted and distance < closest:
			closest = distance
			loot = item
	if loot != null:
		goal = chapter.map.layout.get_navigation_direction(position, loot.position, chapter.player.get_body_radius())
	# Visible warning fields are danger, not impassable terrain. A player already
	# inside a field must still be able to walk out instead of rejecting all axes.
	if telegraph != null and telegraph.is_attacking():
		if telegraph.attack_kind == telegraph.AttackKind.SWEEP:
			for radius in [100.0, 200.0, 300.0]:
				for angle in [-0.3, 0.0, 0.3]:
					threats.append(boss.global_position + Vector2.RIGHT.rotated(telegraph.sweep_angle + angle) * radius)
			if telegraph.is_point_in_sweep(position):
				danger_distance = 0
		else:
			for target: Vector2 in telegraph.get_slam_targets():
				danger_distance = minf(danger_distance, position.distance_to(target))
	var direction: Vector2 = policy.choose_direction(position, goal, threats, func(point: Vector2) -> bool:
		return chapter.map.layout.is_position_walkable(point, chapter.player.get_body_radius())
	)
	return {"direction": direction, "dash": danger_distance < 100}
