extends SceneTree
## Resource + production adapter contract, not a second-chapter combat actor.
const Motion = preload("res://scripts/components/NativeBossMotion.gd")
const SCENE := "res://scenes/actors/native/furnace_foreman_paper_v1.tscn"
class Driver extends CharacterBody2D:
	var entrance_resolved := false
	var entrance_progress := 0.5
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: FurnaceForemanPlaybackTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"exportable furnace skeleton missing")
	if failures:
		quit(1)
		return
	var host := Node2D.new()
	root.add_child(host)
	var driver := Driver.new()
	driver.position = Vector2(90,70)
	host.add_child(driver)
	var view = load(SCENE).instantiate()
	driver.add_child(view)
	var motion := Motion.new(view)
	var at: Transform2D = driver.global_transform
	motion.update(driver,0)
	check(view.player.current_animation=="entrance" and driver.global_transform==at,"adapter changes root or skips real entrance state")
	driver.entrance_resolved = true
	driver.velocity = Vector2(60,0)
	motion.update(driver,0.28)
	check(view.player.current_animation=="walk" and absf(view.skeleton.get_node("Torso/LegR/ShinR").rotation)>0.05,"production adapter cannot drive new gait")
	check(driver.global_transform==at,"resource moves collision root")
	motion.notify_hit()
	motion.update(driver,0)
	check(view.player.current_animation=="hit","real adapter doesn't sample recoil")
	motion.update(driver,0.4)
	check(view.player.current_animation=="walk","recoil doesn't settle")
	driver.velocity = Vector2.ZERO
	motion.update(driver,0.1)
	check(view.player.current_animation=="idle","locomotion gets stuck")
	view.set_facing_left(true)
	check(view.get_node("Facing").scale.x==-1 and driver.rotation==0,"mirror rotates gameplay root")
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(pose),"paused view changes")
	paused = false
	var corpse_at: Transform2D = view.global_transform
	motion.release_death(host)
	check(view.get_parent()==host and view.global_transform.is_equal_approx(corpse_at) and view.player.current_animation=="death","detached death drifts")
	view.player.advance(1.2)
	await process_frame
	check(not is_instance_valid(view),"corpse resource leaks")
	host.free()
	await process_frame
	if not failures:
		print("TEST PASS: FurnaceForemanPlaybackTest %d" % checks)
	quit(1 if failures else 0)
