extends SceneTree
## Actual view/adapter with controlled clock contract, not a playable Boss.
const SCENE := "res://scenes/actors/native/rift_observer_paper_v2.tscn"
class Clock extends RefCounted:
	const DURATIONS = preload("res://scripts/components/RiftObserverAttackDirector.gd").DURATIONS
	enum Stage { IDLE,WARNING,ACTIVE,RECOVERY }
	var action: StringName = &"beam"
	var action_stage := 1
	var action_elapsed := 0.0
	var active := true
	func is_attacking() -> bool: return active
class Driver extends CharacterBody2D:
	var entrance_resolved := false
	var entrance_progress := 0.5
	var attack_director := Clock.new()
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverMotionContractTest "+label)
func _initialize() -> void:
	await process_frame
	var path := "res://scripts/components/NativeRiftObserverMotion.gd"
	check(ResourceLoader.exists(path),"actual observer adapter missing")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var driver := Driver.new(); driver.position = Vector2(90,70); host.add_child(driver)
	var view = load(SCENE).instantiate(); driver.add_child(view)
	var motion = load(path).new(view); var at := driver.global_transform
	motion.update(driver,0); check(view.player.current_animation=="entrance","attack overrides actual entrance")
	driver.entrance_resolved = true
	for action in [&"beam",&"probes",&"refract"]:
		for stage in [1,2,3]:
			driver.attack_director.action = action; driver.attack_director.action_stage = stage
			driver.attack_director.action_elapsed = 0.11; motion.update(driver,0.02)
			check(view.player.current_animation==String(action)+"_"+["warning","attack","recovery"][stage-1],"wrong director action/stage")
			check(driver.attack_director.action_elapsed==0.11 and driver.global_transform==at and not view.get_node("Warning").visible,"adapter owns combat/root/label")
	# Slower combat warnings map all fractions to the original serialized pose.
	for action in [&"beam",&"probes",&"refract"]:
		driver.attack_director.action = action; driver.attack_director.action_stage = Clock.Stage.WARNING
		var clip: String = String(action)+"_warning"
		var duration: float = Clock.DURATIONS[action][0]
		for fraction in [0.0,0.25,0.5,0.75,1.0]:
			driver.attack_director.action_elapsed = duration*fraction; motion.update(driver,0)
			check(is_equal_approx(view.player.current_animation_position,view.player.get_animation(clip).length*fraction),"warning does not normalize combat time onto serialized clip")
			check(is_equal_approx(driver.attack_director.action_elapsed,duration*fraction) and driver.global_transform==at,"normalization mutates director or root")
	var before: StringName = view.player.current_animation
	for delta in [NAN,INF,-1.0]: motion.update(driver,delta); check(view.player.current_animation==before,"invalid delta changes pose")
	var frozen_pose: Transform2D = view.skeleton.get_bone(0).transform
	for pair in [["action",&"legacy_overseer"],["action_stage",0],["action_stage",4],["action_elapsed",NAN],["action_elapsed",INF],["action_elapsed",-1.0]]:
		var old_value = driver.attack_director.get(pair[0]); driver.attack_director.set(pair[0],pair[1]); motion.update(driver,0.1)
		check(view.skeleton.get_bone(0).transform.is_equal_approx(frozen_pose) and driver.global_transform==at,"invalid clock changes pose/root")
		driver.attack_director.set(pair[0],old_value)
	driver.attack_director.active = false; driver.velocity = Vector2(60,0); motion.update(driver,0.25)
	check(view.player.current_animation=="walk","idle clock does not restore gait")
	motion.notify_hit(); motion.update(driver,0); check(view.player.current_animation=="hit","normal recoil absent")
	motion.update(driver,0.5); driver.velocity = Vector2.ZERO; motion.update(driver,0.1)
	check(view.player.current_animation=="idle" and driver.global_transform==at,"ordinary pose changes physical root")
	view.sample_clip("death",0.9); driver.attack_director.active = true; motion.update(driver,0.1)
	check(view.player.current_animation=="death" and not view.cancel_action(),"director sampling resurrects dead view")
	host.free(); await process_frame
	if not failures: print("TEST PASS: RiftObserverMotionContractTest %d"%checks)
	quit(1 if failures else 0)
