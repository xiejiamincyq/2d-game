extends SceneTree
## Real animated bone trajectory, controlled hitch; not navigation/gameplay.
const Director = preload("res://scripts/components/TideShellAttackDirector.gd")
const Body = preload("res://scenes/actors/native/tide_shell_paper_v2.tscn")
class Target extends CharacterBody2D:
	var hits := 0
	func is_alive() -> bool: return true
	func get_body_radius() -> float: return 13.0
	func take_damage(_amount: float,_source: StringName = &"") -> void: hits += 1
class Driver extends CharacterBody2D:
	var world_bounds := Rect2(-1000,-1000,2000,2000)
	var death_resolved := false
	var body_radius := 56.0
	var body: Node2D
	var combat: Node
	func get_claw_origins() -> Array[Vector2]:
		return [body.get_node("Facing/Skeleton2D/Torso/ShoulderL/ArmL/PincerL/ClawOrigin").global_position,body.get_node("Facing/Skeleton2D/Torso/ShoulderR/ArmR/PincerR/ClawOrigin").global_position]
	func _update_boss_motion(_delta: float) -> void:
		if combat.is_attacking():
			var clip: String = String(combat.action)+"_"+["warning","attack","recovery"][combat.action_stage-1]
			var elapsed: float = combat.action_elapsed
			if combat.action_stage==combat.Stage.WARNING:
				elapsed = elapsed/combat.DURATIONS[combat.action][0]*body.player.get_animation(clip).length
			body.sample_clip(clip,elapsed)
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: TideShellClawSweepTest "+label)
func _initialize() -> void: call_deferred("run")
func advance_warning(combat: Node,seconds: float = -1.0) -> void:
	var remaining: float = combat.DURATIONS[combat.action][0] if seconds<0 else seconds
	while remaining>0.0000001:
		var step := minf(1.0/120.0,remaining)
		combat.advance(step)
		remaining -= step

func run() -> void:
	for left in [false,true]:
		var host := Node2D.new(); root.add_child(host)
		var boss := Driver.new(); host.add_child(boss)
		boss.body = Body.instantiate(); boss.add_child(boss.body); boss.body.set_facing_left(left)
		boss.body.sample_clip("pincer_attack",0)
		var charged: Vector2 = boss.get_claw_origins()[0]
		boss.body.sample_clip("pincer_attack",0.10)
		var impact: Vector2 = boss.get_claw_origins()[0]
		var target := Target.new(); target.position = impact+(impact-charged).normalized()*30; host.add_child(target)
		check(target.position.distance_to(charged)>35,"fixture overlaps initial charged tip")
		boss.combat = Director.new(); boss.add_child(boss.combat); boss.combat.configure(boss,target,null)
		boss.combat.advance(1.4); boss.combat.attack_gap = 99
		check(boss.combat.start_action(&"pincer"),"actual curve cannot arm")
		advance_warning(boss.combat)
		check(target.hits==0,"initial overlap invalidates curved-path test")
		boss.combat.advance(0.36*0.52)
		check(target.hits==1,"hitch skips curved stroke returning to charged pose")
		boss.combat.advance(0.36)
		check(target.hits==1,"two strokes repeat same cast")
		host.free(); await process_frame
	if not failures: print("TEST PASS: TideShellClawSweepTest %d" % checks)
	quit(1 if failures else 0)
