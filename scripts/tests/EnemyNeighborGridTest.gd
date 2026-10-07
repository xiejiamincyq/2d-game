extends SceneTree

const DirectorScript = preload("res://scripts/systems/WaveDirector.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
var assertions := 0
var failures := 0

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("TEST FAIL: EnemyNeighborGridTest: " + message)

func query(director: Node, subject: Node2D) -> Array[Node]:
	if director.has_method("_get_enemy_neighbors"):
		return director._get_enemy_neighbors(subject)
	return director.get_active_enemies()

func _initialize() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var director := DirectorScript.new()
	fixture.add_child(director)
	director.set_process(false)
	var subject := EnemyScript.new()
	fixture.add_child(subject)
	subject.set_physics_process(false)
	director.active_enemies.append(subject)
	for index in range(512):
		var other := EnemyScript.new()
		other.position = Vector2(1500 + (index % 32) * 300, (index / 32) * 300)
		fixture.add_child(other)
		other.set_physics_process(false)
		director.active_enemies.append(other)
	var near: Node2D = director.active_enemies[1]
	near.position = Vector2(239, 0)
	var dead: Node2D = director.active_enemies[2]
	dead.position = Vector2(20, 0)
	dead.death_resolved = true
	var queued: Node2D = director.active_enemies[3]
	queued.position = Vector2(-20, 0)
	queued.queue_free()
	var first := query(director, subject)
	check(first.size() == 1 and first.has(near), "query includes self, distant, dead or queued bodies")
	check(director.has_method("_get_enemy_neighbors"), "director still provides full-world array")
	if director.has_method("_get_enemy_neighbors"):
		check(director.neighbor_grid.last_candidate_count < 30, "spread population scanned full 513-body array")
		var rebuilds: int = director.neighbor_grid.rebuild_count
		query(director, near)
		check(director.neighbor_grid.rebuild_count == rebuilds, "index rebuilt per enemy rather than per physics frame")
		near.position = Vector2(241, 0)
		check(query(director, subject).is_empty(), "live radius filter retained moved-out peer")
		near.position = Vector2(239, 0)
		check(query(director, subject).has(near), "live radius filter lost moved-in peer")
		var born := EnemyScript.new()
		fixture.add_child(born)
		born.set_physics_process(false)
		born.position = Vector2(-100, 0)
		director.active_enemies.append(born)
		check(query(director, subject).has(born), "same-frame birth omitted from index")
		born.free()
		check(query(director, subject).size() == 1, "freed body in cached cell was not filtered")
		near.position = Vector2(800, 0)
		await physics_frame
		check(query(director, subject).is_empty(), "next physics frame kept stale spatial position")
		director.active_enemies.clear()
		check(query(director, subject).is_empty(), "cleared wave retained previous spatial cells")
	fixture.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("TEST PASS: EnemyNeighborGridTest %d" % assertions)
	quit(0 if failures == 0 else 1)
