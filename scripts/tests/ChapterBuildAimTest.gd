extends "res://scripts/art/VerifyChapterBuildRun.gd"
## Diagnostic pointer policy fixture; not ordinary gameplay or human balance.
class Muzzle extends Node2D:
	func get_muzzle_position() -> Vector2: return global_position
class PlayerFixture extends CharacterBody2D:
	var projectile_speed := 620.0
	var active_build_evolutions := {"orbital_storm":true}
	var visual: Node2D
	func get_visual_node() -> Node2D: return visual
class DirectorFixture extends RefCounted:
	var enemies: Array = []
	func get_active_enemies() -> Array: return enemies
class ChapterFixture extends Node:
	var player: CharacterBody2D
	var director: RefCounted
func _initialize() -> void: call_deferred("aim_checks")
func aim_checks() -> void:
	check(has_method("aim_world_point"),"actual input driver lacks aim hook")
	if failures: quit(1); return
	var chapter := ChapterFixture.new()
	chapter.player = PlayerFixture.new()
	chapter.director = DirectorFixture.new()
	chapter.player.visual = Muzzle.new()
	chapter.add_child(chapter.player)
	chapter.player.add_child(chapter.player.visual)
	var enemy := CharacterBody2D.new()
	chapter.add_child(enemy)
	root.add_child(chapter)
	enemy.position = Vector2(300,0)
	chapter.player.velocity = Vector2(0,300)
	chapter.director.enemies = [enemy]
	check(call("aim_world_point",chapter,enemy.position)==enemy.position,"direct mode must remain exact baseline")
	set("aim_mode","compensated")
	var corrected: Vector2 = call("aim_world_point",chapter,enemy.position)
	check(corrected.y < -1 and corrected.is_finite(),"normal pointer counteraims inherited lateral velocity")
	check(chapter.player.velocity==Vector2(0,300) and enemy.position==Vector2(300,0),"aim policy mutated actors")
	chapter.player.active_build_evolutions.clear()
	var ordinary_corrected: Vector2 = call("aim_world_point",chapter,enemy.position)
	check(ordinary_corrected.y < corrected.y,"normal primary input accounts for its actual full inherited velocity")
	var expected_velocity: Vector2 = chapter.player.velocity + ordinary_corrected.normalized()*chapter.player.projectile_speed
	var time := 300.0 / expected_velocity.x
	check((expected_velocity*time).distance_to(enemy.position)<0.001,"normal production bullet kinematics reach stationary target")
	chapter.player.active_build_evolutions["orbital_storm"] = true
	chapter.director.enemies.clear()
	check(call("aim_world_point",chapter,Vector2(123,456))==Vector2(123,456),"no actual target retains baseline")
	chapter.free()
	if failures==0: print("TEST PASS: ChapterBuildAimTest %d"%assertions)
	quit(1 if failures>0 else 0)
