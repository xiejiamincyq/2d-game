extends Node
class_name BossAttackDirector

signal phase_changed(phase: int)
signal reinforcements_requested(count: int)
signal combat_cue(cue: StringName)

const BossProjectilePatternScript = preload("res://scripts/components/BossProjectilePattern.gd")

const ENTRANCE_SECONDS := 1.1
const TRANSITION_SECONDS := 0.65
const ATTACK_GAP_SECONDS := 0.35

enum State { ENTRANCE, PHASE_1, TRANSITION_1, PHASE_2, TRANSITION_2, PHASE_3, DEATH }

var boss: Node2D
var target_player: Node2D
var projectile_parent: Node
var tentacle_attack: Node
var pattern: Node2D
var state := State.ENTRANCE
var current_phase := 0
var requested_phase := 1
var state_elapsed := 0.0
var attack_gap := 0.0
var attack_index := 0

func configure(owner: Node2D, target: Node2D, projectiles: Node, tentacle: Node, seed_value: int) -> void:
	boss = owner
	target_player = target
	projectile_parent = projectiles
	tentacle_attack = tentacle
	pattern = BossProjectilePatternScript.new()
	pattern.name = "BossProjectilePattern"
	add_child(pattern)
	var bounds: Rect2 = boss.get("world_bounds")
	pattern.configure(projectile_parent, bounds, target_player, boss.get_instance_id(), seed_value)
	pattern.set_process(false)
	state = State.ENTRANCE
	state_elapsed = 0.0

func advance(delta: float) -> void:
	if delta <= 0.0 or state == State.DEATH:
		return
	pattern.advance(delta)
	state_elapsed += delta
	if state == State.ENTRANCE:
		if state_elapsed >= ENTRANCE_SECONDS:
			_enter_phase(1)
		return
	if state in [State.TRANSITION_1, State.TRANSITION_2]:
		if state_elapsed >= TRANSITION_SECONDS:
			_finish_transition()
		return
	attack_gap = maxf(0.0, attack_gap - delta)
	_schedule_attack()

func set_health_phase(health_phase: int) -> void:
	requested_phase = maxi(requested_phase, clampi(health_phase, 1, 3))
	if current_phase > 0 and requested_phase > current_phase and (state == State.PHASE_1 or state == State.PHASE_2 or state == State.PHASE_3):
		_start_next_transition()

func shutdown() -> void:
	if state == State.DEATH:
		return
	state = State.DEATH
	state_elapsed = 0.0
	if is_instance_valid(pattern):
		pattern.clear()
	if is_instance_valid(tentacle_attack):
		tentacle_attack.cancel_attack()
	combat_cue.emit(&"boss_death")

func get_pattern() -> Node2D:
	return pattern

func get_state_name() -> String:
	return State.keys()[state]

func is_movement_locked() -> bool:
	return state in [State.ENTRANCE, State.TRANSITION_1, State.TRANSITION_2, State.DEATH]

func _enter_phase(phase: int) -> void:
	current_phase = phase
	state = [State.PHASE_1, State.PHASE_2, State.PHASE_3][phase - 1]
	state_elapsed = 0.0
	attack_gap = 0.0
	attack_index = 0
	phase_changed.emit(phase)
	combat_cue.emit(&"boss_phase")
	if requested_phase > current_phase:
		_start_next_transition()

func _start_next_transition() -> void:
	if current_phase >= 3:
		return
	_cancel_active_attacks()
	state = State.TRANSITION_1 if current_phase == 1 else State.TRANSITION_2
	state_elapsed = 0.0
	reinforcements_requested.emit(6 if current_phase == 1 else 8)
	combat_cue.emit(&"boss_transition")

func _finish_transition() -> void:
	_enter_phase(current_phase + 1)

func _cancel_active_attacks() -> void:
	if is_instance_valid(pattern):
		pattern.clear()
	if is_instance_valid(tentacle_attack):
		tentacle_attack.cancel_attack()

func _schedule_attack() -> void:
	if attack_gap > 0.0 or not is_instance_valid(target_player):
		return
	if pattern.is_pattern_active() or tentacle_attack.is_attacking():
		return
	var started := false
	if current_phase == 1:
		started = tentacle_attack.start_sweep(target_player.global_position) if attack_index % 2 == 0 else pattern.start_pattern(pattern.AIMED_FAN)
	elif current_phase == 2:
		started = tentacle_attack.start_slam(tentacle_attack.make_slam_targets(target_player.global_position, 3)) if attack_index % 2 == 0 else pattern.start_pattern(pattern.TWIN_SPIRAL)
	elif current_phase == 3:
		started = pattern.start_pattern(pattern.BROKEN_RING) if attack_index % 2 == 0 else tentacle_attack.start_sweep(target_player.global_position)
	if started:
		combat_cue.emit(&"boss_tentacle" if tentacle_attack.is_attacking() else &"boss_barrage")
		attack_index += 1
		attack_gap = ATTACK_GAP_SECONDS
