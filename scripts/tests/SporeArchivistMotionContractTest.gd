extends SceneTree
## Actual native view and motion adapter. Only the combat clock is a test double.
const SCENE := "res://scenes/actors/native/spore_archivist_paper_v2.tscn"
const Motion = preload("res://scripts/components/NativeSporeArchivistMotion.gd")
class Clock extends RefCounted:
	const DURATIONS = preload("res://scripts/components/SporeArchivistAttackDirector.gd").DURATIONS
	enum Stage { IDLE,WARNING,ACTIVE,RECOVERY }
	var action: StringName = &"page"
	var action_stage := Stage.WARNING
	var action_elapsed := 0.0
	var active := true
	func is_attacking() -> bool: return active
class Driver extends CharacterBody2D:
	var entrance_resolved := true
	var entrance_progress := 1.0
	var attack_director := Clock.new()
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: SporeArchivistMotionContractTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host := Node2D.new(); root.add_child(host)
	var driver := Driver.new(); driver.position = Vector2(90,70); host.add_child(driver)
	var view = load(SCENE).instantiate(); driver.add_child(view)
	var motion = Motion.new(view); var at := driver.global_transform
	for action in [&"page",&"seal",&"brood"]:
		for stage in [Clock.Stage.WARNING,Clock.Stage.ACTIVE,Clock.Stage.RECOVERY]:
			driver.attack_director.action = action; driver.attack_director.action_stage = stage
			var clip: String = String(action)+"_"+["warning","attack","recovery"][stage-1]
			var duration: float = Clock.DURATIONS[action][stage-1]
			for fraction in [0.0,0.25,0.5,0.75,1.0]:
				driver.attack_director.action_elapsed = duration*fraction
				motion.update(driver,0)
				var expected: float = view.player.get_animation(clip).length*fraction if stage==Clock.Stage.WARNING else minf(duration*fraction,view.player.get_animation(clip).length)
				# At a non-loop endpoint Godot clears current_animation, but retains the
				# assigned clip, exact seek position and terminal pose. Interior samples
				# must still identify the running clip; no position tolerance is relaxed.
				var clip_valid: bool = view.player.assigned_animation==clip and (view.player.current_animation==clip or (fraction==1.0 and view.player.current_animation==&""))
				check(clip_valid and is_equal_approx(view.player.current_animation_position,expected),"action=%s stage=%s fraction=%s actual_clip=%s assigned_clip=%s actual_pos=%.12f expected_pos=%.12f combat_elapsed=%.12f" % [action,stage,fraction,view.player.current_animation,view.player.assigned_animation,view.player.current_animation_position,expected,driver.attack_director.action_elapsed])
				check(is_equal_approx(driver.attack_director.action_elapsed,duration*fraction) and driver.global_transform==at and not view.get_node("Warning").visible,"visual adapter owns combat, physical root or laboratory label")
	driver.attack_director.active = false; driver.velocity = Vector2(60,0); motion.update(driver,0.25)
	check(view.player.current_animation=="walk" and driver.global_transform==at,"cancelled combat fails to restore gait")
	view.sample_clip("death",0.9); driver.attack_director.active = true; motion.update(driver,0)
	check(view.player.current_animation=="death" and driver.global_transform==at,"clock sampling resurrects dead native view")
	host.free(); await process_frame
	if not failures: print("TEST PASS: SporeArchivistMotionContractTest %d" % checks)
	quit(1 if failures else 0)
