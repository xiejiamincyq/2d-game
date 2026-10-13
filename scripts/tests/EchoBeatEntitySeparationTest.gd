extends SceneTree
## Controlled lifecycle/damage-resolution cases, not gameplay escape evidence.
## Real map, actors and direct-space queries; actor layers are never changed.
const Map = preload("res://scenes/world/echo_court.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const Beat = preload("res://scripts/world/EchoBeat.gd")
const Health = preload("res://scripts/components/HealthComponent.gd")

class DamageTarget extends Node2D:
	var health: Node
	var hits := 0
	func _ready() -> void:
		health = Health.new(); health.max_health = 100; add_child(health)
	func get_body_radius() -> float: return 16.9
	func take_damage(amount: float, _source: StringName) -> void:
		if health.damage(amount): hits += 1

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoBeatEntitySeparationTest "+label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func collision_body(body: CollisionObject2D, radius: float) -> CollisionObject2D:
	var shape := CircleShape2D.new(); shape.radius = radius
	var collision := CollisionShape2D.new(); collision.shape = shape; body.add_child(collision)
	return body
func wall_at(host: Node2D, at: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new(); wall.position = at
	var shape := RectangleShape2D.new(); shape.size = Vector2(2, 60)
	var collision := CollisionShape2D.new(); collision.shape = shape; wall.add_child(collision)
	host.add_child(wall); return wall
func run() -> void:
	for role in ["echo_sentinel", "circling_shade"]:
		var host := Node2D.new(); root.add_child(host)
		var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
		var anchor: Vector2 = map.layout.get_echo_sites()[0]
		var player := Player.new(); player.position = anchor+Vector2(0,150)
		player.world_bounds = map.layout.world_bounds; host.add_child(player)
		player.set_physics_process(false)
		var enemy = Factory.create_actor(5,role,0,host,player)
		enemy.position = anchor; enemy.world_bounds = map.layout.world_bounds; host.add_child(enemy)
		enemy.set_physics_process(false)
		var beat := Beat.new(); host.add_child(beat); beat.set_physics_process(false)
		await tick(); await tick()
		check(enemy.collision_layer==1 and player.collision_layer==1,"real actors no longer exercise normal layer1")
		var before_health: float = enemy.health.current_health
		var enemies := get_nodes_in_group(&"enemies").size()
		beat.configure(map.layout,player,anchor,Vector2.RIGHT); beat.set_enabled(true)
		check(beat.enabled,"ordinary %s occupying first disk is misclassified as terrain"%role)
		beat.advance(0.01)
		check(beat.enabled,"ordinary %s cancels enabled clock"%role)
		beat.set_enabled(false); enemy.position = anchor+Vector2(0,-80); await tick(); await tick()
		beat.set_enabled(true); check(beat.enabled,"clear reserved disk cannot arm")
		var old_position: Vector2 = enemy.position
		enemy.move_and_collide(Vector2(0,80)); await tick(); await tick()
		check(enemy.position.distance_to(old_position)>60 and enemy.position.distance_to(anchor)<1,"real actor sweep never enters disk")
		beat.advance(0.01)
		check(beat.enabled,"moving %s onto disk incorrectly cancels pair"%role)
		check(enemy.health.current_health==before_health and get_nodes_in_group(&"enemies").size()==enemies and not beat.is_in_group(&"enemies"),"hazard changes enemy HP or creates reward-bearing actor")
		host.free(); await process_frame
	# Default-layer-1 unlisted thin StaticBody remains terrain, including beat2.
	var host := Node2D.new(); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var anchor: Vector2 = map.layout.get_echo_sites()[0]
	var player := Player.new(); player.position = anchor+Vector2(0,150); host.add_child(player); player.set_physics_process(false)
	var beat := Beat.new(); host.add_child(beat); beat.set_physics_process(false)
	await tick(); await tick(); beat.configure(map.layout,player,anchor,Vector2.RIGHT)
	for center in beat.get_beat_centers():
		var wall := wall_at(host,center); await tick(); await tick()
		check(wall.collision_layer==1,"unexpected wall fixture does not exercise legacy static layer")
		beat.set_enabled(true); check(not beat.enabled and beat.state==Beat.State.INACTIVE,"thin static wall at either disk does not veto whole pair")
		wall.free(); await tick(); await tick()
	beat.set_enabled(true); beat.advance(3.4); beat.advance(0.4); beat.advance(0.12)
	check(beat.enabled and beat.state==Beat.State.WARNING_SECOND,"controlled second-warning fixture never arms")
	var late_wall := wall_at(host,beat.get_beat_centers()[1]); await tick(); await tick(); beat.advance(0.01)
	check(not beat.enabled and beat.state==Beat.State.INACTIVE,"new thin terrain during second warning does not cancel pair")
	late_wall.free(); host.free(); await process_frame
	# Isolate hit resolution from arming. An actual CharacterBody between stamp
	# and explicit real-Health target is not a terrain shield. Phase advancement
	# is controlled and happens BEFORE adding the actor or moving the target.
	host = Node2D.new(); root.add_child(host)
	map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	anchor = map.layout.get_echo_sites()[0]
	var target := DamageTarget.new(); target.position = anchor+Vector2(0,150); host.add_child(target)
	beat = Beat.new(); host.add_child(beat); beat.set_physics_process(false)
	await tick(); await tick(); beat.configure(map.layout,target,anchor,Vector2.RIGHT); beat.set_enabled(true)
	beat.advance(3.4); beat.advance(0.4)
	check(beat.state==Beat.State.PULSE_FIRST and not beat.attempted,"isolated pulse is not live before ray fixture")
	var blocker := CharacterBody2D.new(); collision_body(blocker,4); blocker.position = anchor+Vector2(12,0); host.add_child(blocker)
	target.position = anchor+Vector2(24,0); await tick(); await tick()
	check(blocker.collision_layer==1 and target.health.current_health==100,"ray fixture modified layer or damages target before resolution")
	beat._try_damage()
	check(target.hits==1 and target.health.current_health==82 and beat.attempted,"ordinary CharacterBody wrongly shields target from ground pulse")
	beat._try_damage(); check(target.hits==1,"same pulse repeats damage after accepted hit")
	# A moving actor must not hide the static wall behind it in the ray results.
	var shield := wall_at(host,anchor+Vector2(18,0)); await tick(); await tick()
	beat.attempted = false; beat._try_damage()
	check(target.hits==1 and not beat.attempted,"ignored moving actor also bypasses thin wall behind it")
	shield.free(); await tick(); await tick()
	beat._try_damage()
	check(target.hits==2 and target.health.current_health==64 and beat.attempted,"removing wall does not restore one ground hit through actor")
	# Query saturation is unsafe: an unseen static result must not be ignored.
	target.position = anchor+Vector2(0,150)
	for index in 33:
		var crowded := CharacterBody2D.new(); collision_body(crowded,2)
		crowded.position = anchor+Vector2(index%5,index/5); host.add_child(crowded)
	await tick(); await tick(); beat.set_enabled(false); beat.set_enabled(true)
	check(not beat.enabled,"saturated body query silently hides potential terrain")
	host.free(); await process_frame
	if not failures: print("TEST PASS: EchoBeatEntitySeparationTest %d"%checks)
	quit(1 if failures else 0)
