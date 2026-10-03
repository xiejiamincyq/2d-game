extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const LaserScript = preload("res://scripts/components/LaserBeam.gd")
const ProjectileScript = preload("res://scripts/components/Projectile.gd")

class FixtureMain extends MainScript:
	func _ready() -> void:
		pass # Only exercise the real boundary method; never create a snapshot store/audio/UI.

var assertions := 0
var fixture: Node

func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: DroneVisualLifecycleTest: " + message)
	fixture.free()
	quit(1)
	return false

func _initialize() -> void:
	fixture = FixtureMain.new()
	root.add_child(fixture)
	fixture.set_process(false)
	fixture.projectiles = Node2D.new()
	fixture.pickups = Node2D.new()
	fixture.add_child(fixture.projectiles)
	fixture.add_child(fixture.pickups)
	fixture.player = PlayerScript.new()
	fixture.player.projectile_parent = fixture.projectiles
	fixture.player.world_bounds = MainScript.WORLD_BOUNDS
	fixture.player.set_physics_process(false)
	fixture.add_child(fixture.player)
	await process_frame
	var player: Node = fixture.player
	player.drone_count = 2
	player._sync_drone_visuals()
	player.global_position = Vector2(MainScript.WORLD_BOUNDS.end.x - player.get_body_radius(), 0)
	player.drone_lasers[0].setup(player.global_position + Vector2(48, 0), player.global_position, Color.WHITE)
	player.drone_lasers[1].setup(player.global_position - Vector2(48, 0), player.global_position, Color.WHITE)
	player.drone_reticles[0].global_position = Vector2(MainScript.WORLD_BOUNDS.end.x + 30, 0)
	player.drone_reticles[1].global_position = player.global_position
	var transient: Node2D = LaserScript.new()
	fixture.projectiles.add_child(transient)
	transient.global_position = Vector2(MainScript.WORLD_BOUNDS.end.x + 30, 0)
	var bullet: Node2D = ProjectileScript.new()
	bullet.set_physics_process(false)
	fixture.projectiles.add_child(bullet)
	bullet.global_position = transient.global_position
	fixture._enforce_world_bounds()
	if not _check(not player.drone_lasers[0].is_queued_for_deletion(), "boundary cleanup deleted a persistent orbit beam"):
		return
	if not _check(not player.drone_reticles[0].is_queued_for_deletion(), "boundary cleanup deleted a tracked reticle"):
		return
	if not _check(transient.is_queued_for_deletion() and bullet.is_queued_for_deletion(), "transient projectile cleanup was weakened"):
		return
	await process_frame
	await process_frame
	if not _check(is_instance_valid(player.drone_lasers[0]) and is_instance_valid(player.drone_reticles[0]), "owned visual disappeared after deferred cleanup"):
		return
	player._update_drone_lasers(1.0 / 60.0)
	if not _check(player.drone_lasers.size() == 2 and not player.drone_lasers[0].visible, "no-target update corrupted beam slots"):
		return
	player.drone_count = 0
	player._sync_drone_visuals()
	if not _check(player.drone_lasers.is_empty() and player.drone_reticles.is_empty(), "drone removal kept owned visual references"):
		return
	await process_frame
	await process_frame
	if not _check(fixture.projectiles.get_child_count() == 0, "owned visuals leaked after removing drones"):
		return
	fixture.free()
	await process_frame
	print("TEST PASS: DroneVisualLifecycleTest %d" % assertions)
	quit(0)
