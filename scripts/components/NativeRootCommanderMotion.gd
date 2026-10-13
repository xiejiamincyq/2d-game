extends "res://scripts/components/NativeLargeMotion.gd"
## Authoritative combat clocks select poses; animation never fires projectiles.
const OriginSafety := preload("res://scripts/components/NativeProjectileOriginSafety.gd")
const CORE := "Facing/Skeleton2D/Torso/Core/CommandOrigin"
const MELEE_IMPACT := 0.12
const BURST_RECOVERY := 0.3
const COMMAND_DURATION := 0.35
var command_time := COMMAND_DURATION

func notify_command() -> void:
	command_time = 0

func cancel_actions() -> void:
	command_time = COMMAND_DURATION

func get_safe_core_origin(actor: CharacterBody2D) -> Vector2:
	return OriginSafety.resolve(actor,view.get_node(CORE).global_position,5)

func update(actor: CharacterBody2D,delta: float) -> void:
	if not is_finite(delta) or delta<0:
		return
	command_time += delta
	if actor.spawn_impulse_remaining<=0 and actor.get_target_player()!=null:
		var clip := ""
		var at := 0.0
		if actor.ranged_is_winding_up:
			clip = "burst_warning"
			at = maxf(0,actor.ranged_windup_duration-actor.ranged_windup_remaining)
		elif actor.is_attacking:
			clip = "melee_warning"
			at = maxf(0,actor.attack_windup-actor.attack_timer)
			if actor.attack_timer<=0:
				var elapsed: float = -actor.attack_timer
				clip = "melee_attack" if elapsed<=MELEE_IMPACT else "melee_recovery"
				at = elapsed if elapsed<=MELEE_IMPACT else elapsed-MELEE_IMPACT
		elif actor.overseer_burst_recovery_remaining>0:
			clip = "burst_attack"
			at = BURST_RECOVERY-actor.overseer_burst_recovery_remaining
		elif command_time<COMMAND_DURATION:
			clip = "command"
			at = command_time
		if not clip.is_empty():
			locomotion_time += delta
			hit_time += delta
			view.sample_clip(clip,at)
			return
	super.update(actor,delta)
