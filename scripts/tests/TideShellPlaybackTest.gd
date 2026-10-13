extends SceneTree
## Production view/adapter consumption, not third-chapter gameplay.
const Motion = preload("res://scripts/components/NativeBossMotion.gd")
const SCENE := "res://scenes/actors/native/tide_shell_paper_v1.tscn"
class Driver extends CharacterBody2D:
	var entrance_resolved := false
	var entrance_progress := 0.5
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: TideShellPlaybackTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"packed crab view missing")
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
	check(view.skeleton.get_bone_count()==25 and view.get_node("Facing/Skin").get_bone_count()==25,"serialized skeleton/weights lost")
	check(view.visual_bounds_padding==16,"export drops reviewed motion bounds")
	var motion := Motion.new(view)
	var at: Transform2D = driver.global_transform
	motion.update(driver,0)
	check(view.player.current_animation=="entrance" and driver.global_transform==at,"adapter skips entrance or changes root")
	driver.entrance_resolved = true
	driver.velocity = Vector2(60,0)
	motion.update(driver,0.2)
	check(view.player.current_animation=="walk" and absf(view.skeleton.get_node("Torso/LegBR/ShinBR").rotation)>0.05,"adapter doesn't drive multi-leg gait")
	check(driver.global_transform==at,"visual moves collision root")
	motion.notify_hit()
	motion.update(driver,0)
	check(view.player.current_animation=="hit","recoil not sampled")
	motion.update(driver,0.4)
	check(view.player.current_animation=="walk","recoil stuck")
	driver.velocity = Vector2.ZERO
	motion.update(driver,0.1)
	check(view.player.current_animation=="idle","idle recovery absent")
	view.set_facing_left(true)
	check(view.get_node("Facing").scale.x==-1 and driver.rotation==0,"gameplay root spins")
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(pose),"paused joints change")
	paused = false
	var corpse_at: Transform2D = view.global_transform
	motion.release_death(host)
	check(view.get_parent()==host and view.global_transform.is_equal_approx(corpse_at) and view.player.current_animation=="death","death detachment drifts")
	view.player.advance(1.2)
	await process_frame
	check(not is_instance_valid(view),"crab corpse leaks")
	host.free()
	await process_frame
	if not failures:
		print("TEST PASS: TideShellPlaybackTest %d" % checks)
	quit(1 if failures else 0)
