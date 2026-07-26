extends Node
class_name BossAttackDirector

signal phase_changed(phase: int)
signal reinforcements_requested(count: int)
signal combat_cue(cue: StringName)

const BossProjectilePatternScript = preload("res://scripts/components/BossProjectilePattern.gd")

const ENTRANCE_SECONDS := 1.4
const TRANSITION_SECONDS := 0.65
const INITIAL_ATTACK_DELAY_SECONDS := 0.65
const ATTACK_RECOVERY_SECONDS := 1.0
const MELEE_ZONE_MAX := 230.0
const RANGED_ZONE_MIN := 310.0

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
var last_attack_class: StringName = &"none"
var waiting_for_attack_completion := false

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
	pattern.global_position = boss.global_position
	pattern.set_process(false)
	state = State.ENTRANCE
	state_elapsed = 0.0

func advance(delta: float) -> void:
	if delta <= 0.0 or state == State.DEATH:
		return
	if is_instance_valid(boss):
		pattern.global_position = boss.global_position
	if (
		state in [State.PHASE_1, State.PHASE_2, State.PHASE_3]
		and is_instance_valid(boss)
		and is_instance_valid(target_player)
		and pattern.is_pattern_active()
		and boss.global_position.distance_to(target_player.global_position) <= MELEE_ZONE_MAX
	):
		pattern.clear()
		attack_gap = maxf(attack_gap, ATTACK_RECOVERY_SECONDS)
	pattern.advance(delta)
	var attack_is_active: bool = pattern.is_pattern_active() or tentacle_attack.is_attacking()
	if waiting_for_attack_completion and not attack_is_active:
		waiting_for_attack_completion = false
		attack_gap = maxf(attack_gap, ATTACK_RECOVERY_SECONDS)
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

func get_last_attack_class() -> StringName:
	return last_attack_class

func is_movement_locked() -> bool:
	return state in [State.ENTRANCE, State.TRANSITION_1, State.TRANSITION_2, State.DEATH]

func _enter_phase(phase: int) -> void:
	current_phase = phase
	state = [State.PHASE_1, State.PHASE_2, State.PHASE_3][phase - 1]
	state_elapsed = 0.0
	attack_gap = INITIAL_ATTACK_DELAY_SECONDS
	attack_index = 0
	waiting_for_attack_completion = false
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
	waiting_for_attack_completion = false

func _schedule_attack() -> void:
	if attack_gap > 0.0 or not is_instance_valid(target_player):
		return
	if pattern.is_pattern_active() or tentacle_attack.is_attacking():
		return
	var distance := boss.global_position.distance_to(target_player.global_position) if is_instance_valid(boss) else INF
	var choose_melee := distance <= MELEE_ZONE_MAX or (distance < RANGED_ZONE_MIN and attack_index % 2 == 0)
	var started := _start_melee_attack() if choose_melee else _start_ranged_attack()
	if started:
		last_attack_class = &"melee" if choose_melee else &"ranged"
		combat_cue.emit(&"boss_tentacle" if choose_melee else &"boss_barrage")
		attack_index += 1
		waiting_for_attack_completion = true

func _start_melee_attack() -> bool:
	if current_phase == 2 or (current_phase == 3 and attack_index % 2 == 1):
		var target_count := 3 if current_phase == 2 else 4
		return tentacle_attack.start_slam(tentacle_attack.make_slam_targets(target_player.global_position, target_count))
	return tentacle_attack.start_sweep(target_player.global_position)

func _start_ranged_attack() -> bool:
	if current_phase == 1:
		return pattern.start_pattern(pattern.AIMED_FAN)
	if current_phase == 2:
		return pattern.start_pattern(pattern.TWIN_SPIRAL)
	return pattern.start_pattern(pattern.BROKEN_RING if attack_index % 2 == 0 else pattern.TWIN_SPIRAL)
