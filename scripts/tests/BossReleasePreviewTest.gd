extends SceneTree
## A real new terrain body blocks the articulated socket after warning admission.
const Gate = preload("res://scripts/components/BossEscapeGate.gd")
const Player = preload("res://scripts/actors/Player.gd")
const CASES := [[preload("res://scripts/actors/NurseryVineBoss.gd"),&"seeds"],[preload("res://scripts/actors/FoundryFurnaceBoss.gd"),&"jet"],[preload("res://scripts/actors/SaltTideBoss.gd"),&"salt"],[preload("res://scripts/actors/ArchiveArchivistBoss.gd"),&"page"],[preload("res://scripts/actors/RiftObserverBoss.gd"),&"beam"]]
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BossReleasePreviewTest "+label)
func run() -> void:
	for entry in CASES:
		var host := Node2D.new(); root.add_child(host)
		var shots := Node2D.new(); host.add_child(shots)
		var player := Player.new(); player.position = Vector2(150,0); host.add_child(player); player.set_physics_process(false)
		var boss = entry[0].new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000)
		boss.setup(1,shots,player); host.add_child(boss); boss.set_physics_process(false)
		var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
		var kind: StringName = entry[1]
		check(combat.start_action(kind),"clear warning rejected "+String(kind))
		if not combat.is_attacking(): host.free(); await process_frame; continue
		var origin := Vector2.ZERO
		match kind:
			&"seeds": origin = combat.seed_warning_paths[0]
			&"jet": origin = combat.warning_origin
			&"salt": origin = combat.warning_paths[0]
			&"page": origin = combat.locked_origin
			&"beam": origin = combat.preview_beam.origin
		check(origin.is_finite() and origin.distance_to(boss.global_position)>0.01,"fixture did not use articulated socket "+String(kind))
		var wall := StaticBody2D.new(); wall.position = origin; wall.collision_layer = 1|2
		var collision := CollisionShape2D.new(); var circle := CircleShape2D.new(); circle.radius = 4
		collision.shape = circle; wall.add_child(collision); host.add_child(wall)
		await physics_frame; await physics_frame
		check(Gate.route_still_clear(boss,player,combat.escape_route),"socket obstacle accidentally tests player path, not release "+String(kind))
		var remaining: float = combat.DURATIONS[kind][0]+0.02
		while remaining>0.000001 and combat.is_attacking():
			var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
		check(not combat.is_attacking() and shots.get_child_count()==0 and player.health.current_health==100,"unmarked replacement origin fired "+String(kind))
		host.free(); await process_frame
	if not failures: print("TEST PASS: BossReleasePreviewTest %d" % checks)
	quit(1 if failures else 0)
