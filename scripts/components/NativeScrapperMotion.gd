extends RefCounted

# Internal Enemy(SCRAPPER) -> visual-only contract. Reads existing combat state;
# never writes attack, movement, health, collision or emits gameplay events.
var view: Node2D
var locomotion_time := 0.0
var hit_time := 1.0

func _init(native_view: Node2D) -> void:
	view = native_view
	view.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

func notify_hit() -> void:
	# Sustained fire does not restart recoil every frame and freeze the gait.
	if hit_time >= 0.16:
		hit_time = 0.0

func update(actor: CharacterBody2D, delta: float) -> void:
	if not is_finite(delta) or delta < 0:
		return
	locomotion_time += delta
	hit_time += delta
	var attack = actor.basic_attack
	var clip := "idle"
	var seconds := locomotion_time
	var show_action: bool = actor.spawn_impulse_remaining <= 0 and actor.get_target_player() != null
	if show_action and attack.stage == attack.Stage.WARNING:
		clip = "warning"
		seconds = view.player.get_animation(clip).length * clampf(attack.elapsed / attack.get_warning_duration(), 0, 1)
	elif show_action and attack.stage in [attack.Stage.ACTIVE, attack.Stage.RECOVERY]:
		clip = "attack"
		var active_progress := clampf((attack.elapsed - attack.get_warning_duration()) / attack.get_active_duration(), 0, 1)
		var recovery_progress := clampf((attack.elapsed - attack.get_warning_duration() - attack.get_active_duration()) / attack.RECOVERY, 0, 1)
		seconds = view.player.get_animation(clip).length * (active_progress * 0.7 + recovery_progress * 0.3)
	elif show_action and actor.is_attacking:
		clip = "warning" if actor.attack_timer > 0 else "attack"
		var progress: float = 1 - actor.attack_timer / actor.attack_windup if actor.attack_timer > 0 else -actor.attack_timer / actor.attack_recovery
		seconds = view.player.get_animation(clip).length * clampf(progress, 0, 1)
	elif hit_time < 0.16:
		clip = "hit"
		seconds = hit_time
	elif actor.velocity.length_squared() > 1:
		clip = "walk"
	view.sample_clip(clip, seconds)

func release_death(parent: Node) -> void:
	var ghost := view
	var at: Transform2D = ghost.global_transform
	ghost.get_parent().remove_child(ghost)
	parent.add_child(ghost)
	ghost.process_mode = Node.PROCESS_MODE_PAUSABLE
	ghost.global_transform = at
	ghost.play_clip("death")
	ghost.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	ghost.player.animation_finished.connect(func(_clip: StringName): ghost.queue_free(), CONNECT_ONE_SHOT)
	view = null
