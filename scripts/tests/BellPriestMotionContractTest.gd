extends SceneTree
## Actual view/adapter with controlled clock contract, not a playable Boss.
const SCENE := "res://scenes/actors/native/bell_priest_paper_v2.tscn"
class Clock extends RefCounted:
	const Contract = preload("res://scripts/components/BellPriestAttackDirector.gd")
	const Stage = Contract.Stage
	const DURATIONS = Contract.DURATIONS
	var action: StringName = &"bell"
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
	if not ok: failures += 1; push_error("TEST FAIL: BellPriestMotionContractTest "+label)
func _initialize() -> void:
	await process_frame
	var path := "res://scripts/components/NativeBellPriestMotion.gd"
	check(ResourceLoader.exists(path),"actual priest adapter missing")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var driver := Driver.new(); driver.position = Vector2(90,70); host.add_child(driver)
	var view = load(SCENE).instantiate(); driver.add_child(view)
	var motion = load(path).new(view); var at := driver.global_transform
	motion.update(driver,0); check(view.player.current_animation=="entrance","attack overrides actual entrance")
	driver.entrance_resolved = true
	for action in [&"bell",&"pendant",&"crown"]:
		for stage in [1,2,3]:
			driver.attack_director.action = action; driver.attack_director.action_stage = stage
			driver.attack_director.action_elapsed = 0.11; motion.update(driver,0.02)
			var clip: String = String(action)+"_"+["warning","attack","recovery"][stage-1]
			check(view.player.current_animation==clip,"wrong director action/stage")
			var expected_seconds := 0.11
			if stage==Clock.Stage.WARNING:
				expected_seconds = 0.11/Clock.DURATIONS[action][0]*view.player.get_animation(clip).length
			check(is_equal_approx(view.player.current_animation_position,expected_seconds),"adapter pose does not map warning fraction/direct active seconds")
			check(driver.attack_director.action_elapsed==0.11 and driver.global_transform==at and not view.get_node("Warning").visible,"adapter owns combat/root/label")
	var before: StringName = view.player.current_animation
	for delta in [NAN,INF,-1.0]: motion.update(driver,delta); check(view.player.current_animation==before,"invalid delta changes pose")
	driver.attack_director.active = false; driver.velocity = Vector2(60,0); motion.update(driver,0.25)
	check(view.player.current_animation=="walk","idle clock does not restore gait")
	motion.notify_hit(); motion.update(driver,0); check(view.player.current_animation=="hit","normal recoil absent")
	motion.update(driver,0.5); driver.velocity = Vector2.ZERO; motion.update(driver,0.1)
	check(view.player.current_animation=="idle" and driver.global_transform==at,"ordinary pose changes physical root")
	view.sample_clip("death",0.9); driver.attack_director.active = true; motion.update(driver,0.1)
	check(view.player.current_animation=="death" and not view.cancel_action(),"director sampling resurrects dead view")
	host.free(); await process_frame
	if not failures: print("TEST PASS: BellPriestMotionContractTest %d"%checks)
	quit(1 if failures else 0)
