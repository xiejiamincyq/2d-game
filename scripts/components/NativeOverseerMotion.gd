extends "res://scripts/components/NativeBossMotion.gd"
## Legacy five-attack visual adapter. Combat controllers remain authoritative.
## Only a completed attack has a short visual tail; cancellation never does.
const TentacleSource = preload("res://scripts/components/TentacleAttack.gd")
var _observing := false
var _tail_action := ""
var _tail_elapsed := 0.0
var _tail_impact_seconds := 0.0

func update(actor: CharacterBody2D, delta: float) -> void:
	if view == null or not is_finite(delta) or delta < 0:
		return
	var combat = actor.get_attack_director()
	var melee = actor.get_tentacle_attack()
	# Existing fixture/legacy callers may add the Actor before calling setup.
	if combat == null or melee == null:
		super.update(actor, delta)
		return
	var pattern = combat.get_pattern()
	if not _observing:
		melee.attack_finished.connect(_on_melee_finished)
		melee.attack_cancelled.connect(_clear_tail)
		pattern.pattern_finished.connect(_on_pattern_finished)
		pattern.pattern_cancelled.connect(_clear_tail)
		_observing = true
	if not actor.entrance_resolved:
		_clear_tail()
		super.update(actor, delta)
		return
	if combat.get_state_name() in ["TRANSITION_1", "TRANSITION_2"]:
		_clear_tail()
		_suppress_recoil(delta)
		_sample_phase("phase_transition", combat.state_elapsed / combat.TRANSITION_SECONDS)
		return
	if combat.target_hidden or actor.death_resolved:
		_clear_tail()
	elif melee.is_attacking():
		_clear_tail()
		_suppress_recoil(delta)
		var action := "sweep" if melee.attack_kind == melee.AttackKind.SWEEP else "slam"
		if melee.attack_stage == melee.AttackStage.WARNING:
			var warning: float = melee.SWEEP_WARNING_SECONDS if action == "sweep" else melee.SLAM_WARNING_SECONDS
			_sample_phase(action + "_warning", melee.elapsed / warning)
		else:
			_sample_phase(action + "_attack", melee.elapsed / melee.SWEEP_ACTIVE_SECONDS)
		return
	else:
		var state: Dictionary = pattern.get_visual_state()
		if not state.is_empty():
			_clear_tail()
			_suppress_recoil(delta)
			var progress: float = state.elapsed / state.first_shot_seconds
			if state.stage == "attack":
				progress = (state.elapsed - state.first_shot_seconds) / maxf(0.001, state.last_shot_seconds - state.first_shot_seconds)
			_sample_phase(String(state.pattern) + "_" + String(state.stage), progress)
			return
	if not _tail_action.is_empty():
		_suppress_recoil(delta)
		_tail_elapsed += delta
		if _tail_elapsed < _tail_impact_seconds:
			view.sample_clip(_tail_action + "_attack", _tail_elapsed)
			return
		var recovery := _tail_action + "_recovery"
		var recovery_elapsed := _tail_elapsed - _tail_impact_seconds
		if recovery_elapsed < view.player.get_animation(recovery).length:
			view.sample_clip(recovery, recovery_elapsed)
			return
		_clear_tail()
		# Delta already consumed above; do not double-advance locomotion.
		super.update(actor, 0.0)
		return
	super.update(actor, delta)

func _suppress_recoil(delta: float) -> void:
	locomotion_time += delta
	hit_time = 1.0 # Flash remains on the skin, no delayed recoil after an attack.

func _sample_phase(clip: String, progress: float) -> void:
	view.sample_clip(clip, view.player.get_animation(clip).length * clampf(progress, 0.0, 1.0))

func _on_melee_finished(kind: int) -> void:
	_tail_action = "slam" if kind == TentacleSource.AttackKind.SLAM else "sweep"
	_tail_elapsed = 0.0
	# Slam has no sustained ACTIVE combat window. This impact is visual only.
	_tail_impact_seconds = view.player.get_animation("slam_attack").length if kind == TentacleSource.AttackKind.SLAM else 0.0

func _on_pattern_finished(pattern_id: StringName) -> void:
	_tail_action = String(pattern_id)
	_tail_elapsed = 0.0
	_tail_impact_seconds = 0.0

func _clear_tail() -> void:
	_tail_action = ""
	_tail_elapsed = 0.0
	_tail_impact_seconds = 0.0
