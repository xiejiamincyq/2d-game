extends "res://scripts/art/VerifyNativePlayerChapter.gd"
## Read-only driver's visible attack perception; not gameplay victory evidence.
class Warning extends RefCounted:
	enum Stage { IDLE, WARNING, ACTIVE, RECOVERY }
	var action_stage := Stage.WARNING
	var action_elapsed := 0.0
	var action: StringName = &"roots"
	var root_centers: Array[Vector2] = [Vector2(30, 0)]
	var lash_points := PackedVector2Array([Vector2(80, 20)])
class Boss extends Node2D:
	var attack_director: RefCounted
class Director extends RefCounted:
	var boss: Node2D
	func get_active_boss() -> Node2D: return boss
class PlayerHost extends Node2D: pass
class Chapter extends RefCounted:
	var director: RefCounted
	var projectiles: Node
	var player: Node2D

func _initialize() -> void: call_deferred("threat_checks")
func threat_checks() -> void:
	check(has_method("native_visible_threats"), "driver cannot read current Vine warnings and seed flight")
	if failures: quit(1); return
	var chapter := Chapter.new()
	var director := Director.new()
	var boss := Boss.new()
	var warning := Warning.new()
	boss.attack_director = warning
	director.boss = boss
	chapter.director = director
	chapter.player = PlayerHost.new()
	chapter.projectiles = Node.new()
	root.add_child(chapter.player)
	root.add_child(chapter.projectiles)
	root.add_child(boss)
	var threats: Array[Vector2] = []
	check(call("native_visible_threats", chapter, threats, INF) == INF and threats.is_empty(), "driver reacts before warning has been visible")
	warning.action_elapsed = 0.15
	check(is_equal_approx(call("native_visible_threats", chapter, threats, INF), 30.0) and threats == [Vector2(30, 0)], "visible roots are not perceived")
	threats.clear()
	warning.action = &"lash"
	call("native_visible_threats", chapter, threats, INF)
	check(threats == [Vector2(80, 20)], "visible lash geometry ignored")
	warning.action_stage = Warning.Stage.RECOVERY
	threats.clear()
	var seed := SeedFlight.new()
	seed.position = Vector2(60, 0)
	seed.velocity = Vector2(-100, 0)
	chapter.projectiles.add_child(seed)
	var at := seed.position
	var velocity := seed.velocity
	check(is_equal_approx(call("native_visible_threats", chapter, threats, INF), 42.0), "actual seed flight future not perceived")
	check(threats == [Vector2(60, 0), Vector2(42, 0)], "recovery warning persists or seed future wrong")
	check(seed.position == at and seed.velocity == velocity and warning.action_stage == Warning.Stage.RECOVERY, "driver mutates combat instead of observing")
	seed.position = Vector2(600, 0)
	threats.clear()
	call("native_visible_threats", chapter, threats, INF)
	check(threats.is_empty(), "driver reads distant invisible seed")
	chapter.player.free()
	chapter.projectiles.free()
	boss.free()
	await process_frame
	if not failures: print("TEST PASS: NativeChapterPilotThreatTest %d" % assertions)
	quit(1 if failures else 0)
