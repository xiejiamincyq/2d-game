extends SceneTree
## Real actor/director warning admission followed by a controlled 0.5s hitch.
## Isolated lifecycle fixture, not OS input, GPU performance or chapter victory.
const Player = preload("res://scripts/actors/Player.gd")
const ACTORS := [
	preload("res://scripts/actors/NurseryVineBoss.gd"),
	preload("res://scripts/actors/FoundryFurnaceBoss.gd"),
	preload("res://scripts/actors/SaltTideBoss.gd"),
	preload("res://scripts/actors/ArchiveArchivistBoss.gd"),
	preload("res://scripts/actors/EchoBellPriestBoss.gd"),
	preload("res://scripts/actors/RiftObserverBoss.gd")]
const ACTIONS := [
	[&"lash", &"roots", &"seeds"], [&"jet", &"ram", &"vents"],
	[&"ripple", &"pincer", &"salt"], [&"page", &"seal"],
	[&"bell", &"pendant", &"crown"], [&"beam", &"probes", &"refract"]]
var checks := 0
var failures := 0
var admitted := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: BossWarningHitchTest " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for chapter in ACTORS.size():
		for action in ACTIONS[chapter]:
			var host := Node2D.new(); root.add_child(host)
			var shots := Node2D.new(); host.add_child(shots)
			var player := Player.new()
			player.position = Vector2(120, -28) if action==&"pincer" else Vector2(120, 0)
			player.world_bounds = Rect2(-1000, -1000, 2000, 2000)
			host.add_child(player); player.set_physics_process(false)
			var boss = ACTORS[chapter].new(); boss.world_bounds = player.world_bounds
			boss.setup(chapter+1, shots, player); host.add_child(boss)
			boss.set_physics_process(false)
			var combat = boss.get_attack_director()
			combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
			var label := "chapter%s/%s" % [chapter+1, action]
			check(player.health.current_health==100 and player.shield==0 and not boss.death_resolved,
				"real healthy actor setup " + label)
			var armed: bool = combat.start_action(action)
			check(armed and combat.action_stage==combat.Stage.WARNING and boss.should_show_attack_marker(),
				"actual warning was not admitted " + label)
			if armed:
				admitted += 1
				var births := {"count":0}
				shots.child_entered_tree.connect(func(_shot): births.count += 1)
				var damage_attempts := {"count":0}
				player.health_changed.connect(func(value, _maximum):
					if value<100: damage_attempts.count += 1)
				var position_before: Vector2 = boss.global_position
				combat.advance(0.5)
				check(not combat.is_attacking() and combat.action_stage==combat.Stage.IDLE
					and not boss.should_show_attack_marker(), "hitch retained or activated warning " + label)
				check(player.health.current_health==100 and player.shield==0 and damage_attempts.count==0,
					"hitch dealt skipped-warning damage " + label)
				check(births.count==0 and shots.get_child_count()==0,
					"hitch released an unseen projectile " + label)
				check(boss.global_position==position_before and boss.velocity==Vector2.ZERO
					and not boss.death_resolved, "hitch moved Boss or faked death " + label)
				if combat.get("strike")!=null: check(not combat.strike.armed, "hitch left strike armed " + label)
				if combat.get("seal_attack")!=null:
					check(combat.seal_attack.centers.is_empty() and combat.seal_attack.actor==null,
						"hitch left seal armed " + label)
				if combat.get("preview_beam")!=null: check(not combat.preview_beam.armed, "hitch left preview beam armed " + label)
				print("WARNING HITCH CASE: " + label)
			host.free(); await process_frame
	check(admitted==17, "did not exercise all 17 damaging skills; admitted=%s" % admitted)
	if not failures: print("TEST PASS: BossWarningHitchTest %d; 17 real damaging-skill warnings; controlled 0.5s hitch" % checks)
	quit(1 if failures else 0)
