extends SceneTree

const Enemy = preload("res://scripts/actors/Enemy.gd")
var assertions := 0
var holder: Node2D

func require_condition(condition: bool, message: String) -> bool:
	assertions += 1
	if not condition:
		push_error("TEST FAIL: LateCrowdLedgerTest: " + message)
		if holder != null:
			holder.free()
		quit(1)
	return condition

func _initialize() -> void:
	if not require_condition(FileAccess.file_exists("res://scripts/art/LateCrowdLedger.gd"), "observer API not implemented"):
		return
	_run.call_deferred()

func _run() -> void:
	var Observer = load("res://scripts/art/LateCrowdLedger.gd")
	holder = Node2D.new()
	root.add_child(holder)
	var actors: Array = []
	for point in [Vector2(20, 20), Vector2(110, 20), Vector2(300, 20), Vector2(60, 60), Vector2(70, 70)]:
		var actor = Enemy.new()
		actor.setup(Enemy.EnemyKind.LOBBER, 3, null)
		holder.add_child(actor)
		actor.set_physics_process(false)
		actor.position = point
		actors.append(actor)
	actors[3].health.current_health = 0
	actors[4].queue_free()
	var freed = Enemy.new()
	freed.free()
	actors.append(freed)
	actors.append(actors[0]) # Duplicate director entry must not count twice.
	var snapshot: Dictionary = Observer.entities(actors, Transform2D.IDENTITY, Rect2(0, 0, 100, 100), Vector2.ZERO, 13.0)
	if not require_condition(snapshot.bodies.size() == 3, "dead/queued/freed/duplicate nodes counted"):
		return
	if not require_condition(snapshot.visible == 2, "partly visible collision AABB was missed"):
		return
	if not require_condition(snapshot.kinds.get("LOBBER") == 3 and snapshot.bodies[0].radius == 17.0, "actual kind/body radius missing"):
		return
	if not require_condition(snapshot.bodies[0].screen_rect == [3.0, 3.0, 34.0, 34.0], "body AABB not bound to transform"):
		return
	var ledger = Observer.new()
	ledger.observe_value("health", 100.0, {"state":"SETTLEMENT"})
	ledger.observe_value("health", 90.0, {"state":"PLAYING"})
	ledger.observe_value("health", 100.0, {"state":"PLAYING"})
	ledger.observe_value("health", 95.0, {"state":"PLAYING"})
	if not require_condition(ledger.health_loss == 15.0, "healing masked accumulated damage"):
		return
	ledger.observe_value("shield", 20.0, {"state":"PLAYING"})
	ledger.observe_value("shield", 0.0, {"state":"PLAYING"})
	if not require_condition(ledger.shield_loss == 20.0 and ledger.events.size() == 4, "shield/event ledger mismatch"):
		return
	if not require_condition(not Observer.eligible({"state":"PLAYING","wave":1,"boss":false,"collection":false}), "opening accepted as late"):
		return
	for flags in [{"state":"SETTLEMENT","wave":4,"boss":false,"collection":false}, {"state":"PLAYING","wave":4,"boss":true,"collection":false}, {"state":"PLAYING","wave":4,"boss":false,"collection":true}]:
		if not require_condition(not Observer.eligible(flags), "nonordinary late phase accepted"):
			return
	if not require_condition(Observer.eligible({"state":"PLAYING","wave":6,"boss":false,"collection":false}), "ordinary sixth wave rejected"):
		return
	var buffer = Observer.new()
	if not require_condition(buffer.has_method("consider_peak"), "peak window API not implemented"):
		return
	for index in range(200):
		var info := {"index":index+1, "wall":index*0.1, "segment":1,
			"eligible":true, "live":10 if index < 40 else 20, "visible":5}
		buffer.consider_peak(info)
		buffer.retain_capture({"id":index+1,"record":{"wall":index*0.1, "segment":1,"frame":index+1}})
	if not require_condition(buffer.peak.index == 41 and buffer.visible_peak.index == 1, "peak tie did not keep earliest physics step"):
		return
	if not require_condition(buffer.max_retained <= 120 and buffer.candidate.size() > 50, "window is unbounded or empty"):
		return
	for entry in buffer.candidate:
		if not require_condition(absf(entry.record.wall - buffer.peak.wall) <= 3.0 + 0.000001, "retained frame outside six-second peak window"):
			return
	holder.free()
	print("TEST PASS: LateCrowdLedgerTest %d" % assertions)
	quit(0)
