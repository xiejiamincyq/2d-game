extends "res://scripts/components/NativeScrapperMotion.gd"
## Shares only visual hit/death lifecycle, never the scrapper attack mapping.
var shot_remaining := 0.0
func notify_shot() -> void:
	shot_remaining = 0.24
func update(actor: CharacterBody2D, delta: float) -> void:
	if not is_finite(delta) or delta < 0:
		return
	locomotion_time += delta
	hit_time += delta
	shot_remaining = maxf(0, shot_remaining - delta)
	var show_action: bool = actor.spawn_impulse_remaining <= 0 and actor.get_target_player() != null
	var clip := "idle"
	var seconds := locomotion_time
	if not show_action:
		shot_remaining = 0 # Hidden target / spawn cannot leave a stale visible spit.
	if show_action and actor.ranged_is_winding_up:
		clip = "warning"
		seconds = view.player.get_animation(clip).length * clampf(1 - actor.ranged_windup_remaining / actor.ranged_windup_duration, 0, 1)
	elif show_action and shot_remaining > 0:
		clip = "attack"
		seconds = 0.24 - shot_remaining
	elif hit_time < 0.16:
		clip = "hit"
		seconds = hit_time
	elif actor.velocity.length_squared() > 1:
		clip = "walk"
	view.sample_clip(clip, seconds)
