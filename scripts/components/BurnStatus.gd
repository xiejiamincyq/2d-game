extends RefCounted
class_name BurnStatus

const MAX_STACKS := 5
const DAMAGE_PER_STACK_RATIO := 0.60

var stacks: Array[Dictionary] = []

func apply_stack(base_attack: float, duration: float, slow_fraction: float = 0.0) -> bool:
	if base_attack <= 0.0 or duration <= 0.0:
		return false
	var stack := {
		"damage_per_second": base_attack * DAMAGE_PER_STACK_RATIO,
		"remaining": duration,
		"slow_fraction": clampf(slow_fraction, 0.0, 0.95),
	}
	if stacks.size() < MAX_STACKS:
		stacks.append(stack)
		return true
	var refresh_index := 0
	var shortest_remaining := float(stacks[0]["remaining"])
	for index in range(1, stacks.size()):
		var remaining := float(stacks[index]["remaining"])
		if remaining < shortest_remaining:
			shortest_remaining = remaining
			refresh_index = index
	stacks[refresh_index] = stack
	return false

func advance(delta: float) -> float:
	if delta <= 0.0 or stacks.is_empty():
		return 0.0
	var resolved_damage := 0.0
	for index in range(stacks.size() - 1, -1, -1):
		var stack: Dictionary = stacks[index]
		var remaining := float(stack["remaining"])
		resolved_damage += float(stack["damage_per_second"]) * minf(delta, remaining)
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			stacks.remove_at(index)
		else:
			stack["remaining"] = remaining
			stacks[index] = stack
	return resolved_damage

func get_stack_count() -> int:
	return stacks.size()

func get_damage_per_second() -> float:
	var total := 0.0
	for stack in stacks:
		total += float(stack["damage_per_second"])
	return total

func get_slow_fraction() -> float:
	var strongest_slow := 0.0
	for stack in stacks:
		strongest_slow = maxf(strongest_slow, float(stack["slow_fraction"]))
	return strongest_slow

func clear() -> void:
	stacks.clear()
